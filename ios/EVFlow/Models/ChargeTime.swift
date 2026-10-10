import Foundation

/// A finished, confirmed session of this user (stored in SwiftData as `PastCharge`).
struct ChargeHistoryItem: Equatable {
    let connectorClass: String
    let durationMin: Int
}

enum ChargeTimeSource: Equatable {
    /// the feed's calibrated expectedChargeMin for the connector
    case feed
    /// median of the user's own sessions on this connector class
    case history

    var label: String {
        switch self {
        case .feed: "pagal jungties galią"
        case .history: "pagal tavo įprastą krovimo laiką"
        }
    }
}

/// How long this user will charge here – no input needed.
/// Feed default; with ≥ 3 own sessions of the same class: their median, clamped to 0.5–2× the feed value.
func expectedMinutes(_ c: Connector, history: [ChargeHistoryItem]) -> (minutes: Int, source: ChargeTimeSource) {
    let feed = c.expectedChargeMin
    let own = history.filter { $0.connectorClass == c.class }.map(\.durationMin).sorted()
    guard own.count >= Rewards.historyMinSessions else { return (feed, .feed) }
    let mid = own.count / 2
    let median = own.count.isMultiple(of: 2) ? Double(own[mid - 1] + own[mid]) / 2 : Double(own[mid])
    let lo = Double(feed) * Rewards.historyClamp.lowerBound, hi = Double(feed) * Rewards.historyClamp.upperBound
    return (Int(min(hi, max(lo, median)).rounded()), .history)
}
