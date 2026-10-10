import Foundation
import CoreLocation

// "Planuoti kelionę": destination → number of charging stops → when to stop → a station near the route
// for each stop, chosen by how usually free it is at the arrival hour. Pure functions, no UI.

struct TripPlace: Identifiable, Equatable {
    let name: String
    let detail: String
    let coordinate: CLLocationCoordinate2D
    var id: String { "\(name)|\(coordinate.latitude),\(coordinate.longitude)" }
    static func == (a: TripPlace, b: TripPlace) -> Bool { a.id == b.id }
}

/// Offline quick picks (city centres).
let tripQuickPlaces: [TripPlace] = [
    .init(name: "Kaunas", detail: "Lietuva", coordinate: .init(latitude: 54.8985, longitude: 23.9036)),
    .init(name: "Klaipėda", detail: "Lietuva", coordinate: .init(latitude: 55.7033, longitude: 21.1443)),
    .init(name: "Šiauliai", detail: "Lietuva", coordinate: .init(latitude: 55.9349, longitude: 23.3137)),
    .init(name: "Panevėžys", detail: "Lietuva", coordinate: .init(latitude: 55.7348, longitude: 24.3575)),
    .init(name: "Palanga", detail: "Lietuva", coordinate: .init(latitude: 55.9175, longitude: 21.0686)),
    .init(name: "Druskininkai", detail: "Lietuva", coordinate: .init(latitude: 54.0151, longitude: 23.9737)),
]

enum Trip {
    /// Maximum charging stops offered.
    static let maxStops = 3
    /// A station counts as "on the way" up to this far from the route (straight line).
    static let maxOffRouteKm = 3.0
    /// Search window along the route around the chosen stop point: ± max(10 km, 12 % of the trip).
    static func windowKm(total: Double) -> Double { max(10, total * 0.12) }
    /// Assumed time at each stop when estimating the final arrival.
    static let stopMin = 30
    /// No stop in the first / last few minutes of the drive.
    static let edgeMin = 5
    /// Rough EV range used only for the suggested stop count.
    static let comfortableKm = 200.0
}

/// Suggested number of stops for a trip (0 for short trips).
func suggestedStops(totalKm: Double) -> Int {
    min(Trip.maxStops, max(0, Int((totalKm / Trip.comfortableKm).rounded(.up)) - 1))
}

/// Stop times spread evenly over the drive (minutes after departure).
func defaultStopMinutes(count: Int, driveMin: Int) -> [Int] {
    guard count > 0 else { return [] }
    return (1...count).map { Int((Double(driveMin) * Double($0) / Double(count + 1)).rounded()) }
}

/// Keeps stop `i` between its neighbours (and away from the ends of the drive).
func clampStop(_ m: Int, index i: Int, stops: [Int], driveMin: Int, gap: Int = 5) -> Int {
    let lo = i == 0 ? Trip.edgeMin : stops[i - 1] + gap
    let hi = i == stops.count - 1 ? driveMin - Trip.edgeMin : stops[i + 1] - gap
    return min(max(m, lo), max(lo, hi))
}

/// Distance along the route reached after `minute` of driving (the route's average speed).
func routeKm(atMinute minute: Int, route: Route) -> Double {
    guard route.minutes > 0 else { return 0 }
    return min(route.total, route.total * Double(minute) / Double(route.minutes))
}

/// Where each station sits relative to the route: km along it and km off it. Computed once per route.
struct RouteIndex {
    struct Hit { let v: StationView; let alongKm: Double; let offKm: Double }
    let hits: [Hit]

