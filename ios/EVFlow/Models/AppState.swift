import Foundation
import CoreLocation
import SwiftUI
import SwiftData

enum Screen: Equatable { case home, station, connector, route, nav, arrived, charging, report, menu, profile, settings, howItWorks }
enum Filter { case fast, all, cheap }

struct GameEvent: Codable, Identifiable {
    enum Kind: String, Codable { case ontime, late, report, redeem }
    var id = UUID()
    let at: Date
    let label: String
    let pts: Int
    let kind: Kind
}

/// Points + reputation (local only, no backend). Rules live in `Rewards`.
struct Game: Codable {
    var points = 340, onTime = 11, late = 1, reports = 2, streak = 4
    /// 0-100
    var reputation = Rewards.startReputation
    var events: [GameEvent] = [
        .init(at: .now.addingTimeInterval(-86400), label: "Laiku atlaisvinote vietą · Ozas", pts: Rewards.onTimePoints, kind: .ontime),
        .init(at: .now.addingTimeInterval(-2 * 86400), label: "Patvirtintas pranešimas · Akropolis", pts: Rewards.reportConfirmedPoints, kind: .report),
        .init(at: .now.addingTimeInterval(-4 * 86400), label: "Vėlavote 18 min · Panorama", pts: 0, kind: .late),
    ]

    var level: String {
        reputation >= 95 ? "Pavyzdinis vairuotojas" : reputation >= 85 ? "Patikimas vairuotojas" : reputation >= 70 ? "Stengiasi" : "Dažnai užsistovi"
    }
    var stars: Int { max(1, Int((Double(reputation) / 20).rounded())) }
}

struct Celebration { let title: String; let text: String; let pts: Int; let mood: Mascot.Mood }

// Demo start: VILNIUS TECH, Saulėtekio al. (hackathon venue)
let startLocation = CLLocationCoordinate2D(latitude: 54.7225, longitude: 25.3373)

@MainActor
final class AppState: ObservableObject {
    let feed = FeedStore()
    let container: ModelContainer
    private var ctx: ModelContext { container.mainContext }
    private let eta = ETACache()

    @Published var meta: Meta?
    @Published var stations: [Station] = []
    @Published var views: [StationView] = []
    /// "Rekomenduojama dabar": best first (drive + wait)
    @Published var recos: [Reco] = []
    @Published var activeSession: ChargingSession?
    let location = LocationService()
    private let arrival = ArrivalWatcher()

    /// "Planavimas": full-screen trip planner (destination → stops → when)
    @Published var planner = false
    func openPlanner() { withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { planner = true } }
    func closePlanner() { withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { planner = false } }

    /// "Važiuojam": app picker (Apple / Google / Waze / here)
    @Published var navDialog = false
    /// last pick (shown first) and the optional "always use" choice from the profile
    @Published var lastNav: NavApp = NavApp(rawValue: UserDefaults.standard.string(forKey: "evflow.lastNav") ?? "") ?? .apple {
        didSet { UserDefaults.standard.set(lastNav.rawValue, forKey: "evflow.lastNav") }
    }
    @Published var alwaysNav: NavApp? = NavApp(rawValue: UserDefaults.standard.string(forKey: "evflow.alwaysNav") ?? "") {
        didSet { UserDefaults.standard.set(alwaysNav?.rawValue, forKey: "evflow.alwaysNav") }
    }
    /// QR scanner open for this station (nil = any station)
    @Published var qrScan: QRScanTarget?
    struct QRScanTarget: Identifiable { let stationId: String?; var id: String { stationId ?? "-" } }

