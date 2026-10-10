import Foundation
import CoreLocation
import Testing
@testable import EVFlow

private let t0 = Date(timeIntervalSince1970: 1_791_000_000)

private func connector(status: String = ConnectorStatus.busy, expected: Int = 39, busy: Int? = 20, overstay: Bool? = false,
                       remaining: Int? = 23, since: Date? = nil, kw: Double = 150, cls: String = "DC_150") -> Connector {
    Connector(id: "C1", chargerId: "CH1", type: "IEC_62196_T2_COMBO", powerKw: kw, class: cls, tariff: "0.42 €/kWh",
              restriction: nil, status: status, statusSince: since, expectedChargeMin: expected,
              busyMin: status == ConnectorStatus.busy ? busy : nil, busyMinIsLowerBound: false,
              overstay: status == ConnectorStatus.busy ? overstay : nil, overstayMin: 0,
              prediction: remaining.map { Prediction(pFree15min: 0.2, pFree30min: 0.6, pFree60min: 0.9, expectedRemainingMin: $0, likelyByMin: nil, remainingCdfMin: nil,
                                                     basis: "stotelės istorija", basisN: 25, explain: "…") })
}

/// Minimal station JSON; `extra` overrides / adds top-level fields.
private func station(free: Int, expectedWait: Int?, waitByHour: Int? = nil, extra: String = "") throws -> Station {
    let fbh = waitByHour.map { w in
        #"{"free_prob": [\#(Array(repeating: "0.5", count: 24).joined(separator: ","))], "wait_min": [\#(Array(repeating: "\(w)", count: 24).joined(separator: ","))], "confidence": 0.8}"#
    } ?? "null"
    let json = """
    {"id": "1", "name": "S", "operator": "Op, UAB", "address": "A", "city": "Vilnius", "lat": 54.7, "lon": 25.3,
     "max_power_kw": 150, "counts": {"total": 2, "free": \(free), "busy": \(2 - free), "broken": 0, "unknown": 0, "overstaying": 0},
     "expected_wait_min": \(expectedWait.map(String.init) ?? "null"),
     "reliability": {"score": 90}, "history": {}, "groups": [], "forecast_by_hour": \(fbh), "connectors": [] \(extra)}
    """
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    return try d.decode(Station.self, from: Data(json.utf8))
}

struct RemainingNowTests {
    @Test func countsDownWithLag() {
        let c = connector(remaining: 23)
        #expect(c.remainingNow(lag: 0) == 23)
        #expect(c.remainingNow(lag: 5) == 18)
        #expect(freesInText(remainingNow: 23) == "Atsilaisvins per ~25 min.")
        #expect(freesInText(remainingNow: 120) == "Atsilaisvins per ~2 val.")
    }

    @Test func lagPastPredictionMeansAnyMinute() {
        let c = connector(remaining: 10)
        let rem = c.remainingNow(lag: 14)!
        #expect(rem == -4)
        #expect(freesInText(remainingNow: rem) == "Turėtų atsilaisvinti bet kurią minutę")
    }

    @Test func busyNowAddsLag() {
        #expect(connector(busy: 20).busyNow(lag: 7) == 27)
        #expect(connector(status: ConnectorStatus.free).busyNow(lag: 7) == nil)
    }
}

struct OverstayNowTests {
    @Test func flipsExactlyAfterExpectedChargeMin() {
        let c = connector(expected: 39, busy: 30, overstay: false)
        #expect(!c.overstayNow(lag: 9))   // 39 min = still allowed
        #expect(c.overstayNow(lag: 10))   // 40 min
        #expect(c.overstayByNow(lag: 10) == 1)
    }

    @Test func serverFlagWins() {
        #expect(connector(expected: 39, busy: 50, overstay: true).overstayNow(lag: 0))
        // server exempted it (e.g. overnight AC) – lag alone must not override that
        #expect(!connector(expected: 211, busy: 229, overstay: false).overstayNow(lag: 3))
    }

    @Test func onlyBusyConnectorsOverstay() {
        #expect(!connector(status: ConnectorStatus.free).overstayNow(lag: 500))
    }
}

