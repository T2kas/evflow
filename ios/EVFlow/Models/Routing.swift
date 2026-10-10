import Foundation
import CoreLocation

struct RouteStep { let at: CLLocationCoordinate2D; let type: String; let modifier: String?; let name: String }

struct Route {
    let coords: [CLLocationCoordinate2D]
    let km: Double
    let minutes: Int
    let via: String
    let steps: [RouteStep]
    let cum: [Double]          // cumulative km along coords
    let stepAt: [Double]       // km along route where each step happens

    var total: Double { cum.last ?? 0 }

    /// Point + bearing at distance d (km) along the route.
    func along(_ d: Double) -> (CLLocationCoordinate2D, Double) {
        guard coords.count > 1 else { return (coords.first ?? startLocation, 0) }
        var i = cum.firstIndex(where: { $0 >= d }) ?? coords.count - 1
        i = max(1, i)
        let a = coords[i - 1], b = coords[i]
        let seg = max(cum[i] - cum[i - 1], 1e-9)
        let t = min(1, max(0, (d - cum[i - 1]) / seg))
        let p = CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                       longitude: a.longitude + (b.longitude - a.longitude) * t)
        let r = Double.pi / 180
        let y = sin((b.longitude - a.longitude) * r) * cos(b.latitude * r)
        let x = cos(a.latitude * r) * sin(b.latitude * r) - sin(a.latitude * r) * cos(b.latitude * r) * cos((b.longitude - a.longitude) * r)
        return (p, (atan2(y, x) / r + 360).truncatingRemainder(dividingBy: 360))
    }
}

// MARK: - Simulated drive (shared by the nav screen's text and the map's 60 fps camera)

/// 38 km/h shown on the speedometer, played back 8× faster.
let navSpeedKmh = 38.0
let navKmPerSec = navSpeedKmh * 8 / 3600

/// km driven along the route since `start`.
func navDistance(_ r: Route, start: Date, at now: Date) -> Double {
    min(r.total, max(0, now.timeIntervalSince(start)) * navKmPerSec)
}

func bearingDeg(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let r = Double.pi / 180
    let y = sin((b.longitude - a.longitude) * r) * cos(b.latitude * r)
    let x = cos(a.latitude * r) * sin(b.latitude * r) - sin(a.latitude * r) * cos(b.latitude * r) * cos((b.longitude - a.longitude) * r)
    return (atan2(y, x) / r + 360).truncatingRemainder(dividingBy: 360)
}

/// Direction of the road under the car: a short chord from 10 m behind to 15 m ahead.
func roadBearing(_ r: Route, at d: Double) -> Double {
    let a = r.along(max(0, d - 0.010)).0, b = r.along(min(r.total, d + 0.015)).0
    return bearingDeg(a, b)
}

private func cumulative(_ c: [CLLocationCoordinate2D]) -> [Double] {
    var out = [0.0]
    for i in 1..<max(1, c.count) { out.append(out[i - 1] + haversineKm(c[i - 1], c[i])) }
    return out
}

private func build(coords: [CLLocationCoordinate2D], km: Double, min: Int, via: String, steps: [RouteStep]) -> Route {
    let cum = cumulative(coords)
    // place each step on the nearest route vertex
    let stepAt = steps.map { s -> Double in
        var best = Double.infinity, bi = 0
        for (i, c) in coords.enumerated() {
            let d = abs(c.latitude - s.at.latitude) + abs(c.longitude - s.at.longitude)
            if d < best { best = d; bi = i }
        }
        return cum[bi]
    }
    return Route(coords: coords, km: km, minutes: min, via: via, steps: steps, cum: cum, stepAt: stepAt)
}

private struct BadJSON: Error {}
private func cast<T>(_ v: Any?) throws -> T { guard let t = v as? T else { throw BadJSON() }; return t }

/// Driving routes (best first, then alternatives) from the public OSRM demo server; straight line if offline.
func fetchRoutes(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> [Route] {
    let u = URL(string: "https://router.project-osrm.org/route/v1/driving/\(from.longitude),\(from.latitude);\(to.longitude),\(to.latitude)?overview=full&geometries=geojson&steps=true&alternatives=2")!
    do {
        var req = URLRequest(url: u); req.timeoutInterval = 6
        let (data, _) = try await URLSession.shared.data(for: req)
        let j: [String: Any] = try cast(try JSONSerialization.jsonObject(with: data))
        let routes: [[String: Any]] = try cast(j["routes"])
        let out = try routes.map(parseRoute)
        guard !out.isEmpty else { throw BadJSON() }
        return out
    } catch {
        let km = haversineKm(from, to) * 1.35
        return [build(coords: [from, to], km: km, min: driveMinutes(km / 1.35), via: "",
                      steps: [RouteStep(at: to, type: "arrive", modifier: nil, name: "")])]
    }
}

private func parseRoute(_ rt: [String: Any]) throws -> Route {
    let geom: [String: Any] = try cast(rt["geometry"])
    let coords = (try cast(geom["coordinates"]) as [[Double]]).map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    guard coords.count > 1, let leg = (try cast(rt["legs"]) as [[String: Any]]).first else { throw BadJSON() }
    let steps: [RouteStep] = try (try cast(leg["steps"]) as [[String: Any]]).map { s in
        let m: [String: Any] = try cast(s["maneuver"])
        let loc: [Double] = try cast(m["location"])
        return RouteStep(at: .init(latitude: loc[1], longitude: loc[0]), type: m["type"] as? String ?? "",
                         modifier: m["modifier"] as? String, name: s["name"] as? String ?? "")
    }
    var seen = Set<String>()
    let via = steps.map(\.name).filter { !$0.isEmpty && seen.insert($0).inserted }.prefix(3).joined(separator: ", ")
    let duration: Double = try cast(rt["duration"]), distance: Double = try cast(rt["distance"])
    // OSRM demo has no traffic: +25 % for city congestion
    return build(coords: coords, km: distance / 1000, min: Int((duration / 60 * 1.25).rounded()) + 1, via: via, steps: steps)
}

// MARK: - Speed limit (OpenStreetMap maxspeed via Overpass)

/// Returns the posted speed limit of the nearest road, or nil if OSM has none.
func fetchSpeedLimit(at c: CLLocationCoordinate2D) async -> Int? {
    let q = "[out:json][timeout:5];way(around:30,\(c.latitude),\(c.longitude))[highway][maxspeed];out tags 1;"
    var comps = URLComponents(string: "https://overpass-api.de/api/interpreter")!
    comps.queryItems = [URLQueryItem(name: "data", value: q)]
    guard let url = comps.url else { return nil }
    var req = URLRequest(url: url); req.timeoutInterval = 6
    guard let (data, _) = try? await URLSession.shared.data(for: req),
          let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let el = (j["elements"] as? [[String: Any]])?.first,
          let raw = (el["tags"] as? [String: String])?["maxspeed"] else { return nil }
    if let n = Int(raw.prefix { $0.isNumber }) , n > 0 { return n }
    switch raw { case "LT:urban": return 50; case "LT:rural": return 90; case "LT:motorway": return 130; default: return nil }
}