    @Published var screen: Screen = .home
    @Published var selectedId: String?
    @Published var selectedConnectorId: String?
    @Published var filter: Filter = .all { didSet { recompute(); refreshRecos() } }
    @Published var freeOnly = false { didSet { recompute(); refreshRecos() } }
    /// "Mano automobilis" plug; nil = any
    @Published var plugType: String? = UserDefaults.standard.string(forKey: "evflow.plugType") {
        didSet { UserDefaults.standard.set(plugType, forKey: "evflow.plugType"); refreshRecos() }
    }
    @Published var user = startLocation { didSet { userMoved() } }
    /// set while the simulated drive runs; the map animates the camera from it
    @Published var navStart: Date?
    @Published var route: Route?
    @Published var alternatives: [Route] = []
    @Published var speedLimit: Int?
    private var limitCheckedAt: CLLocationCoordinate2D?
    private var limitTask: Task<Void, Never>?
    private var recoTask: Task<Void, Never>?
    private var recosFrom: CLLocationCoordinate2D?
    @Published var celebration: Celebration?
    @Published var recenterTick = 0
    @Published var game: Game { didSet { save() } }
    private var demoApplied = false

    init() {
        if let d = UserDefaults.standard.data(forKey: "evflow.game.v2"), let g = try? JSONDecoder().decode(Game.self, from: d) {
            game = g
        } else { game = Game() }
        container = try! ModelContainer(for: ChargingSession.self, LocalReport.self, PastCharge.self, UnknownQR.self)
        activeSession = try? container.mainContext.fetch(
            FetchDescriptor<ChargingSession>(predicate: #Predicate { $0.endedAt == nil }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        ).first
        feed.onUpdate = { [weak self] f in self?.apply(f) }
        ChargeReminder.registerCategory()
        NotificationBanner.shared.onExtend = { [weak self] in self?.extendCharging() }
        NotificationBanner.shared.onOpenStation = { [weak self] id in self?.pick(id) }
        feed.start()
        // lag grows between refreshes: re-derive overstay / waits every minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.recompute()
                if let f = self.feed.feed { self.checkSession(f) } // "unconfirmed" depends on the clock, not only on refreshes
            }
        }
    }

    private func save() { if let d = try? JSONEncoder().encode(game) { UserDefaults.standard.set(d, forKey: "evflow.game.v2") } }
    func resetGame() { game = Game() }

    /// Minutes since the feed snapshot.
    var lag: Int { meta.map { feedLag(dataUntil: $0.dataUntilUtc, now: .now) } ?? 0 }

    private func apply(_ f: Feed) {
        stations = f.stations
        meta = f.meta
        recompute()
        refreshRecos()
        checkSession(f)
        if !demoApplied { demoApplied = true; refreshSpeedLimit(); applyDemoScreen() }
    }