struct ArrivalWaitTests {
    @Test func freeAndCloseUsesLiveData() throws {
        let s = try station(free: 1, expectedWait: 0)
        #expect(arrivalWait(s, driveMin: 10, lag: 2, arrivalHour: 12) == 0)
    }

    @Test func withinAnHourUsesExpectedWaitMinusLagAndDrive() throws {
        let s = try station(free: 0, expectedWait: 40, waitByHour: 99)
        #expect(arrivalWait(s, driveMin: 20, lag: 5, arrivalHour: 12) == 15)
        #expect(arrivalWait(s, driveMin: 50, lag: 5, arrivalHour: 12) == 0)
    }

    @Test func farAwayUsesHourlyForecastOr15() throws {
        #expect(arrivalWait(try station(free: 0, expectedWait: 40, waitByHour: 7), driveMin: 75, lag: 0, arrivalHour: 18) == 7)
        #expect(arrivalWait(try station(free: 0, expectedWait: nil), driveMin: 30, lag: 0, arrivalHour: 18) == 15)
    }
}

private let station = CLLocationCoordinate2D(latitude: 54.7225, longitude: 25.3373)
private let atStation = CLLocation(latitude: 54.7226, longitude: 25.3374)        // ~15 m away
private let farAway = CLLocation(latitude: 54.7315, longitude: 25.3373)          // ~1 km away

struct CanStartChargingTests {
    @Test func freeIsAllowed() {
        #expect(canStartCharging(connector(status: ConnectorStatus.free), lag: 3, userLocation: atStation, station: station) == .allowed)
    }

    @Test func justBusyIsProbablyYou() {
        // busy 2 min in the snapshot + 3 min lag = 5 min
        #expect(canStartCharging(connector(busy: 2), lag: 3, userLocation: atStation, station: station) == .allowed)
    }

    @Test func busyLongerIsDenied() {
        #expect(canStartCharging(connector(busy: 37), lag: 3, userLocation: atStation, station: station) == .denied("Ši jungtis užimta jau 40 min."))
    }

    @Test func brokenIsDenied() {
        #expect(canStartCharging(connector(status: ConnectorStatus.broken), lag: 0, userLocation: atStation, station: station) == .denied("Jungtis neveikia"))
    }

    @Test func unknownWarns() {
        #expect(canStartCharging(connector(status: ConnectorStatus.unknown), lag: 0, userLocation: atStation, station: station)
                == .allowedWithWarning("Stotelė nesiunčia būsenos"))
    }

    @Test func tooFarIsDenied() {
        #expect(canStartCharging(connector(status: ConnectorStatus.free), lag: 0, userLocation: farAway, station: station) == .denied("Būk prie stotelės"))
    }

    @Test func noLocationPermissionSkipsDistance() {
        #expect(canStartCharging(connector(status: ConnectorStatus.free), lag: 0, userLocation: nil, station: station) == .allowed)
    }
}

struct ExpectedMinutesTests {
    private func h(_ mins: [Int], cls: String = "DC_150") -> [ChargeHistoryItem] { mins.map { .init(connectorClass: cls, durationMin: $0) } }
    private let c = connector(status: ConnectorStatus.free, expected: 39)   // DC_150

    @Test func noHistoryUsesFeed() {
        #expect(expectedMinutes(c, history: []) == (39, .feed))
        #expect(expectedMinutes(c, history: h([30, 40])) == (39, .feed))            // < 3 sessions
        #expect(expectedMinutes(c, history: h([30, 40, 50], cls: "AC_22")) == (39, .feed)) // other class
    }

    @Test func threeSessionsUseTheirMedian() {
        #expect(expectedMinutes(c, history: h([50, 30, 40])) == (40, .history))
        #expect(expectedMinutes(c, history: h([30, 40, 50, 60])) == (45, .history))
    }

    @Test func medianIsClampedTo0_5xAnd2x() {
        #expect(expectedMinutes(c, history: h([200, 210, 220])) == (78, .history))  // 2 × 39
        #expect(expectedMinutes(c, history: h([5, 6, 7])) == (20, .history))        // 0.5 × 39 = 19.5
    }
}

