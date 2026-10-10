import Foundation
import CoreLocation

// MARK: - Live feed (https://raw.githubusercontent.com/T2kas/evflow/app-data/stations.json)
// Format: app-data/README.md. Everything the server may omit or null is optional, so a missing field never breaks decoding.

struct Feed: Codable {
    let meta: Meta
    let stations: [Station]

    static let url = URL(string: "https://raw.githubusercontent.com/T2kas/evflow/app-data/stations.json")!

    static func decode(_ data: Data) throws -> Feed {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(Feed.self, from: data)
    }
}

struct Meta: Codable {
    let generatedUtc: Date
    let dataUntilUtc: Date
    let historyDays: Double?
    /// thresholds + names of the "will I find a spot" levels (never hard-coded in the app)
    let availabilityLevels: AvailabilityLevels?
    /// quantiles of every `*_cdf_min` array, e.g. [0.1, 0.2, … 0.9, 0.95]
    let cdfQuantiles: [Double]?

    enum CodingKeys: String, CodingKey {
        case generatedUtc = "generated_utc", dataUntilUtc = "data_until_utc", historyDays = "history_days"
        case availabilityLevels = "availability_levels", cdfQuantiles = "cdf_quantiles"
    }
}

struct AvailabilityLevels: Codable, Equatable {
    /// share of time with a free connector: ≥ green → green, ≥ yellow → yellow, else red
    let green: Double?
    let yellow: Double?
    /// "green" / "yellow" / "red" / "unknown" → display name
    let labels: [String: String]?
}

/// History-based "will I find a spot", independent of the current status.
struct Availability: Codable, Equatable {
    /// "green" | "yellow" | "red" for the current Vilnius hour; nil = little data
    let level: String?
    let levelOverall: String?
    let freeShareOverall: Double?
    /// 24 values, Europe/Vilnius hours
    let levelByHour: [String?]?

    enum CodingKeys: String, CodingKey {
        case level, levelOverall = "level_overall", freeShareOverall = "free_share_overall", levelByHour = "level_by_hour"
    }
}

struct Station: Codable, Identifiable {
    let id: String
    let name: String
    let `operator`: String
    let address: String
    let city: String
    let lat: Double?
    let lon: Double?
    let open24_7: Bool?
    let openNow: Bool?
    let payments: [String]?
    let maxPowerKw: Double
    let counts: Counts
    /// 0 = a connector is free right now; nil = unknown
    let expectedWaitMin: Int?
    /// "9 iš 10 kartų atsilaisvins per N min." (first of the busy connectors); 0 = a connector is free
    let waitLikelyByMin: Int?
    /// wait minutes at meta.cdfQuantiles
    let waitCdfMin: [Int]?
    let availability: Availability?
    let reliability: Reliability
    let history: History
    let groups: [ConnectorGroup]
    let forecastByHour: Forecast?
    let connectors: [Connector]

    enum CodingKeys: String, CodingKey {
        case id, name, `operator`, address, city, lat, lon, payments, counts, reliability, history, groups, connectors
        case open24_7 = "open_24_7", openNow = "open_now", maxPowerKw = "max_power_kw"
        case expectedWaitMin = "expected_wait_min", forecastByHour = "forecast_by_hour"
        case waitLikelyByMin = "wait_likely_by_min", waitCdfMin = "wait_cdf_min", availability
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return .init(latitude: lat, longitude: lon)
    }
    var operatorName: String { `operator`.replacingOccurrences(of: ", UAB", with: "").replacingOccurrences(of: " UAB", with: "") }
}

struct Counts: Codable {
    let total: Int
    let free: Int
    let busy: Int
    let broken: Int
    let unknown: Int
    let overstaying: Int
}

struct Reliability: Codable {
    /// 0-100, 100 = never reported "Neveikia" / "Nežinoma"
    let score: Int
    let brokenShare: Double?
    let dataAgeMin: Int?
    let neverUsed: Bool?

    enum CodingKeys: String, CodingKey {
        case score, brokenShare = "broken_share", dataAgeMin = "data_age_min", neverUsed = "never_used"
    }
}

struct History: Codable {
    let sessionsPerDay: Double?
    let medianSessionMin: Int?
    let overstayShare: Double?
    /// 24 values, Europe/Vilnius hours
    let busyByHour: [Double?]?

    enum CodingKeys: String, CodingKey {
        case sessionsPerDay = "sessions_per_day", medianSessionMin = "median_session_min"
        case overstayShare = "overstay_share", busyByHour = "busy_by_hour"
    }
}

/// named ConnectorGroup (not Group) so it does not shadow SwiftUI.Group
struct ConnectorGroup: Codable, Hashable {
    let type: String
    let powerKw: Double
    let count: Int
    let free: Int

    enum CodingKeys: String, CodingKey { case type, count, free, powerKw = "power_kw" }
}

struct Forecast: Codable {
    /// 24 values, Europe/Vilnius hours
    let freeProb: [Double?]
    let waitMin: [Int?]
    let confidence: Double

    enum CodingKeys: String, CodingKey { case confidence, freeProb = "free_prob", waitMin = "wait_min" }
}

struct Connector: Codable, Identifiable {
    let id: String
    let chargerId: String
    let type: String
    let powerKw: Double
    let `class`: String
    let tariff: String?
    /// "CUSTOMERS" | "DISABLED" | … | nil
    let restriction: String?
    /// "Laisva" | "Užimta" | "Neveikia" | "Nežinoma"
    let status: String
    let statusSince: Date?
    /// how long a car realistically needs to charge on this connector (calibrated server side)
    let expectedChargeMin: Int
    let busyMin: Int?
    let busyMinIsLowerBound: Bool?
    let overstay: Bool?
    let overstayMin: Int?
    let prediction: Prediction?

    enum CodingKeys: String, CodingKey {
        case id, type, `class`, tariff, restriction, status, overstay, prediction
        case chargerId = "charger_id", powerKw = "power_kw", statusSince = "status_since"
        case expectedChargeMin = "expected_charge_min", busyMin = "busy_min"
        case busyMinIsLowerBound = "busy_min_is_lower_bound", overstayMin = "overstay_min"
    }

    var isDC: Bool { `class`.hasPrefix("DC") }
    /// multi-plug connectors come as "IEC_62196_T2|CHADEMO"
    var plugTypes: [String] { type.split(separator: "|").map(String.init) }
}

struct Prediction: Codable {
    let pFree15min: Double
    let pFree30min: Double
    let pFree60min: Double
    /// may be negative (the session is already longer than expected)
    let expectedRemainingMin: Int
    /// "9 iš 10 kartų atsilaisvina per N min." (calibrated server side: 90 % in the backtest, AC and DC)
    let likelyByMin: Int?
    /// remaining minutes at meta.cdfQuantiles
    let remainingCdfMin: [Int]?
    let basis: String
    let basisN: Int
    let explain: String

    enum CodingKeys: String, CodingKey {
        case basis, explain
        case pFree15min = "p_free_15min", pFree30min = "p_free_30min", pFree60min = "p_free_60min"
        case expectedRemainingMin = "expected_remaining_min", basisN = "basis_n"
        case likelyByMin = "likely_by_min", remainingCdfMin = "remaining_cdf_min"
    }
}

enum ConnectorStatus {
    static let free = "Laisva", busy = "Užimta", broken = "Neveikia", unknown = "Nežinoma"
}
