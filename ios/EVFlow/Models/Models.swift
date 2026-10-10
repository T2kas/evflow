import Foundation
import CoreLocation

// MARK: - Derived view state (feed + lag → what the map and sheets show)

enum ChargerState { case free, busy, overstay, broken, unknown }
enum PinState: String { case free, busy, overstay, broken, stale }

struct ConnectorView: Identifiable {
    let c: Connector
    let state: ChargerState
    let busyNow: Int?
    let remainingNow: Int?
    /// minutes parked beyond expectedChargeMin, as of now
    let overstayBy: Int
    var id: String { c.id }
}

struct StationView: Identifiable {
    let s: Station
    let coordinate: CLLocationCoordinate2D
    let connectors: [ConnectorView]
    let lag: Int
    let free: Int
    let total: Int
    let overstays: Int
    let maxKw: Double
    let dc: Bool
    let pin: PinState
    let stale: Bool
    let price: Double?
    let priceText: String
    var id: String { s.id }
}

extension Connector {
    func liveState(lag: Int) -> ChargerState {
        switch status {
        case ConnectorStatus.free: .free
        case ConnectorStatus.busy: overstayNow(lag: lag) ? .overstay : .busy
        case ConnectorStatus.broken: .broken
        default: .unknown
        }
    }
    var priceText: String { parsePrice(tariff).map { String(format: "%.2f €", $0).replacingOccurrences(of: ".", with: ",") } ?? "—" }
}

func plugName(_ t: String) -> String {
    t.split(separator: "|").map { p in
        p.contains("COMBO") ? "CCS" : p.contains("CHADEMO") ? "CHAdeMO" : p.contains("T2") ? "Type 2" : String(p)
    }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: " / ")
}

/// Plug filter choices ("Mano automobilis"); nil = any.
let plugChoices: [(type: String?, label: String)] = [
    (nil, "Bet kokia"), ("IEC_62196_T2_COMBO", "CCS"), ("IEC_62196_T2", "Type 2"), ("CHADEMO", "CHAdeMO"),
]

func parsePrice(_ t: String?) -> Double? {
    guard let s = t?.replacingOccurrences(of: ",", with: "."),
          let r = s.range(of: #"([\d.]+)\s*€\s*/\s*kWh"#, options: .regularExpression) else { return nil }
    return Double(s[r].components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).first(where: { !$0.isEmpty }) ?? "")
}

// Operator "last update" only changes when status changes, so a long gap alone is not proof of a dead feed.
// Treat a feed as stale only when silent for over a day.
let staleAfterMin = 1440

func makeView(_ s: Station, lag: Int) -> StationView? {
    guard let coord = s.coordinate else { return nil }
    let connectors = s.connectors.map { c in
        ConnectorView(c: c, state: c.liveState(lag: lag), busyNow: c.busyNow(lag: lag), remainingNow: c.remainingNow(lag: lag),
                             overstayBy: c.overstayByNow(lag: lag))
    }
    let overstays = connectors.filter { $0.state == .overstay }.count
    let stale = (s.reliability.dataAgeMin ?? 0) > staleAfterMin
    let free = s.counts.free
    let pin: PinState = stale ? .stale : free > 0 ? .free : overstays > 0 ? .overstay : s.counts.busy > 0 ? .busy : .broken
    let price = s.connectors.compactMap { parsePrice($0.tariff) }.min()
    return StationView(s: s, coordinate: coord, connectors: connectors, lag: lag, free: free, total: s.counts.total,
                       overstays: overstays, maxKw: s.maxPowerKw, dc: s.connectors.contains { $0.isDC }, pin: pin, stale: stale,
                       price: price,
                       priceText: price.map(fmtPrice) ?? (s.connectors.first?.tariff ?? "—"))
}

// MARK: - Recommendation

struct Reco: Identifiable {
    let v: StationView
    let km: Double
    /// driving minutes (MKDirections ETA, or a straight-line estimate when offline)
    let drive: Int
    /// expected wait on arrival (`arrivalWait`)
    let wait: Int
    var score: Int { drive + wait }
    var id: String { v.id }
    var explanation: String { "\(drive) min. kelio + ~\(wait) min. laukimo" }
}

/// Stations worth sending someone to: located, not closed, a compatible unrestricted working connector, reliability ≥ 50.
func isRecommendable(_ s: Station, plugType: String?) -> Bool {
    guard s.coordinate != nil, s.openNow != false, s.reliability.score >= 50 else { return false }
    return s.connectors.contains { c in
        c.restriction == nil && c.status != ConnectorStatus.broken && (plugType.map { c.plugTypes.contains($0) } ?? true)
    }
}

func haversineKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let r = 6371.0, rad = Double.pi / 180
    let dLat = (b.latitude - a.latitude) * rad, dLon = (b.longitude - a.longitude) * rad
    let x = pow(sin(dLat / 2), 2) + cos(a.latitude * rad) * cos(b.latitude * rad) * pow(sin(dLon / 2), 2)
    return 2 * r * asin(sqrt(x))
}

/// Fallback when MKDirections is unavailable (offline demo): road factor 1.35, 28 km/h city average, +2 min to park.
func driveMinutes(_ km: Double) -> Int { Int((km * 1.35 / 28 * 60 + 2).rounded()) }

// MARK: - Formatting

func fmtMin(_ m: Double) -> String {
    let m = Int(m.rounded())
    if m < 60 { return "\(m) min" }
    let h = m / 60, r = m % 60
    return r > 0 ? "\(h) val. \(r) min" : "\(h) val."
}
func fmtKm(_ km: Double) -> String {
    km < 1 ? "\(Int((km * 1000).rounded())) m" : String(format: "%.1f km", km).replacingOccurrences(of: ".", with: ",")
}
func fmtPrice(_ p: Double) -> String { String(format: "%.2f €/kWh", p).replacingOccurrences(of: ".", with: ",") }
func pct(_ p: Double) -> String { "\(Int((p * 100).rounded())) %" }