struct QRMatchTests {
    private func conn(_ id: String) -> Connector {
        Connector(id: id, chargerId: "CH", type: "IEC_62196_T2", powerKw: 22, class: "AC_22", tariff: nil, restriction: nil,
                  status: ConnectorStatus.free, statusSince: nil, expectedChargeMin: 200, busyMin: nil, busyMinIsLowerBound: nil,
                  overstay: nil, overstayMin: nil, prediction: nil)
    }
    private var station: [Connector] { [conn("IGN-E-00-0-A"), conn("IGN-E-00-0-B")] }

    @Test func plainId() {
        #expect(matchConnector(qr: "IGN-E-00-0-A", station: station, all: [])?.id == "IGN-E-00-0-A")
    }

    @Test func eMobilityIdWithStars() {
        #expect(matchConnector(qr: "LT*IGN*E000A", station: station, all: [])?.id == "IGN-E-00-0-A")
    }

    @Test func urlWithEvseParameter() {
        #expect(matchConnector(qr: "https://pay.example.lt/start?evse=IGN-E-00-0-A", station: station, all: [])?.id == "IGN-E-00-0-A")
    }

    @Test func unknownCode() {
        #expect(matchConnector(qr: "HELLO WORLD", station: station, all: [conn("008-E-0012-A")]) == nil)
    }

    @Test func otherStationsAndLongestWins() {
        // not at this station → search everywhere; "…0" and "…0-A" both fit, the longer id wins
        #expect(matchConnector(qr: "LT*ELD*0080012A", station: station, all: [conn("008-0012"), conn("008-0012-A")])?.id == "008-0012-A")
        #expect(normalizeEVSE(" lt*ign-e 00_0a ") == "LTIGNE000A")
    }
}

struct NavURLTests {
    private let c = CLLocationCoordinate2D(latitude: 54.7225, longitude: 25.3373)

    @Test func googleMaps() {
        #expect(NavApp.google.url(to: c)?.absoluteString == "comgooglemaps://?daddr=54.7225,25.3373&directionsmode=driving")
    }

    @Test func waze() {
        #expect(NavApp.waze.url(to: c)?.absoluteString == "waze://?ll=54.7225,25.3373&navigate=yes")
    }

    @Test func appleMapsGoesThroughMapKit() {
        // Apple Maps opens via MKMapItem.openInMaps (no URL scheme); "here" is our own route screen
        #expect(NavApp.apple.url(to: c) == nil && NavApp.inApp.url(to: c) == nil)
        #expect(NavApp.apple.probe == nil) // always installed, no canOpenURL needed
    }

    @Test func arrivalPrompt() {
        let near = CLLocation(latitude: 54.7230, longitude: 25.3373)            // ~55 m
        #expect(shouldOfferArrival(target: c, pickedAt: t0, user: near, now: t0.addingTimeInterval(3600)))
        #expect(!shouldOfferArrival(target: c, pickedAt: t0, user: near, now: t0.addingTimeInterval(4 * 3600)))   // too old
        #expect(!shouldOfferArrival(target: c, pickedAt: t0, user: CLLocation(latitude: 54.73, longitude: 25.3373), now: t0)) // ~830 m
        #expect(!shouldOfferArrival(target: c, pickedAt: t0, user: nil, now: t0))  // no location permission
    }
}

struct RewardsTests {
    private func at(_ min: Int) -> Date { t0.addingTimeInterval(Double(min) * 60) }

    @Test func onTimeGetsPointsAndReputation() {
        // 40 min charge, cable out at 50 min (deadline + 10 grace)
        let o = Rewards.outcome(startedAt: t0, endedAt: at(40 + Rewards.graceMin), chargeMin: 40, extensions: 0)
        #expect(o == .init(points: Rewards.onTimePoints, reputationDelta: Rewards.onTimeReputation, lateMin: 0))
    }

    @Test func late20MinLosesTwoReputation() {
        let o = Rewards.outcome(startedAt: t0, endedAt: at(40 + Rewards.graceMin + 20), chargeMin: 40, extensions: 0)
        #expect(o == .init(points: 0, reputationDelta: -2, lateMin: 20))
    }

    @Test func twoExtensionsMoveTheDeadline() {
        // 40 + 2 × 15 = 70 min, + 10 grace: 80 min is still on time
        #expect(Rewards.outcome(startedAt: t0, endedAt: at(80), chargeMin: 40, extensions: 2).onTime)
        #expect(!Rewards.outcome(startedAt: t0, endedAt: at(81), chargeMin: 40, extensions: 2).onTime)
    }

