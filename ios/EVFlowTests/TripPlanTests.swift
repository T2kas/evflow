import Foundation
import CoreLocation
import Testing
@testable import EVFlow

/// Straight 100 km route going north from (54.0, 25.0), 60 min, a vertex every ~1 km.
private func northRoute() -> Route {
    let coords = (0...100).map { CLLocationCoordinate2D(latitude: 54.0 + Double($0) * 0.009, longitude: 25.0) }
    var cum = [0.0]
    for i in 1..<coords.count { cum.append(cum[i - 1] + haversineKm(coords[i - 1], coords[i])) }
    return Route(coords: coords, km: cum.last!, minutes: 60, via: "", steps: [], cum: cum, stepAt: [])
}

/// Station at (lat, lon); `level` is the availability level for every hour; DC 150 kW unless `ac`.
private func tripStation(_ id: String, lat: Double, lon: Double = 25.0, level: String = "green", ac: Bool = false) throws -> StationView {
    let byHour = Array(repeating: "\"\(level)\"", count: 24).joined(separator: ",")
    let cls = ac ? "AC_22" : "DC_150", type = ac ? "IEC_62196_T2" : "IEC_62196_T2_COMBO", kw = ac ? 22 : 150
    let json = """
    {"id": "\(id)", "name": "S\(id)", "operator": "Op", "address": "A", "city": "X", "lat": \(lat), "lon": \(lon),
     "max_power_kw": \(kw), "counts": {"total": 1, "free": 1, "busy": 0, "broken": 0, "unknown": 0, "overstaying": 0},
     "expected_wait_min": 0, "reliability": {"score": 90}, "history": {}, "groups": [],
     "availability": {"level": "\(level)", "level_overall": "\(level)", "free_share_overall": 0.8, "level_by_hour": [\(byHour)]},
     "connectors": [{"id": "C\(id)", "charger_id": "CH\(id)", "type": "\(type)", "power_kw": \(kw), "class": "\(cls)",
                     "status": "Laisva", "expected_charge_min": 40}]}
    """
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    return try #require(makeView(try d.decode(Station.self, from: Data(json.utf8)), lag: 0))
}

struct TripPlanTests {
    @Test func suggestedStopCount() {
        #expect(suggestedStops(totalKm: 100) == 0)
        #expect(suggestedStops(totalKm: 310) == 1)
        #expect(suggestedStops(totalKm: 450) == 2)
        #expect(suggestedStops(totalKm: 2000) == Trip.maxStops)
    }

    @Test func stopTimesSpreadAndClamp() {
        #expect(defaultStopMinutes(count: 1, driveMin: 90) == [45])
        #expect(defaultStopMinutes(count: 2, driveMin: 90) == [30, 60])
        #expect(defaultStopMinutes(count: 0, driveMin: 90).isEmpty)
        let s = [30, 60]
        #expect(clampStop(80, index: 0, stops: s, driveMin: 90) == 55)   // stays before the next stop
        #expect(clampStop(10, index: 1, stops: s, driveMin: 90) == 35)   // stays after the previous one
        #expect(clampStop(90, index: 1, stops: s, driveMin: 90) == 85)   // not at the very end
        #expect(clampStop(0, index: 0, stops: s, driveMin: 90) == Trip.edgeMin)
    }

    @Test func routeIndexKeepsOnlyStationsNearTheRoute() throws {
        let r = northRoute()
        let near = try tripStation("near", lat: 54.45, lon: 25.01)    // ~0.6 km off, ~50 km along
        let far = try tripStation("far", lat: 54.45, lon: 25.2)       // ~13 km off
        let idx = RouteIndex(route: r, views: [near, far], plugType: nil)
        #expect(idx.hits.map(\.v.id) == ["near"])
        let h = try #require(idx.hits.first)
        #expect(abs(h.alongKm - 50) < 1.5 && h.offKm < 1)
    }

    @Test func pickPrefersUsuallyFreeAndFastNearTheChosenPoint() throws {
        let r = northRoute()
        let busy = try tripStation("busy", lat: 54.45, level: "red")
        let free = try tripStation("free", lat: 54.48, level: "green")
        let slow = try tripStation("slow", lat: 54.45, level: "green", ac: true)
        let early = try tripStation("early", lat: 54.05, level: "green")   // ~5 km along: outside the window
        let idx = RouteIndex(route: r, views: [busy, free, slow, early], plugType: nil)
        #expect(pickStop(idx, aroundKm: 50, total: r.total, hour: 14)?.v.id == "free")
        #expect(pickStop(idx, aroundKm: 50, total: r.total, hour: 14, excluding: ["free"])?.v.id == "slow"
                || pickStop(idx, aroundKm: 50, total: r.total, hour: 14, excluding: ["free"])?.v.id == "busy")
    }

    @Test func planUsesEachStationOnceAndShiftsLaterArrivals() throws {
        let r = northRoute()
        let a = try tripStation("a", lat: 54.3), b = try tripStation("b", lat: 54.6)
        let idx = RouteIndex(route: r, views: [a, b], plugType: nil)
        let t0 = Date(timeIntervalSince1970: 1_791_000_000)
        let plan = planTrip(route: r, index: idx, stopMinutes: [20, 40], depart: t0)
        #expect(plan.map { $0.hit?.v.id } == ["a", "b"])
        #expect(plan[0].arrival == t0.addingTimeInterval(20 * 60))
        #expect(plan[1].arrival == t0.addingTimeInterval(Double(40 + Trip.stopMin) * 60))
        #expect(plan.allSatisfy { $0.level == .green })
        #expect(tripArrival(depart: t0, driveMin: 60, stops: 2) == t0.addingTimeInterval(Double(60 + 2 * Trip.stopMin) * 60))
    }

    @Test func formatting() {
        #expect(fmtDuration(45) == "45 min.")
        #expect(fmtDuration(60) == "1 val.")
        #expect(fmtDuration(85) == "1 val. 25 min.")
        #expect(abs(routeKm(atMinute: 30, route: northRoute()) - northRoute().total / 2) < 0.01)
    }
}
