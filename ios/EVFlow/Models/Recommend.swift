import Foundation
import MapKit

private func mapItem(_ c: CLLocationCoordinate2D) -> MKMapItem {
    if #available(iOS 26, *) { return MKMapItem(location: CLLocation(latitude: c.latitude, longitude: c.longitude), address: nil) }
    return MKMapItem(placemark: MKPlacemark(coordinate: c))
}

/// Apple Maps hand-off.
func openInAppleMaps(_ v: StationView) {
    let item = mapItem(v.coordinate)
    item.name = v.s.name
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
}

/// Route screen: if waiting here on arrival is long (> 10 min) and another station is at least 5 min better
/// (drive + wait), suggest it.
func betterOption(than current: Reco, among recos: [Reco]) -> Reco? {
    guard current.wait > Rewards.longWaitMin else { return nil }
    return recos.filter { $0.id != current.id && $0.score <= current.score - Rewards.betterByMin }.min { $0.score < $1.score }
}

/// Driving ETAs from MKDirections, cached per station while the user stays within ~300 m (Apple throttles ETA requests).
@MainActor
final class ETACache {
    private var cache: [String: (from: CLLocationCoordinate2D, at: Date, min: Int)] = [:]

    func minutes(from: CLLocationCoordinate2D, to v: StationView) async -> Int {
        if let c = cache[v.id], haversineKm(c.from, from) < 0.3, Date.now.timeIntervalSince(c.at) < 600 { return c.min }
        let req = MKDirections.Request()
        req.source = mapItem(from)
        req.destination = mapItem(v.coordinate)
        req.transportType = .automobile
        guard let r = try? await MKDirections(request: req).calculateETA() else {
            return driveMinutes(haversineKm(from, v.coordinate)) // offline: estimate, don't cache
        }
        let m = max(1, Int((r.expectedTravelTime / 60).rounded()))
        cache[v.id] = (from, .now, m)
        return m
    }
}

/// Where to go now: the 10 nearest suitable stations (straight line), ranked by real drive time + expected wait on arrival.
@MainActor
func recommend(_ views: [StationView], from user: CLLocationCoordinate2D, plugType: String?,
               now: Date, eta: ETACache, nearest: Int = 10) async -> [Reco] {
    let here = CLLocation(latitude: user.latitude, longitude: user.longitude)
    let near = views
        .filter { isRecommendable($0.s, plugType: plugType) }
        .map { v in (v, here.distance(from: CLLocation(latitude: v.coordinate.latitude, longitude: v.coordinate.longitude))) }
        .sorted { $0.1 < $1.1 }
        .prefix(nearest)
    var out: [Reco] = []
    await withTaskGroup(of: Reco.self) { g in
        for (v, meters) in near {
            g.addTask { @MainActor in
                let drive = await eta.minutes(from: user, to: v)
                let h = vilniusHour(now.addingTimeInterval(Double(drive) * 60))
                return Reco(v: v, km: meters / 1000, drive: drive, wait: arrivalWait(v.s, driveMin: drive, lag: v.lag, arrivalHour: h))
            }
        }
        for await r in g { out.append(r) }
    }
    return out.sorted { ($0.score, $0.km) < ($1.score, $1.km) }
}
