import Foundation
import CoreLocation

/// Where "Važiuoti" hands the drive over to.
enum NavApp: String, CaseIterable, Identifiable {
    case apple, google, waze, inApp
    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: "Apple Maps"
        case .google: "Google Maps"
        case .waze: "Waze"
        case .inApp: "Rodyti maršrutą čia"
        }
    }

    /// short name for "Tęsti navigaciją {…}"
    var short: String {
        switch self { case .apple: "Apple"; case .google: "Google"; case .waze: "Waze"; case .inApp: "EVFlow" }
    }

    /// app icon in the picker
    var icon: String {
        switch self { case .apple: "nav_apple"; case .google: "nav_google"; case .waze: "nav_waze"; case .inApp: "nav_evflow" }
    }

    /// App Store page when the app isn't installed
    var appStore: URL? {
        switch self {
        case .google: URL(string: "itms-apps://apps.apple.com/app/id585027354")
        case .waze: URL(string: "itms-apps://apps.apple.com/app/id323229106")
        case .apple, .inApp: nil
        }
    }

    /// Deep link (Apple Maps opens through MKMapItem instead).
    func url(to c: CLLocationCoordinate2D) -> URL? {
        switch self {
        case .google: URL(string: "comgooglemaps://?daddr=\(c.latitude),\(c.longitude)&directionsmode=driving")
        case .waze: URL(string: "waze://?ll=\(c.latitude),\(c.longitude)&navigate=yes")
        case .apple, .inApp: nil
        }
    }

    /// scheme to test with canOpenURL (listed in LSApplicationQueriesSchemes)
    var probe: URL? {
        switch self {
        case .google: URL(string: "comgooglemaps://")
        case .waze: URL(string: "waze://")
        case .apple, .inApp: nil
        }
    }
}

/// The "in-app arrival" prompt: within 300 m of the station picked with "Važiuoti", picked at most 3 h ago.
func shouldOfferArrival(target: CLLocationCoordinate2D, pickedAt: Date, user: CLLocation?, now: Date) -> Bool {
    guard let user, now.timeIntervalSince(pickedAt) <= Rewards.arrivalMaxAgeHours * 3600 else { return false }
    return user.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude)) <= Rewards.nearbyMeters
}