    @Test func reputationStaysInRange() {
        #expect(Rewards.clampReputation(104) == 100)
        #expect(Rewards.clampReputation(-3) == 0)
    }
}

struct SessionVerdictTests {
    private func at(_ min: Int) -> Date { t0.addingTimeInterval(Double(min) * 60) }

    @Test func endsWhenFreedAfterBeingSeenBusy() {
        let freed = connector(status: ConnectorStatus.free, since: at(45))
        #expect(evaluateSession(startedAt: t0, seenBusy: true, manualEndAt: nil, connector: freed, dataUntil: at(46), now: at(47)) == .ended(at(45)))
    }

    @Test func neverSeenChargingIsUnconfirmed() {
        // still "Laisva" (from before we started) 11 min later → dropped, no points
        let stillFree = connector(status: ConnectorStatus.free, since: t0.addingTimeInterval(-600))
        #expect(evaluateSession(startedAt: t0, seenBusy: false, manualEndAt: nil, connector: stillFree, dataUntil: at(9), now: at(5)) == .running)
        #expect(evaluateSession(startedAt: t0, seenBusy: false, manualEndAt: nil, connector: stillFree, dataUntil: at(10), now: at(11)) == .unconfirmed)
    }

    @Test func baigiauButStillBusyGivesNoPoints() {
        let busy = connector(busy: 60)
        // just tapped: keep waiting, nothing scored
        #expect(evaluateSession(startedAt: t0, seenBusy: true, manualEndAt: at(50), connector: busy, dataUntil: at(55), now: at(56)) == .running)
        // still plugged in 10+ min later: ask about the cable, still nothing scored
        #expect(evaluateSession(startedAt: t0, seenBusy: true, manualEndAt: at(50), connector: busy, dataUntil: at(61), now: at(62)) == .stillPlugged)
    }
}

struct FeedDecodingTests {
    @Test func decodesWithMissingOptionals() throws {
        let json = """
        {"meta": {"generated_utc": "2026-10-09T20:50:50Z", "data_until_utc": "2026-10-09T20:50:37Z"},
         "stations": [{
           "id": "2831", "name": "Test", "operator": "In Balance grid, UAB", "address": "Gatvė 1", "city": "Vilnius",
           "lat": null, "open_24_7": null, "max_power_kw": 22,
           "counts": {"total": 1, "free": 0, "busy": 1, "broken": 0, "unknown": 0, "overstaying": 0},
           "expected_wait_min": null,
           "reliability": {"score": 40, "never_used": true},
           "history": {"busy_by_hour": [null, 0.2]},
           "groups": [{"type": "IEC_62196_T2", "power_kw": 22, "count": 1, "free": 0}],
           "connectors": [{
             "id": "A", "charger_id": "CH", "type": "IEC_62196_T2", "power_kw": 22, "class": "AC_22",
             "status": "Užimta", "status_since": "2026-10-09T16:24:23Z", "expected_charge_min": 211, "busy_min": 4
           }]
         }]}
        """
        let f = try Feed.decode(Data(json.utf8))
        let s = try #require(f.stations.first)
        #expect(f.meta.historyDays == nil)
        #expect(s.coordinate == nil && s.lon == nil && s.open24_7 == nil && s.openNow == nil && s.payments == nil)
        #expect(s.forecastByHour == nil && s.expectedWaitMin == nil)
        #expect(stationHeadline(s, lag: 3) == "Užimta")
        #expect(reliabilityLevel(s.reliability) == .neverUsed)
        let c = try #require(s.connectors.first)
        #expect(c.class == "AC_22" && c.tariff == nil && c.prediction == nil && c.overstay == nil)
        #expect(c.busyNow(lag: 3) == 7)
        #expect(!isRecommendable(s, plugType: nil)) // no coordinates
    }

    @Test func decodesBundledSnapshot() throws {
        let url = try #require(Bundle.main.url(forResource: "stations", withExtension: "json"))
        let f = try Feed.decode(Data(contentsOf: url))
        #expect(f.stations.count > 1000)
    }
}

// MARK: - availability levels, 9-of-10 times, map filter

