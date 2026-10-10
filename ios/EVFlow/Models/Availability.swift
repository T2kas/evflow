import Foundation
import CoreLocation

// "Will I find a spot" from history (station.availability) and the 9-of-10 times.
// Thresholds and names come from meta.availability_levels – nothing is hard-coded except fallbacks
// for older feeds that don't send them.

enum AvailLevel: String {
    case green, yellow, red
}

/// Level at the arrival hour: level_by_hour[h], else the current-hour level.
func arrivalLevel(_ s: Station, arrivalHour: Int) -> AvailLevel? {
    guard let a = s.availability else { return nil }
    let raw = a.levelByHour?[safe: arrivalHour].flatMap { $0 } ?? a.level
    return raw.flatMap(AvailLevel.init(rawValue:))
}

/// Name of a level from meta.availability_levels.labels (fallback only for feeds without it).
func levelLabel(_ l: AvailLevel, levels: AvailabilityLevels?) -> String {
    if let name = levels?.labels?[l.rawValue], !name.isEmpty { return name }
    switch l { case .green: return "Paprastai laisva"; case .yellow: return "Kartais užimta"; case .red: return "Dažnai užimta" }
}

/// "Dažniausiai laisva šiuo metu" / "Dažnai užimta 18:00" – arrival in the same Vilnius hour reads "šiuo metu".
func availabilityText(_ s: Station, arrival: Date, now: Date, levels: AvailabilityLevels?) -> String? {
    let h = vilniusHour(arrival)
    guard let l = arrivalLevel(s, arrivalHour: h) else { return nil }
    let when = h == vilniusHour(now) ? "šiuo metu" : String(format: "%02d:00", h)
    let label = levelLabel(l, levels: levels)
    return l == .red ? "Populiari: \(label.lowercased()) \(when)" : "\(label) \(when)"
}

/// "Per 4 d. laisva vieta buvo 87 % laiko"
func freeShareText(_ s: Station, historyDays: Double?) -> String? {
    guard let share = s.availability?.freeShareOverall, let days = historyDays, days > 0 else { return nil }
    return "Per \(max(1, Int(days.rounded()))) d. laisva vieta buvo \(Int((share * 100).rounded())) % laiko"
}

/// Recommendation penalty: a station that is usually full at the arrival hour.
let busyAtArrivalPenaltyMin = 10

func busyAtArrival(_ s: Station, arrivalHour: Int) -> Bool { arrivalLevel(s, arrivalHour: arrivalHour) == .red }

// MARK: - "9 iš 10" (likely_by_min / wait_likely_by_min)

/// Above this the 9-of-10 time says little: "Sunku nuspėti" instead of the usual line.
let hardToPredictMin = 180

/// The 9-of-10 time shifted by the feed lag (never below 0).
func likelyByNow(_ likelyBy: Int?, lag: Int) -> Int? {
    likelyBy.map { max(0, $0 - lag) }
}

/// Decided on the feed value, so the card doesn't flip between refreshes.
func hardToPredict(_ likelyBy: Int?) -> Bool { (likelyBy ?? 0) > hardToPredictMin }

/// "Sunku nuspėti: gali užtrukti iki 4 val."
func hardToPredictText(likelyBy: Int, lag: Int) -> String {
    "Sunku nuspėti: gali užtrukti iki \(tileMinShort(max(0, likelyBy - lag)))"
}

/// Compact rows: "~25 min. · iki 40 min." – the 9-of-10 time only when it adds something.
func freesInShortLikely(remainingNow: Int, likelyBy: Int?, lag: Int) -> String {
    let short = freesInShort(remainingNow: remainingNow)
    // compare with what is shown ("~25" for 23), so "~25 · iki 26" never appears
    let shown = remainingNow <= 0 ? 0 : remainingNow > 90 ? remainingNow : max(5, Int((Double(remainingNow) / 5).rounded()) * 5)
    guard let hi = likelyByNow(likelyBy, lag: lag), hi > shown + 2 else { return short }
    return "\(short) · iki \(tileMinShort(hi))"
}

/// Connector card: "Greičiausiai ~25 min. · 9 iš 10 kartų per 40 min."; nil without likely_by_min (older feeds).
func likelySentence(remainingNow: Int, likelyBy: Int?, lag: Int) -> String? {
    guard let raw = likelyBy, let hi = likelyByNow(raw, lag: lag) else { return nil }
    if hardToPredict(raw) { return hardToPredictText(likelyBy: raw, lag: lag) }
    let likely = hi == 0 ? "9 iš 10 kartų jau būtų atsilaisvinusi" : "9 iš 10 kartų per \(tileMinShort(hi))"
    return "Greičiausiai \(freesInShort(remainingNow: remainingNow)) · \(likely)"
}

/// Station wait: "~15 min. · iki 40 min.", or "Sunku nuspėti: …"; nil when free now or unknown.
func waitShortLikely(_ s: Station, lag: Int) -> String? {
    guard let w = waitNow(s, lag: lag), w > 0 else { return nil }
    if let raw = s.waitLikelyByMin, hardToPredict(raw) { return hardToPredictText(likelyBy: raw, lag: lag) }
    guard let hi = likelyByNow(s.waitLikelyByMin, lag: lag), hi > w + 2 else { return "~\(w) min." }
    return "~\(w) min. · iki \(tileMinShort(hi))"
}

/// "40 min." / "1,5 val."
private func tileMinShort(_ m: Int) -> String {
    m < 90 ? "\(m) min." : String(format: "%g", (Double(m) / 30).rounded() / 2).replacingOccurrences(of: ".", with: ",") + " val."
}

// MARK: - Map

/// Broken or silent (> 24 h) stations stay off the map unless asked for; the selected one is always shown.
func showsOnMap(pin: PinState, selected: Bool, showBroken: Bool) -> Bool {
    selected || showBroken || (pin != .broken && pin != .stale)
}

// MARK: - Planavimas: best nearby stations for a chosen hour

struct PlanItem: Identifiable {
    let v: StationView
    let km: Double
    let level: AvailLevel?
    /// typical wait that hour (forecast_by_hour.wait_min), nil = unknown
    let wait: Int?
    var id: String { v.id }
}

/// Usually free first, then sometimes busy, often full, unknown; then shorter wait, then closer. Within `maxKm`.
func planStations(_ views: [StationView], from user: CLLocationCoordinate2D, hour: Int, plugType: String?,
                  maxKm: Double = 15, limit: Int = 5) -> [PlanItem] {
    func rank(_ l: AvailLevel?) -> Int { switch l { case .green: 0; case .yellow: 1; case .red: 2; case nil: 3 } }
    return views
        .filter { isRecommendable($0.s, plugType: plugType) }
        .map { v in PlanItem(v: v, km: haversineKm(user, v.coordinate), level: arrivalLevel(v.s, arrivalHour: hour),
                             wait: v.s.forecastByHour?.waitMin[safe: hour].flatMap { $0 }) }
        .filter { $0.km <= maxKm }
        .sorted { (rank($0.level), $0.wait ?? 999, $0.km) < (rank($1.level), $1.wait ?? 999, $1.km) }
        .prefix(limit).map { $0 }
}