    /// Launch argument `-demoScreen station|overstay|route|nav|charging|report|menu|profile` jumps straight to a screen.
    private func applyDemoScreen() {
        guard let s = UserDefaults.standard.string(forKey: "demoScreen") else { return }
        let near = views.filter { isRecommendable($0.s, plugType: nil) }
            .sorted { haversineKm(user, $0.coordinate) < haversineKm(user, $1.coordinate) }
        if s == "overstay" || s == "connectorOverstay", let v = near.first(where: { $0.overstays > 0 }) {
            pick(v.id)
            if s == "connectorOverstay" { pickConnector(v.connectors.first { $0.state == .overstay }!.id) }
            return
        }
        guard let first = near.first else { return }
        // route demo looks best with a destination a few km away (alternatives appear)
        let far = (s == "route" || s == "nav") ? near.first { $0.free > 0 && $0.dc && (3.5..<7).contains(haversineKm(user, $0.coordinate)) } : nil
        selectedId = (far ?? first).id
        switch s {
        case "station": screen = .station
        case "navPicker": screen = .station; navDialog = true
        case "planner", "tripStops", "tripTime", "tripPlan": selectedId = nil; planner = true
        case "arrived": screen = .arrived
        case "route", "nav": startRoute(); if s == "nav" { Task { try? await Task.sleep(for: .seconds(3)); screen = .nav } }
        case "connector":
            let v = far ?? first
            selectedConnectorId = (v.connectors.first { $0.state == .overstay } ?? v.connectors.first)?.id
            screen = .connector
        case "charging": if let c = (far ?? first).connectors.first(where: { $0.c.isFree })?.c { startCharging(c, at: far ?? first) }
        case "startSheet": if let c = (far ?? first).connectors.first(where: { $0.c.isFree })?.c { requestStart(c, at: far ?? first) }
        case "confirming":
            if let c = (far ?? first).connectors.first(where: { $0.c.isFree })?.c { startCharging(c, at: far ?? first); finishManually() }
        case "report", "camera", "cameraReview", "cameraDone": screen = .report
        case "reportAnim": // demo the home → report sheet swap
            selectedId = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation(.snappy) { self.screen = .report } }
        case "menu": selectedId = nil; screen = .menu
        case "profile": selectedId = nil; screen = .profile
        case "settings": selectedId = nil; screen = .settings
        default: break
        }
    }

    func recompute() {
        let lag = self.lag
        views = stations.compactMap { makeView($0, lag: lag) }
    }

    var mapViews: [StationView] {
        views.filter {
            matchesFilter($0, filter) && (!freeOnly || $0.free > 0)
                && showsOnMap(pin: $0.pin, selected: $0.id == selectedId, showBroken: false) // broken / silent > 24 h: hidden
        }
    }

    func refreshRecos() {
        let pool = mapViews, from = user, plug = plugType
        recosFrom = from
        recoTask?.cancel()
        recoTask = Task {
            let r = sortForFilter(await recommend(pool, from: from, plugType: plug, now: .now, eta: eta), filter: self.filter)
            if !Task.isCancelled { recos = r }
        }
    }

    private func userMoved() {
        if screen == .nav { refreshSpeedLimit(); return }
        if let last = recosFrom, haversineKm(last, user) < 0.3 { return }
        refreshRecos()
    }

    /// ETA bubbles: best route at ~45 % of its length, alternatives at their midpoint
    var routeLabels: [RouteLabel] {
        guard let r = route else { return [] }
        return [RouteLabel(at: r.along(r.total * 0.45).0, minutes: r.minutes, best: true)]
            + alternatives.map { RouteLabel(at: $0.along($0.total * 0.5).0, minutes: $0.minutes, best: false) }
    }

    /// The selected station as a recommendation (real ETA when it is in the list, straight-line estimate otherwise).
    var selected: Reco? {
        guard let id = selectedId, let v = views.first(where: { $0.id == id }) else { return nil }
        if let r = recos.first(where: { $0.id == id }) { return r }
        let km = haversineKm(user, v.coordinate), drive = driveMinutes(km)
        let h = vilniusHour(.now.addingTimeInterval(Double(drive) * 60))
        return Reco(v: v, km: km, drive: drive, wait: arrivalWait(v.s, driveMin: drive, lag: v.lag, arrivalHour: h),
                    busyAtArrival: busyAtArrival(v.s, arrivalHour: h))
    }

    var selectedConnector: ConnectorView? {
        guard let id = selectedConnectorId else { return nil }
        return selected?.v.connectors.first { $0.id == id }
    }

    /// MKDirections drive time to a station (cached).
    func etaMinutes(to v: StationView) async -> Int { await eta.minutes(from: user, to: v) }

    // MARK: actions
    /// one transaction for selection + screen, so the sheet can never miss the change
    func pick(_ id: String) {
        withAnimation(.snappy) { selectedId = id; selectedConnectorId = nil; screen = .station }
    }

    func pickConnector(_ id: String) { selectedConnectorId = id; withAnimation(.snappy) { screen = .connector } }

    func startRoute() {
        guard let r = selected else { return }
        route = nil; alternatives = []
        withAnimation(.snappy) { screen = .route }
        Task {
            let rts = await fetchRoutes(from: user, to: r.v.coordinate)
            self.alternatives = Array(rts.dropFirst())
            self.route = rts.first
        }
    }

    /// Re-query the OSM speed limit when we've moved > 120 m since the last lookup.
    func refreshSpeedLimit() {
        if let last = limitCheckedAt, haversineKm(last, user) < 0.12 { return }
        limitCheckedAt = user
        let at = user
        limitTask?.cancel()
        limitTask = Task {
            let lim = await fetchSpeedLimit(at: at)
            if !Task.isCancelled { self.speedLimit = lim }
        }
    }

    /// "Greitas" / "Pigiausi" chips: pick the best station of that kind nearby and go straight to the route preview.
    func quickRoute(_ kind: Filter) {
        let pool: [StationView]
        switch kind {
        case .fast: pool = views.filter { $0.dc && $0.maxKw >= 50 }
        case .cheap: pool = views.filter { $0.price != nil && haversineKm(user, $0.coordinate) < 5 }
        case .all: return
        }
        Task {
            let rs = await recommend(pool, from: user, plugType: plugType, now: .now, eta: eta)
            let pick: Reco?
            switch kind {
            case .cheap:
                // cheapest among those with no wait on arrival; ties → sooner
                pick = rs.filter { $0.wait == 0 }.min { ($0.v.price!, $0.score) < ($1.v.price!, $1.score) } ?? rs.first
            default:
                pick = rs.first
            }
            guard let p = pick else { return }
            if !recos.contains(where: { $0.id == p.id }) { recos.append(p) }
            selectedId = p.id
            startRoute()
        }
    }

    func add(_ kind: GameEvent.Kind, pts: Int, label: String) {
        var g = game
        g.points = max(0, g.points + pts)
        if kind == .report { g.reports += 1 }
        g.events.insert(.init(at: .now, label: label, pts: pts, kind: kind), at: 0)
        g.events = Array(g.events.prefix(30))
        game = g
    }

    // MARK: charging session ("Kraunu čia")

    func startCheck(_ c: Connector, at v: StationView, skipDistance: Bool = false) -> StartCheck {
        canStartCharging(c, lag: lag, userLocation: skipDistance ? nil : location.location, station: v.coordinate)
    }

    /// The user's finished sessions (for "tavo įprastas laikas").
    var history: [ChargeHistoryItem] {
        ((try? ctx.fetch(FetchDescriptor<PastCharge>())) ?? []).map { .init(connectorClass: $0.connectorClass, durationMin: $0.durationMin) }
    }

    func chargeTime(_ c: Connector) -> (minutes: Int, source: ChargeTimeSource) { expectedMinutes(c, history: history) }

    /// "Krauti čia": starts right away when allowed (no input needed). A scanned QR proves you're there.
    func requestStart(_ c: Connector, at v: StationView, skipDistance: Bool = false) {
        guard startCheck(c, at: v, skipDistance: skipDistance).canStart else { return }
        startCharging(c, at: v)
    }

    func startCharging(_ c: Connector, at v: StationView) {
        if let old = activeSession { ChargeReminder.cancel(old); ctx.delete(old) }
        let t = chargeTime(c)
        let s = ChargingSession(connectorId: c.id, stationId: v.id, stationName: v.s.name, connectorKw: c.powerKw,
                                startedAt: .now, expectedChargeMin: t.minutes, connectorClass: c.class, fromHistory: t.source == .history)
        ctx.insert(s)
        try? ctx.save()
        clearNavTarget()
        activeSession = s
        selectedId = v.id
        selectedConnectorId = c.id
        Task { await ChargeReminder.schedule(s) }
        withAnimation(.snappy) { screen = .charging }
    }

    /// "Krauti čia" from the arrival sheet: best free connector that fits the car.
    func startChargingAnywhere(at v: StationView) {
        let ok = v.connectors.map(\.c).filter { c in c.restriction == nil && (plugType.map { c.plugTypes.contains($0) } ?? true) }
        guard let c = ok.first(where: { startCheck($0, at: v) == .allowed }) ?? ok.first(where: { startCheck($0, at: v).canStart }) else {
            withAnimation(.snappy) { screen = .station }; return
        }
        selectedId = v.id
        requestStart(c, at: v)
    }

    func cancelCharging() {
        if let s = activeSession { ChargeReminder.cancel(s); ctx.delete(s); try? ctx.save() }
        activeSession = nil
        withAnimation(.snappy) { screen = .home }
    }

    /// "Dar kraunasi +15 min.": moves the deadline, no penalty, at most Rewards.maxExtensions times.
    func extendCharging() {
        guard let s = activeSession, s.canExtend, s.manualEndAt == nil else { return }
        objectWillChange.send()
        s.extensions += 1
        try? ctx.save()
        Task { await ChargeReminder.schedule(s) }
    }

    /// "Baigiau ir patraukiau": only marks the session as waiting – the feed decides when it really ended.
    func finishManually() {
        guard let s = activeSession, s.manualEndAt == nil else { return }
        objectWillChange.send()
        s.manualEndAt = .now
        try? ctx.save()
        ChargeReminder.cancel(s)
        // no sheet while we wait: the top-right card shows "Tikrinama"
        withAnimation(.snappy) { screen = .home }
        Task { await feed.refresh() }
    }

    private func checkSession(_ f: Feed) {
        guard let s = activeSession else { return }
        let c = f.stations.first { $0.id == s.stationId }?.connectors.first { $0.id == s.connectorId }
        if c?.isBusy == true && f.meta.dataUntilUtc > s.startedAt { s.seenBusy = true }
        switch evaluateSession(startedAt: s.startedAt, seenBusy: s.seenBusy, manualEndAt: s.manualEndAt,
                               connector: c, dataUntil: f.meta.dataUntilUtc, now: .now) {
        case .ended(let end):
            settle(s, endedAt: end)
        case .unconfirmed:
            // never seen charging: drop it without any penalty
            ChargeReminder.cancel(s)
            ctx.delete(s); try? ctx.save()
            activeSession = nil
            celebration = .init(title: "Nematome, kad krautum", text: "Ar pasirinkai teisingą jungtį?", pts: 0, mood: .sleepy)
            if screen == .charging { withAnimation(.snappy) { screen = .home } }
        case .stillPlugged:
            // back to a normal (late) session; lateness keeps counting
            objectWillChange.send()
            s.manualEndAt = nil
            try? ctx.save()
            celebration = .init(title: "Stotelė rodo, kad vis dar esi prijungtas", text: "Ar ištraukei kabelį?", pts: 0, mood: .sleepy)
        case .running:
            try? ctx.save()
        }
    }

    private func settle(_ s: ChargingSession, endedAt: Date) {
        let o = Rewards.outcome(startedAt: s.startedAt, endedAt: endedAt, chargeMin: s.expectedChargeMin, extensions: s.extensions)
        // confirmed session: remember how long this user really charges on this connector class
        ctx.insert(PastCharge(connectorClass: s.connectorClass, durationMin: max(1, Int(endedAt.timeIntervalSince(s.startedAt) / 60)), endedAt: endedAt))
        s.endedAt = endedAt
        s.points = o.points
        s.reputationDelta = o.reputationDelta
        s.lateMin = o.lateMin
        try? ctx.save()
        ChargeReminder.cancel(s)
        activeSession = nil

        var g = game
        g.points += o.points
        g.reputation = Rewards.clampReputation(g.reputation + o.reputationDelta)
        if o.onTime { g.onTime += 1; g.streak += 1 } else { g.late += 1; g.streak = 0 }
        g.events.insert(.init(at: .now, label: o.onTime ? "Laiku atlaisvinote vietą · \(s.stationName)" : "Vėlavote \(o.lateMin) min · \(s.stationName)",
                              pts: o.points, kind: o.onTime ? .ontime : .late), at: 0)
        g.events = Array(g.events.prefix(30))
        game = g

        celebration = o.onTime
            ? .init(title: "Ačiū, kad atlaisvinote vietą!", text: "Reputacija +\(o.reputationDelta). Kitas vairuotojas jau gali krauti.",
                    pts: o.points, mood: .love)
            : .init(title: "Šįkart pavėlavote", text: "Vieta buvo užimta \(o.lateMin) min per ilgai. Reputacija \(o.reputationDelta). Kitą kartą pavyks!",
                    pts: 0, mood: .sleepy)
        route = nil; alternatives = []
        if screen == .charging { withAnimation(.snappy) { screen = .home } }
    }

    // MARK: navigation hand-off ("Važiuojam")

    var installedNavApps: [NavApp] {
        NavApp.allCases.filter { app in app.probe.map { UIApplication.shared.canOpenURL($0) } ?? true }
    }

    /// "Važiuojam" on a station: remember it as the destination, then ask which app (unless one is set as "always").
    func go(to v: StationView) {
        selectedId = v.id
        if let a = alwaysNav, installedNavApps.contains(a) { open(a, to: v) } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { navDialog = true }
        }
    }

    func closeNavPicker() { withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { navDialog = false } }

    func open(_ app: NavApp, to v: StationView) {
        closeNavPicker()
        if !installedNavApps.contains(app), let store = app.appStore { UIApplication.shared.open(store); return }
        lastNav = app
        setNavTarget(v)
        switch app {
        case .apple: openInAppleMaps(v)
        case .google, .waze: if let u = app.url(to: v.coordinate) { UIApplication.shared.open(u) }
        case .inApp:
            // from our route screen: start driving here; elsewhere: show the route first
            if screen == .route, route != nil { withAnimation(.snappy) { screen = .nav } } else { startRoute() }
        }
    }

    // MARK: arrival

    private func setNavTarget(_ v: StationView) {
        UserDefaults.standard.set(v.id, forKey: "evflow.navTarget")
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "evflow.navTargetAt")
        location.start()
        if location.hasAlways {
            arrival.watch(stationId: v.id, center: v.coordinate) { [weak self] id in
                MainActor.assumeIsolated { self?.arrivalText(stationId: id) }
            }
        }
    }

    private func clearNavTarget() {
        UserDefaults.standard.removeObject(forKey: "evflow.navTarget")
        arrival.stop()
    }

    private func arrivalText(stationId: String) -> String? {
        guard let v = views.first(where: { $0.id == stationId }) else { return nil }
        let free = v.connectors.first { $0.c.isFree }.map { "\(plugName($0.c.type)) \(Int($0.c.powerKw)) kW" } ?? "kol kas nėra"
        return "Atvykai prie \(v.s.name). Laisva jungtis: \(free). Paspausk, kad pradėtum."
    }

    /// App came to the foreground: near the "Važiuojam" station (≤ 300 m, ≤ 3 h ago)? Offer the arrival sheet.
    func checkArrival() {
        guard activeSession == nil, screen == .home || screen == .station,
              let id = UserDefaults.standard.string(forKey: "evflow.navTarget"),
              let v = views.first(where: { $0.id == id }) else { return }
        let at = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "evflow.navTargetAt"))
        guard shouldOfferArrival(target: v.coordinate, pickedAt: at, user: location.location, now: .now) else { return }
        UserDefaults.standard.removeObject(forKey: "evflow.navTarget") // offer once
        selectedId = id
        withAnimation(.snappy) { screen = .arrived }
    }

    // MARK: QR

    /// Scanned text → connector (this station first, then all) → start; unknown codes are kept for debugging.
    func handleQR(_ text: String, stationId: String?) {
        qrScan = nil
        let here = views.first { $0.id == stationId }
        let all = views.flatMap { $0.connectors.map(\.c) }
        if let c = matchConnector(qr: text, station: here?.connectors.map(\.c) ?? [], all: all),
           let v = here.flatMap({ h in h.connectors.contains { $0.id == c.id } ? h : nil }) ?? views.first(where: { $0.connectors.contains { $0.id == c.id } }) {
            selectedId = v.id
            selectedConnectorId = c.id
            if startCheck(c, at: v, skipDistance: true).canStart {
                requestStart(c, at: v, skipDistance: true) // the QR proves you're at the station
            } else {
                withAnimation(.snappy) { screen = .connector }
            }
            return
        }
        ctx.insert(UnknownQR(text: text, stationId: stationId))
        try? ctx.save()
        celebration = .init(title: "Nepavyko atpažinti jungties", text: "Pasirink ją sąraše.", pts: 0, mood: .sleepy)
    }

    var unknownQRs: [UnknownQR] {
        (try? ctx.fetch(FetchDescriptor<UnknownQR>(sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]))) ?? []
    }

}

