import Foundation

/// All points / reputation / session rules in one place.
enum Rewards {
    /// freeing the spot within the deadline + graceMin
    static let onTimePoints = 20
    static let graceMin = 10
    static let onTimeReputation = 1
    /// −1 reputation for every started block of lateness
    static let lateBlockMin = 15
    static let lateReputationPerBlock = 1

    /// "Dar kraunasi +15 min.": no penalty, at most twice per session
    static let extendMin = 15
    static let maxExtensions = 2

    /// "Kraunu čia" only next to the station
    static let nearbyMeters = 300.0
    /// a connector busy this long or less is most likely you (the feed lags 3–6 min)
    static let justPluggedInMin = 10
    /// still "Laisva" this long after "Kraunu čia" → we never saw you charging, session is dropped
    static let confirmWithinMin = 10
    /// still "Užimta" this long after "Baigiau ir patraukiau" → ask whether the cable is out
    static let stuckAfterMin = 10

    /// own charge time: after this many finished sessions of the same connector class
    static let historyMinSessions = 3
    /// …clamped to this range of the feed's expectedChargeMin
    static let historyClamp = 0.5...2.0

    /// arrival: geofence radius (with "Always" location) and how old a "Važiuoti" may be for the in-app prompt
    static let arrivalRadiusMeters = 150.0
    static let arrivalMaxAgeHours = 3.0
    /// route screen: suggest another station when waiting longer than this on arrival…
    static let longWaitMin = 10
    /// …and the other one is at least this much better (drive + wait)
    static let betterByMin = 5

    /// Arbus shop prices are in Arbus credits; EVFlow points = credits / this
    static let creditsPerPoint = 100

    static let startReputation = 80
    static let reputationRange = 0...100

    /// photo reports (camera flow): confirmed by the feed / not
    static let reportPoints = 15
    static let reportConfirmedPoints = 30

    struct Outcome: Equatable {
        let points: Int
        let reputationDelta: Int
        /// minutes past deadline + grace, 0 when on time
        let lateMin: Int
        var onTime: Bool { lateMin == 0 }
    }

    /// terminas = startedAt + chargeMin + 15 × extensions
    static func deadline(startedAt: Date, chargeMin: Int, extensions: Int) -> Date {
        startedAt.addingTimeInterval(Double(chargeMin + extendMin * extensions) * 60)
    }

    /// Only for a confirmed session (the feed saw the connector busy after start, then free).
    static func outcome(startedAt: Date, endedAt: Date, chargeMin: Int, extensions: Int) -> Outcome {
        let limit = deadline(startedAt: startedAt, chargeMin: chargeMin, extensions: extensions).addingTimeInterval(Double(graceMin) * 60)
        let late = endedAt.timeIntervalSince(limit) / 60
        if late <= 0 { return Outcome(points: onTimePoints, reputationDelta: onTimeReputation, lateMin: 0) }
        let blocks = Int((late / Double(lateBlockMin)).rounded(.up))
        return Outcome(points: 0, reputationDelta: -blocks * lateReputationPerBlock, lateMin: Int(late.rounded(.up)))
    }

    static func clampReputation(_ r: Int) -> Int {
        min(reputationRange.upperBound, max(reputationRange.lowerBound, r))
    }

    static let reminderText = "Turbūt jau pasikrovei. Patrauk automobilį per \(graceMin) min. ir gausi +\(onTimePoints) taškų."
}