/// Station with history levels (12:00 green via `level`, 18:00 red, 09:00 null) and a 9-of-10 wait time.
private func availStation(level: String? = "green", hours: [Int: String] = [18: "red"], waitLikely: Int? = 40,
                          expectedWait: Int? = 15, free: Int = 0) throws -> Station {
    let byHour = (0..<24).map { h in hours[h].map { "\"\($0)\"" } ?? (h == 9 ? "null" : "\"\(level ?? "green")\"") }.joined(separator: ",")
    let lvl = level.map { "\"\($0)\"" } ?? "null"
    return try station(free: free, expectedWait: expectedWait, extra: """
    , "wait_likely_by_min": \(waitLikely.map(String.init) ?? "null"),
      "availability": {"level": \(lvl), "level_overall": "green", "free_share_overall": 0.87, "level_by_hour": [\(byHour)]}
    """)
}

/// Vilnius wall-clock time on 2026-10-10.
private func vilniusTime(_ h: Int, _ m: Int = 0) -> Date {
    var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 10; c.hour = h; c.minute = m
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Vilnius")!
    return cal.date(from: c)!
}

private let feedLevels = AvailabilityLevels(green: 0.8, yellow: 0.5,
                                            labels: ["green": "Dažniausiai laisva", "yellow": "Kartais užimta", "red": "Dažnai užimta"])

struct AvailabilityTests {
    @Test func newFieldsDecodeAndOldFeedStillDoes() throws {
        let json = """
        {"meta": {"generated_utc": "2026-10-10T09:52:36Z", "data_until_utc": "2026-10-10T09:52:22Z", "history_days": 3.83,
                  "availability_levels": {"green": 0.8, "yellow": 0.5, "labels": {"green": "Dažniausiai laisva", "red": "Dažnai užimta"}},
                  "cdf_quantiles": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95]},
         "stations": [{"id": "1", "name": "S", "operator": "O", "address": "A", "city": "V", "max_power_kw": 50,
           "counts": {"total": 1, "free": 0, "busy": 1, "broken": 0, "unknown": 0, "overstaying": 0},
           "expected_wait_min": 18, "wait_likely_by_min": 45, "wait_cdf_min": [3, 6, 9, 12, 15, 19, 24, 30, 45, 52],
           "availability": {"level": null, "level_overall": "yellow", "free_share_overall": 0.6, "level_by_hour": [null, "red"]},
           "reliability": {"score": 90}, "history": {}, "groups": [],
           "connectors": [{"id": "A", "charger_id": "C", "type": "IEC_62196_T2_COMBO", "power_kw": 50, "class": "DC_50",
             "status": "Užimta", "expected_charge_min": 45, "busy_min": 12,
             "prediction": {"p_free_15min": 0.4, "p_free_30min": 0.6, "p_free_60min": 0.9, "expected_remaining_min": 18,
                            "likely_by_min": 50, "remaining_cdf_min": [2, 6, 10, 15, 18, 30, 38, 45, 50, 70],
                            "basis": "b", "basis_n": 25, "explain": "e"}}]}]}
        """
        let f = try Feed.decode(Data(json.utf8))
        #expect(f.meta.availabilityLevels?.green == 0.8 && f.meta.cdfQuantiles?.last == 0.95)
        let s = try #require(f.stations.first)
        #expect(s.waitLikelyByMin == 45 && s.waitCdfMin?.count == 10 && s.availability?.levelOverall == "yellow")
        #expect(s.availability?.levelByHour?[1] == "red" && s.availability?.levelByHour?[0] == .some(nil))
        let p = try #require(s.connectors.first?.prediction)
        #expect(p.likelyByMin == 50 && p.remainingCdfMin?.last == 70)

        // the previous format (8-of-10 ranges, meta.interval) still decodes; its p80 is not shown as "9 iš 10"
        let old = """
        {"meta": {"generated_utc": "2026-10-10T09:02:33Z", "data_until_utc": "2026-10-10T09:02:22Z", "interval": "8 iš 10"},
         "stations": [{"id": "1", "name": "S", "operator": "O", "address": "A", "city": "V", "max_power_kw": 50,
           "counts": {"total": 1, "free": 0, "busy": 1, "broken": 0, "unknown": 0, "overstaying": 0},
           "expected_wait_min": 18, "wait_range_min": [0, 45], "reliability": {"score": 90}, "history": {}, "groups": [],
           "connectors": [{"id": "A", "charger_id": "C", "type": "IEC_62196_T2_COMBO", "power_kw": 50, "class": "DC_50",
             "status": "Užimta", "expected_charge_min": 45, "busy_min": 12,
             "prediction": {"p_free_15min": 0.4, "p_free_30min": 0.6, "p_free_60min": 0.9, "expected_remaining_min": 18,
                            "remaining_range_min": [0, 45], "basis": "b", "basis_n": 25, "explain": "e"}}]}]}
        """
        let o = try Feed.decode(Data(old.utf8))
        let os = try #require(o.stations.first)
        #expect(o.meta.cdfQuantiles == nil && os.waitLikelyByMin == nil && os.waitCdfMin == nil)
        #expect(os.connectors.first?.prediction?.likelyByMin == nil && os.connectors.first?.prediction?.remainingCdfMin == nil)
        #expect(stationHeadline(os, lag: 0) == "Laukimas ~18 min.")
        // the minimal test station (no availability / 9-of-10 fields) still decodes
        let bare = try station(free: 1, expectedWait: 0)
        #expect(bare.availability == nil && bare.waitLikelyByMin == nil)
    }

