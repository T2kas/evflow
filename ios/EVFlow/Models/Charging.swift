import Foundation
import CoreLocation
import SwiftData
import UserNotifications

/// "Kraunu čia": a local charging session. Only the feed ends it (connector turns "Laisva"), then it's scored with `Rewards`.
@Model
final class ChargingSession {
    var connectorId: String
    var stationId: String
    var stationName: String
    var connectorKw: Double
    var startedAt: Date
    /// expectedMinutes(): the feed's value, or the user's own median on this connector class
    var expectedChargeMin: Int
    var connectorClass = ""
    /// true when expectedChargeMin came from the user's own history
    var fromHistory = false
    /// "Dar kraunasi +15 min." taps (max Rewards.maxExtensions)
    var extensions = 0
    /// set once the session is scored
    var endedAt: Date?
    /// "Baigiau ir patraukiau" tap: only marks the session as waiting for the feed
    var manualEndAt: Date?
    /// the feed showed this connector busy after we started – required for points
    var seenBusy = false
    var points = 0
    var reputationDelta = 0
    var lateMin = 0

    init(connectorId: String, stationId: String, stationName: String, connectorKw: Double, startedAt: Date,
         expectedChargeMin: Int, connectorClass: String, fromHistory: Bool) {
        self.connectorId = connectorId
        self.stationId = stationId
        self.stationName = stationName
        self.connectorKw = connectorKw
        self.startedAt = startedAt
        self.expectedChargeMin = expectedChargeMin
        self.connectorClass = connectorClass
        self.fromHistory = fromHistory
    }

    /// terminas: when the car should be charged (incl. extensions)
    var chargedAt: Date { Rewards.deadline(startedAt: startedAt, chargeMin: expectedChargeMin, extensions: extensions) }
    /// last moment for points
    var deadline: Date { chargedAt.addingTimeInterval(Double(Rewards.graceMin) * 60) }
    var canExtend: Bool { extensions < Rewards.maxExtensions }
}

/// A finished, confirmed session – feeds expectedMinutes() ("tavo įprastas laikas").
@Model
final class PastCharge {
    var connectorClass: String
    var durationMin: Int
    var endedAt: Date

    init(connectorClass: String, durationMin: Int, endedAt: Date) {
        self.connectorClass = connectorClass
        self.durationMin = durationMin
        self.endedAt = endedAt
    }
}

/// QR codes we could not match to a connector (debug list, to learn operators' formats).
@Model
final class UnknownQR {
    var text: String
    var stationId: String?
    var scannedAt: Date

    init(text: String, stationId: String?, scannedAt: Date = .now) {
        self.text = text
        self.stationId = stationId
        self.scannedAt = scannedAt
    }
}

/// Local "Pranešti" record for an overstaying car (no backend yet).
@Model
final class LocalReport {
    var stationId: String
    var connectorId: String
    var overstayMin: Int
    var createdAt: Date

    init(stationId: String, connectorId: String, overstayMin: Int, createdAt: Date = .now) {
        self.stationId = stationId
        self.connectorId = connectorId
        self.overstayMin = overstayMin
        self.createdAt = createdAt
    }
}

// MARK: - May I start here?

enum StartCheck: Equatable {
    case allowed
    case allowedWithWarning(String)
    case denied(String)

    var canStart: Bool { if case .denied = self { false } else { true } }
}

/// `userLocation` nil = no location permission → the distance check is skipped.
func canStartCharging(_ c: Connector, lag: Int, userLocation: CLLocation?, station: CLLocationCoordinate2D?) -> StartCheck {
    switch c.status {
    case ConnectorStatus.broken:
        return .denied("Jungtis neveikia")
    case ConnectorStatus.busy:
        let busy = c.busyNow(lag: lag) ?? 0
        if busy > Rewards.justPluggedInMin { return .denied("Ši jungtis užimta jau \(busy) min.") }
    default:
        break
    }
    if let u = userLocation, let s = station,
       u.distance(from: CLLocation(latitude: s.latitude, longitude: s.longitude)) > Rewards.nearbyMeters {
        return .denied("Būk prie stotelės")
    }
    if c.status != ConnectorStatus.free && c.status != ConnectorStatus.busy {
        return .allowedWithWarning("Stotelė nesiunčia būsenos")
    }
    return .allowed
}

// MARK: - What does the feed say about my session?