    init(route: Route, views: [StationView], plugType: String?) {
        // thin the polyline to ~every 300 m so long trips stay cheap
        var pts: [(CLLocationCoordinate2D, Double)] = []
        var last = -1.0
        for (i, c) in route.coords.enumerated() where route.cum[i] - last >= 0.3 || i == route.coords.count - 1 {
            pts.append((c, route.cum[i])); last = route.cum[i]
        }
        // quick box filter before the exact distance
        let lats = pts.map(\.0.latitude), lons = pts.map(\.0.longitude)
        let pad = 0.05
        let box = ((lats.min() ?? 0) - pad, (lats.max() ?? 0) + pad, (lons.min() ?? 0) - pad * 1.8, (lons.max() ?? 0) + pad * 1.8)
        hits = views.compactMap { v in
            let c = v.coordinate
            guard c.latitude >= box.0, c.latitude <= box.1, c.longitude >= box.2, c.longitude <= box.3,
                  isRecommendable(v.s, plugType: plugType) else { return nil }
            var best = Double.infinity, along = 0.0
            for (p, km) in pts {
                let d = haversineKm(p, c)
                if d < best { best = d; along = km }
            }
            return best <= Trip.maxOffRouteKm ? Hit(v: v, alongKm: along, offKm: best) : nil
        }
    }
}

struct TripStop: Identifiable {
    let index: Int
    /// minutes after departure the user wants to stop
    let minute: Int
    let arrival: Date
    let hit: RouteIndex.Hit?
    let level: AvailLevel?
    /// typical wait at that hour (forecast_by_hour.wait_min), nil = unknown
    let wait: Int?
    var id: Int { index }
}

/// Best station for one stop: usually free at the arrival hour, fast, close to the chosen point, little detour.
func pickStop(_ index: RouteIndex, aroundKm target: Double, total: Double, hour: Int, excluding: Set<String> = []) -> RouteIndex.Hit? {
    let window = Trip.windowKm(total: total)
    func levelCost(_ l: AvailLevel?) -> Double { switch l { case .green: 0; case .yellow: 6; case .red: 14; case nil: 8 } }
    func cost(_ h: RouteIndex.Hit) -> Double {
        let wait = h.v.s.forecastByHour?.waitMin[safe: hour].flatMap { $0 }.map(Double.init) ?? 0
        return levelCost(arrivalLevel(h.v.s, arrivalHour: hour))
            + (h.v.dc && h.v.maxKw >= fastChargeMinKw ? 0 : 12)   // a trip stop wants a fast charger
            + abs(h.alongKm - target) / 3                         // ~1 point per 3 km away from the chosen spot
            + h.offKm * 2 * 1.35                                  // detour there and back
            + wait / 2
    }
    let pool = index.hits.filter { !excluding.contains($0.v.id) }
    let near = pool.filter { abs($0.alongKm - target) <= window }
    return (near.isEmpty ? pool : near).min { cost($0) < cost($1) }
}

/// The plan: one station per chosen stop time (never the same station twice).
func planTrip(route: Route, index: RouteIndex, stopMinutes: [Int], depart: Date) -> [TripStop] {
    var used = Set<String>()
    return stopMinutes.enumerated().map { i, m in
        // earlier stops push later arrivals back
        let arrival = depart.addingTimeInterval(Double(m + i * Trip.stopMin) * 60)
        let h = vilniusHour(arrival)
        let hit = pickStop(index, aroundKm: routeKm(atMinute: m, route: route), total: route.total, hour: h, excluding: used)
        if let hit { used.insert(hit.v.id) }
        return TripStop(index: i, minute: m, arrival: arrival, hit: hit,
                        level: hit.flatMap { arrivalLevel($0.v.s, arrivalHour: h) },
                        wait: hit.flatMap { $0.v.s.forecastByHour?.waitMin[safe: h].flatMap { $0 } })
    }
}

/// Final arrival: drive + an assumed stop length per stop.
func tripArrival(depart: Date, driveMin: Int, stops: Int) -> Date {
    depart.addingTimeInterval(Double(driveMin + stops * Trip.stopMin) * 60)
}

/// "1 val. 25 min." / "45 min."
func fmtDuration(_ m: Int) -> String {
    m < 60 ? "\(m) min." : m % 60 == 0 ? "\(m / 60) val." : "\(m / 60) val. \(m % 60) min."
}

func fmtClock(_ d: Date) -> String {
    let f = DateFormatter(); f.timeZone = vilnius; f.dateFormat = "HH:mm"
    return f.string(from: d)
}