    @Test func arrivalLevelUsesTheHourThenTheCurrentLevel() throws {
        let s = try availStation()
        #expect(arrivalLevel(s, arrivalHour: 18) == .red)
        #expect(arrivalLevel(s, arrivalHour: 9) == .green)        // null that hour → current level
        #expect(arrivalLevel(try station(free: 1, expectedWait: 0), arrivalHour: 9) == nil)
    }

    @Test func availabilityTextNowOrAtTheHour() throws {
        let s = try availStation()
        #expect(availabilityText(s, arrival: vilniusTime(12, 20), now: vilniusTime(12, 5), levels: feedLevels) == "Dažniausiai laisva šiuo metu")
        #expect(availabilityText(s, arrival: vilniusTime(18, 10), now: vilniusTime(12, 5), levels: feedLevels) == "Populiari: dažnai užimta 18:00")
    }

    @Test func namesComeFromTheFeed() throws {
        let custom = AvailabilityLevels(green: 0.9, yellow: 0.6, labels: ["green": "Visada laisva"])
        #expect(availabilityText(try availStation(), arrival: vilniusTime(12), now: vilniusTime(12), levels: custom) == "Visada laisva šiuo metu")
    }

    @Test func freeShareLine() throws {
        #expect(freeShareText(try availStation(), historyDays: 3.79) == "Per 4 d. laisva vieta buvo 87 % laiko")
        #expect(freeShareText(try availStation(), historyDays: nil) == nil)
    }

    @Test func longDriveUsesTheHistoryLevelInsteadOfPercent() throws {
        // 12:05 + 6 h drive → 18:05 arrival, red that hour
        #expect(arrivalText(try availStation(), driveMin: 360, lag: 0, now: vilniusTime(12, 5), levels: feedLevels) == "Populiari: dažnai užimta 18:00")
    }
}

struct LikelyTests {
    @Test func compactRowShowsTheNineOfTenTime() {
        // likely_by_min 45, 5 min lag → "iki 40 min."
        #expect(freesInShortLikely(remainingNow: 23, likelyBy: 45, lag: 5) == "~25 min. · iki 40 min.")
        #expect(freesInShortLikely(remainingNow: 23, likelyBy: 26, lag: 0) == "~25 min.")   // adds nothing
        #expect(freesInShortLikely(remainingNow: 23, likelyBy: nil, lag: 0) == "~25 min.")
    }

    @Test func connectorSentence() {
        #expect(likelySentence(remainingNow: 23, likelyBy: 45, lag: 5) == "Greičiausiai ~25 min. · 9 iš 10 kartų per 40 min.")
        #expect(likelySentence(remainingNow: -2, likelyBy: 4, lag: 6) == "Greičiausiai bet kurią minutę · 9 iš 10 kartų jau būtų atsilaisvinusi")
        #expect(likelySentence(remainingNow: 23, likelyBy: nil, lag: 0) == nil)   // older feed: no 9-of-10 line
    }