enum SessionVerdict: Equatable {
    /// still charging as far as the feed knows
    case running
    /// connector became free after we were seen charging: score with this end time
    case ended(Date)
    /// never seen charging and still free well after start: drop it without penalty
    case unconfirmed
    /// "Baigiau" tapped but the connector is still busy long after: ask about the cable, lateness keeps counting
    case stillPlugged
}

func evaluateSession(startedAt: Date, seenBusy: Bool, manualEndAt: Date?, connector c: Connector?, dataUntil: Date, now: Date) -> SessionVerdict {
    guard let c else { return .running }
    if c.isFree {
        if seenBusy {
            let end = c.statusSince ?? dataUntil
            if end > startedAt { return .ended(end) }
        }
        if now.timeIntervalSince(startedAt) > Double(Rewards.confirmWithinMin) * 60 { return .unconfirmed }
        return .running
    }
    if c.isBusy, let m = manualEndAt, dataUntil.timeIntervalSince(m) > Double(Rewards.stuckAfterMin) * 60 {
        return .stillPlugged
    }
    return .running
}

// MARK: - Reminder + "Dar kraunasi +15 min."

enum ChargeReminder {
    static let category = "charge-reminder"
    static let extendAction = "extend"

    static func id(_ s: ChargingSession) -> String { "charge-\(s.connectorId)-\(Int(s.startedAt.timeIntervalSince1970))" }

    static func registerCategory() {
        let extend = UNNotificationAction(identifier: extendAction, title: "Dar kraunasi +\(Rewards.extendMin) min.", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [extend], intentIdentifiers: [], options: []),
        ])
    }

    /// Asks for permission the first time, then (re)schedules the reminder at the session's charged-by time.
    static func schedule(_ s: ChargingSession) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        center.removePendingNotificationRequests(withIdentifiers: [id(s)])
        let content = UNMutableNotificationContent()
        content.title = s.stationName
        content.body = Rewards.reminderText
        content.sound = .default
        if s.canExtend { content.categoryIdentifier = category }
        let fireIn = max(1, s.chargedAt.timeIntervalSinceNow)
        try? await center.add(UNNotificationRequest(identifier: id(s), content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)))
    }

    static func cancel(_ s: ChargingSession) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id(s)])
    }
}

/// Shows the reminder as a banner even while the app is open, and forwards "Dar kraunasi +15 min.".
final class NotificationBanner: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationBanner()
    var onExtend: (() -> Void)?
    /// arrival notification tapped → open that station
    var onOpenStation: ((String) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == ChargeReminder.extendAction { await MainActor.run { onExtend?() }; return }
        if let id = response.notification.request.content.userInfo["stationId"] as? String {
            await MainActor.run { onOpenStation?(id) }
        }
    }
}

// MARK: - Location (only for the 300 m "Kraunu čia" check)

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published private(set) var location: CLLocation?
    var hasAlways: Bool { manager.authorizationStatus == .authorizedAlways }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Ask once; without permission `location` stays nil and the distance check is skipped.
    func start() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in self.location = last }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let ok = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
        Task { @MainActor in
            if ok { self.manager.startUpdatingLocation() } else { self.location = nil }
        }
    }
}

// MARK: - Arrival geofence (only with "Always" location permission)

/// 150 m around the station picked with "Važiuoti"; entering it posts
/// "Atvykai prie {stotelė}. Laisva jungtis: {…}. Paspausk, kad pradėtum." which opens the station.
@MainActor
final class ArrivalWatcher {
    private var monitor: CLMonitor?
    private var task: Task<Void, Never>?

    func watch(stationId: String, center: CLLocationCoordinate2D, body: @escaping (String) -> String?) {
        task?.cancel()
        task = Task {
            let m = await CLMonitor("evflow-arrival")
            for id in await m.identifiers { await m.remove(id) }
            await m.add(CLMonitor.CircularGeographicCondition(center: center, radius: Rewards.arrivalRadiusMeters),
                        identifier: stationId, assuming: .unsatisfied)
            self.monitor = m
            do {
                for try await event in await m.events where event.state == .satisfied {
                    guard let text = body(event.identifier) else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "Atvykai"
                    content.body = text
                    content.sound = .default
                    content.userInfo = ["stationId": event.identifier]
                    try? await UNUserNotificationCenter.current().add(
                        UNNotificationRequest(identifier: "arrival-\(event.identifier)", content: content, trigger: nil))
                    await m.remove(event.identifier)
                }
            } catch {}
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
