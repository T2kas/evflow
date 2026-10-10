import Foundation

// Feed numbers are valid at meta.dataUntilUtc. These pure helpers shift them to "now" between refreshes
// (lag = minutes since dataUntilUtc). No UI here, so everything is unit-testable.

/// Whole minutes from the feed snapshot to now (never negative).
func feedLag(dataUntil: Date, now: Date) -> Int {
    max(0, Int(now.timeIntervalSince(dataUntil) / 60))
}

let vilnius = TimeZone(identifier: "Europe/Vilnius")!

/// Europe/Vilnius hour 0-23: the index into forecastByHour / busyByHour.
func vilniusHour(_ date: Date) -> Int {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = vilnius
    return cal.component(.hour, from: date)
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

extension Connector {
    var isFree: Bool { status == ConnectorStatus.free }
    var isBusy: Bool { status == ConnectorStatus.busy }

    /// How long the current session has been going, as of now.
    func busyNow(lag: Int) -> Int? {
        guard isBusy, let b = busyMin else { return nil }
        return b + lag
    }

    /// Minutes until it should free up, as of now; ≤ 0 means "any minute now".
    func remainingNow(lag: Int) -> Int? {
        guard isBusy, let p = prediction else { return nil }
        return p.expectedRemainingMin - lag
    }

    /// The server's `overstay` flag is authoritative at snapshot time (it already exempts e.g. overnight AC);
    /// between refreshes we only flip a session to overstay once it crosses expectedChargeMin.
    func overstayNow(lag: Int) -> Bool {
        guard isBusy else { return false }
        if overstay == true { return true }
        guard let b = busyMin else { return false }
        return b <= expectedChargeMin && b + lag > expectedChargeMin
    }

    /// Minutes the car has been parked beyond what it needs to charge.
    func overstayByNow(lag: Int) -> Int {
        max(0, (busyNow(lag: lag) ?? 0) - expectedChargeMin)
    }
}

// MARK: - Text

/// "Atsilaisvins per ~25 min." – rounded to 5 min, hours above 90 min.
func freesInText(remainingNow: Int) -> String {
    remainingNow <= 0 ? "Turėtų atsilaisvinti bet kurią minutę" : "Atsilaisvins per \(freesInShort(remainingNow: remainingNow))"
}

/// "~25 min." / "~2 val." / "bet kurią minutę" – for tight rows.
func freesInShort(remainingNow: Int) -> String {
    if remainingNow <= 0 { return "bet kurią minutę" }
    if remainingNow > 90 { return "~\(Int((Double(remainingNow) / 60).rounded())) val." }
    return "~\(max(5, Int((Double(remainingNow) / 5).rounded()) * 5)) min."
}

enum Likelihood { case high, medium, low }

/// Colour bucket for a busy connector, from P(free within 30 min).
func likelihood(pFree30: Double) -> Likelihood {
    pFree30 >= 0.6 ? .high : pFree30 >= 0.3 ? .medium : .low
}

/// Station wait as of now: 0 = free now, nil = unknown.
func waitNow(_ s: Station, lag: Int) -> Int? {
    guard let w = s.expectedWaitMin else { return nil }
    return w == 0 ? 0 : max(0, w - lag)
}

/// Big line on the station card.
func stationHeadline(_ s: Station, lag: Int) -> String {
    guard let w = waitNow(s, lag: lag) else { return "Užimta" }
    return w == 0 ? "Yra laisvų vietų (\(s.counts.free)/\(s.counts.total))" : "Laukimas ~\(w) min."
}

enum ReliabilityLevel { case reliable, sometimes, often, neverUsed }

func reliabilityLevel(_ r: Reliability) -> ReliabilityLevel {
    if r.neverUsed == true { return .neverUsed }
    return r.score >= 80 ? .reliable : r.score >= 50 ? .sometimes : .often
}

func reliabilityText(_ l: ReliabilityLevel) -> String {
    switch l {
    case .reliable: "Patikima"
    case .sometimes: "Kartais neveikia"
    case .often: "Dažnai neveikia"
    case .neverUsed: "Niekas čia nekrauna, gali neveikti"
    }
}

// MARK: - Arrival

/// Up to this drive time the live snapshot beats the hourly forecast.
let liveHorizonMin = 15

/// Expected wait on arrival, used to rank recommendations.
func arrivalWait(_ s: Station, driveMin: Int, lag: Int, arrivalHour: Int) -> Int {
    if s.counts.free > 0 && driveMin <= liveHorizonMin { return 0 }
    if driveMin <= 60, let w = s.expectedWaitMin { return max(0, w - lag - driveMin) }
    return s.forecastByHour?.waitMin[safe: arrivalHour].flatMap { $0 } ?? 15
}

/// "Ar bus laisva, kai atvažiuosiu"
func arrivalText(_ s: Station, driveMin: Int, lag: Int, now: Date) -> String {
    if driveMin <= liveHorizonMin {
        if s.counts.free > 0 { return "Greičiausiai rasi laisvą vietą" }
        if let w = waitNow(s, lag: lag) { return "Dabar visos užimtos, laukimas ~\(max(0, w - driveMin)) min." }
        return "Dabar visos vietos užimtos"
    }
    let h = vilniusHour(now.addingTimeInterval(Double(driveMin) * 60))
    guard let f = s.forecastByHour, let p = f.freeProb[safe: h].flatMap({ $0 }) else {
        return "Šiai valandai prognozės nėra"
    }
    var out = "\(Int(p * 100)) % tikimybė rasti laisvą vietą \(String(format: "%02d", h)):00"
    if let w = f.waitMin[safe: h].flatMap({ $0 }), w > 0 { out += ", laukimas ~\(w) min." }
    if f.confidence < 0.3 { out += " (mažai istorijos)" }
    return out
}