    @Test func overThreeHoursIsHardToPredict() {
        #expect(likelySentence(remainingNow: 60, likelyBy: 180, lag: 0) == "Greičiausiai ~60 min. · 9 iš 10 kartų per 3 val.")
        #expect(likelySentence(remainingNow: 60, likelyBy: 245, lag: 5) == "Sunku nuspėti: gali užtrukti iki 4 val.")
        // decided on the feed value: the lag doesn't bring it back under 3 h between refreshes
        #expect(likelySentence(remainingNow: 60, likelyBy: 183, lag: 6) == "Sunku nuspėti: gali užtrukti iki 3 val.")
        #expect(!hardToPredict(180) && hardToPredict(181) && !hardToPredict(nil))
    }

    @Test func stationWaitUsesWaitLikelyBy() throws {
        let s = try availStation(waitLikely: 40, expectedWait: 15)
        #expect(waitShortLikely(s, lag: 0) == "~15 min. · iki 40 min.")
        #expect(stationHeadline(s, lag: 0) == "Laukimas ~15 min. · iki 40 min.")
        #expect(waitShortLikely(try availStation(waitLikely: 0, expectedWait: 0, free: 1), lag: 0) == nil)
    }

    @Test func stationWaitHardToPredict() throws {
        let s = try availStation(waitLikely: 400, expectedWait: 35)
        #expect(waitShortLikely(s, lag: 10) == "Sunku nuspėti: gali užtrukti iki 6,5 val.")
        #expect(stationHeadline(s, lag: 10) == "Sunku nuspėti: gali užtrukti iki 6,5 val.")
    }

    @Test func hardToPredictSuggestsTheNearestFreeStation() throws {
        func v(_ id: String, free: Int) throws -> StationView {
            let s = try station(free: free, expectedWait: free > 0 ? 0 : 30)
            let copy = Station(id: id, name: id, operator: s.operator, address: s.address, city: s.city, lat: s.lat, lon: s.lon,
                               open24_7: nil, openNow: nil, payments: nil, maxPowerKw: 150, counts: s.counts,
                               expectedWaitMin: s.expectedWaitMin, waitLikelyByMin: nil, waitCdfMin: nil, availability: nil,
                               reliability: s.reliability, history: s.history, groups: [], forecastByHour: nil, connectors: [])
            return try #require(makeView(copy, lag: 0))
        }
        let here = Reco(v: try v("here", free: 0), km: 1, drive: 3, wait: 30)
        let busyClose = Reco(v: try v("busy-close", free: 0), km: 1, drive: 2, wait: 20)
        let freeFar = Reco(v: try v("free-far", free: 2), km: 6, drive: 12, wait: 0)
        let freeNear = Reco(v: try v("free-near", free: 1), km: 3, drive: 7, wait: 0, busyAtArrival: true)
        #expect(nearestFreeOption(than: here, among: [here, busyClose, freeFar, freeNear])?.id == "free-near")
        #expect(nearestFreeOption(than: here, among: [here, busyClose]) == nil)
    }
}

struct AvailabilityRecommendTests {
    @Test func redAtArrivalCostsTenMinutes() throws {
        let v = try #require(makeView(try availStation(), lag: 0))
        let calm = Reco(v: v, km: 2, drive: 8, wait: 0)
        let busy = Reco(v: v, km: 2, drive: 8, wait: 0, busyAtArrival: true)
        #expect(calm.score == 8 && busy.score == 18)
        #expect(busy.explanation == "8 min. kelio + ~0 min. laukimo · dažnai užimta tuo metu")
        #expect(busyAtArrival(v.s, arrivalHour: 18) && !busyAtArrival(v.s, arrivalHour: 12))
    }

    @Test func brokenAndSilentStationsAreHiddenByDefault() {
        #expect(!showsOnMap(pin: .broken, selected: false, showBroken: false))
        #expect(!showsOnMap(pin: .stale, selected: false, showBroken: false))
        #expect(showsOnMap(pin: .broken, selected: true, showBroken: false))   // selected is always shown
        #expect(showsOnMap(pin: .stale, selected: false, showBroken: true))
        #expect(showsOnMap(pin: .busy, selected: false, showBroken: false))
    }
}

