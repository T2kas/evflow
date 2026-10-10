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
              prediction: remaining.map { Prediction(pFree15min: 0.2, pFree30min: 0.6, pFree60min: 0.9, expectedRemainingMin: $0,
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