struct HomeFilterTests {
    private func view(kw: Int, cls: String, tariff: String?, free: Int = 1) throws -> StationView {
        let t = tariff.map { "\"\($0)\"" } ?? "null"
        let s = try station(free: free, expectedWait: 0, extra: "")
        let json = """
        {"id": "C", "charger_id": "CH", "type": "IEC_62196_T2_COMBO", "power_kw": \(kw), "class": "\(cls)", "tariff": \(t),
         "status": "Laisva", "expected_charge_min": 40}
        """
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        let c = try d.decode(Connector.self, from: Data(json.utf8))
        let withConn = Station(id: s.id, name: s.name, operator: s.operator, address: s.address, city: s.city, lat: s.lat, lon: s.lon,
                               open24_7: nil, openNow: nil, payments: nil, maxPowerKw: Double(kw), counts: s.counts,
                               expectedWaitMin: 0, waitLikelyByMin: nil, waitCdfMin: nil, availability: nil, reliability: s.reliability, history: s.history,
                               groups: [], forecastByHour: nil, connectors: [c])
        return try #require(makeView(withConn, lag: 0))
    }

    @Test func fastMeansDC50Plus() throws {
        #expect(matchesFilter(try view(kw: 150, cls: "DC_150", tariff: nil), .fast))
        #expect(!matchesFilter(try view(kw: 22, cls: "AC_22", tariff: nil), .fast))
        #expect(matchesFilter(try view(kw: 22, cls: "AC_22", tariff: nil), .all))
    }

    @Test func cheapNeedsAPriceAndSortsByIt() throws {
        let cheap = try view(kw: 22, cls: "AC_22", tariff: "0.25 €/kWh"), dear = try view(kw: 150, cls: "DC_150", tariff: "0.49 €/kWh")
        #expect(!matchesFilter(try view(kw: 22, cls: "AC_22", tariff: nil), .cheap))
        let sorted = sortForFilter([Reco(v: dear, km: 1, drive: 2, wait: 0), Reco(v: cheap, km: 3, drive: 9, wait: 0)], filter: .cheap)
        #expect(sorted.first?.v.price == 0.25)
        #expect(sortForFilter([Reco(v: dear, km: 1, drive: 2, wait: 0), Reco(v: cheap, km: 3, drive: 9, wait: 0)], filter: .all).first?.v.price == 0.49)
    }
}

struct PlannerTests {
    @Test func usuallyFreeComesFirstThenWaitThenDistance() throws {
        let here = CLLocationCoordinate2D(latitude: 54.7, longitude: 25.3)
        func v(_ id: String, level18: String, km: Double) throws -> StationView {
            let byHour = (0..<24).map { $0 == 18 ? "\"\(level18)\"" : "\"green\"" }.joined(separator: ",")
            let s = try station(free: 1, expectedWait: 0, extra: """
            , "availability": {"level": "green", "level_overall": "green", "free_share_overall": 0.9, "level_by_hour": [\(byHour)]}
            """)
            let moved = Station(id: id, name: id, operator: s.operator, address: s.address, city: s.city,
                                lat: 54.7 + km / 111, lon: 25.3, open24_7: nil, openNow: nil, payments: nil, maxPowerKw: 150,
                                counts: s.counts, expectedWaitMin: 0, waitLikelyByMin: nil, waitCdfMin: nil, availability: s.availability,
                                reliability: s.reliability, history: s.history, groups: [], forecastByHour: nil,
                                connectors: [connector(status: ConnectorStatus.free)])
            return try #require(makeView(moved, lag: 0))
        }
        let near = try v("near-red", level18: "red", km: 1), far = try v("far-green", level18: "green", km: 6),
            mid = try v("mid-yellow", level18: "yellow", km: 3), tooFar = try v("too-far", level18: "green", km: 40)
        let plan = planStations([near, far, mid, tooFar], from: here, hour: 18, plugType: nil)
        #expect(plan.map(\.id) == ["far-green", "mid-yellow", "near-red"])   // 40 km one dropped
        #expect(planStations([near, far, mid], from: here, hour: 9, plugType: nil).first?.id == "near-red") // all green at 09 → closest
    }
}
