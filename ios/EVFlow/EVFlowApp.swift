import SwiftUI
import UserNotifications

@main
struct EVFlowApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() { UNUserNotificationCenter.current().delegate = NotificationBanner.shared }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).preferredColorScheme(.light)
                .modelContainer(app.container)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                app.checkArrival()
                Task { await app.feed.refresh() }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var homeExpanded = false
    @State private var homeMini = false

    var mapMode: MapMode { app.screen == .nav ? .nav : app.screen == .route ? .route : .browse }

    var body: some View {
        ZStack {
            WazeMap(views: app.mapViews, user: app.user, selectedId: app.selectedId,
                    navRoute: app.screen == .nav ? app.route : nil, navStart: app.navStart,
                    route: (app.screen == .route || app.screen == .nav) ? app.route?.coords : nil,
                    alternatives: app.screen == .route ? app.alternatives.map(\.coords) : [],
                    labels: app.screen == .route ? app.routeLabels : [],
                    mode: mapMode, recenterTick: app.recenterTick, bottomInset: 341,
                    onSelect: { id in app.pick(id) })
                .ignoresSafeArea()

            if app.meta == nil {
                ProgressView("Kraunami Via Lietuva duomenys…").font(.system(size: 14)).padding().background(RoundedRectangle(cornerRadius: 14).fill(.white))
            }

            if app.screen == .home || app.screen == .station || app.screen == .connector { mapChrome }

            if app.screen == .home {
                // the home sheet + its floating buttons slide away together
                ZStack {
                    // Waze dims the map behind the expanded sheet; tap to collapse
                    Color.black.opacity(homeExpanded ? 0.3 : 0).ignoresSafeArea()
                        .allowsHitTesting(homeExpanded)
                        .onTapGesture { withAnimation(.snappy) { homeExpanded = false } }
                    if !homeExpanded { floatingRow }
                    HomeSheet(expanded: $homeExpanded, mini: $homeMini)
                }
                .transition(.sheetSwap)
            }
            // one sheet at a time: the old one slides down, then the new one slides up (no morphing)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                switch app.screen {
                case .station: if let r = app.selected { StationSheet(r: r) }
                case .connector: if let r = app.selected, let cv = app.selectedConnector { ConnectorSheet(v: r.v, cv: cv) }
                case .arrived: if let r = app.selected { ArrivedSheet(r: r) }
                case .report: ReportView(r: app.selected ?? app.recos.first)
                default: EmptyView()
                }
            }
            .id(app.screen)
            .transition(.sheetSwap)

            switch app.screen {
            case .route: if let r = app.selected { RoutePreview(r: r) }
            case .nav: if let r = app.selected, let rt = app.route { NavigationScreen(r: r, route: rt) }
            case .charging: if let s = app.activeSession { ChargingView(s: s) }
            case .menu: MenuScreen()
            case .profile: ProfileScreen()
            case .settings: SettingsScreen()
            case .howItWorks: HowItWorksScreen()
            default: EmptyView()
            }

            // "Planavimas": full-screen trip planner slides up over everything
            if app.planner {
                TripPlannerScreen()
                    .transition(.move(edge: .bottom))
                    .zIndex(4)
            }

            // "Važiuojam": which map app – dim fades, sheet slides (separate transitions)
            if app.navDialog {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { app.closeNavPicker() }
                    .transition(.opacity)
                    .zIndex(5)
            }
            if app.navDialog, let v = app.selected?.v {
                VStack { Spacer(); NavPickerSheet(v: v) }
                    .transition(.move(edge: .bottom))
                    .zIndex(6)
            }

            if let c = app.celebration { CelebrationView(c: c) { withAnimation { app.celebration = nil } } }
        }
        // no blanket animation on screen changes: sheets use their own slide transitions,
        // otherwise their contents (icons, rows) animate in separately and look like they float
        .animation(.snappy, value: homeExpanded)
        .animation(.snappy, value: homeMini)
        .fullScreenCover(item: $app.qrScan) { t in
            QRScannerScreen(onCode: { app.handleQR($0, stationId: t.stationId) }, onClose: { app.qrScan = nil })
        }
        .onAppear {
            KeyboardDismisser.shared.install()
            if UserDefaults.standard.string(forKey: "demoScreen") == "search" { homeExpanded = true }
        }
    }

    var mapChrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    // profile picture opens the menu (replaces the hamburger)
                    Button { withAnimation(.snappy) { app.screen = .menu } } label: {
                        ProfilePic(size: W.fab - 6, corner: 11)
                            .padding(3)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    }.buttonStyle(PressStyle())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    if let s = app.activeSession, app.screen == .home {
                        ChargingChip(s: s) { withAnimation(.snappy) { app.screen = .charging } }
                    }
                    DataAgeNote()
                }
            }
            .padding(.horizontal, W.margin).padding(.top, 8)
            Spacer()
        }
    }

    /// speedometer + report button that sit just above the collapsed home sheet
    var floatingRow: some View {
        VStack {
            Spacer()
                HStack(alignment: .bottom) {
                    if let lim = app.speedLimit { Speedometer(limit: lim) }
                    Spacer()
                    Button { withAnimation(.snappy) { app.screen = .report } } label: {
                        Image("k_report").resizable().scaledToFit().frame(width: 44, height: 44)
                            .frame(width: W.report, height: W.report)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: 0xffcc28)))
                            .shadow(color: Color(hex: 0xe0a800).opacity(0.35), radius: 6, y: 3)
                    }.buttonStyle(PressStyle())
                }
                .padding(.horizontal, W.margin)
                .padding(.bottom, (homeMini ? HomeSheet.miniHeight : HomeSheet.collapsedHeight) + 14)
        }
        .ignoresSafeArea(.keyboard)
    }
}

/// Waze speedometer bubble with the posted speed limit sign (only shown when the limit is known)
struct Speedometer: View {
    var speed = 0
    let limit: Int
    var body: some View {
        VStack(spacing: -3) {
            Text("\(speed)").font(.system(size: 34, weight: .bold))
            Text("km/h").font(.system(size: 11, weight: .medium)).opacity(0.85)
        }
        .foregroundStyle(speed > limit ? Color(hex: 0xff5a4f) : .white)
        .frame(width: 69, height: 69)
        .background(Circle().fill(Color(hex: 0x2b2e33)))
        .overlay(Circle().stroke(Color(hex: 0x17191c), lineWidth: 2.5))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .overlay(alignment: .topTrailing) { SpeedLimitSign(limit: limit).offset(x: 22, y: -2) }
        .padding(.trailing, 22)
    }
}

/// European speed limit sign: red ring, white disc, black number
struct SpeedLimitSign: View {
    let limit: Int
    var body: some View {
        Text("\(limit)").font(.system(size: limit >= 100 ? 14 : 17, weight: .bold)).foregroundStyle(Color(hex: 0x202124))
            .frame(width: 38, height: 38)
            .background(Circle().fill(.white))
            .overlay(Circle().inset(by: 2.5).stroke(Color(hex: 0xe8433a), lineWidth: 4.5))
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }
}

/// Waze compass needle: light half up, red half down, slightly tilted
struct CompassGlyph: View {
    var body: some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            var top = Path(); top.move(to: .init(x: c.x, y: c.y - 13)); top.addLine(to: .init(x: c.x + 6, y: c.y)); top.addLine(to: .init(x: c.x - 6, y: c.y)); top.closeSubpath()
            var bottom = Path(); bottom.move(to: .init(x: c.x, y: c.y + 13)); bottom.addLine(to: .init(x: c.x + 6, y: c.y)); bottom.addLine(to: .init(x: c.x - 6, y: c.y)); bottom.closeSubpath()
            ctx.fill(top, with: .color(Color(hex: 0xf4f4f4)))
            ctx.stroke(top, with: .color(Color(hex: 0xc9cbce)), lineWidth: 1)
            ctx.fill(bottom, with: .color(Color(hex: 0xe0262d)))
        }
        .frame(width: 30, height: 30)
        .rotationEffect(.degrees(25))
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.move(to: .init(x: r.midX, y: r.minY)); p.addLine(to: .init(x: r.maxX, y: r.maxY)); p.addLine(to: .init(x: r.minX, y: r.maxY)); p.closeSubpath() }
    }
}

struct CelebrationView: View {
    let c: Celebration
    let dismiss: () -> Void
    @State private var shown = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: dismiss)
            VStack(spacing: 6) {
                Mascot(size: 84, mood: c.mood)
                if c.pts != 0 { Text(c.pts > 0 ? "+\(c.pts)" : "\(c.pts)").font(.system(size: 32, weight: .heavy)).foregroundStyle(W.purple) }
                Text(c.title).font(.system(size: 19, weight: .bold)).multilineTextAlignment(.center)
                Text(c.text).font(.system(size: 14.5)).foregroundStyle(W.text2).multilineTextAlignment(.center)
                Button("Puiku", action: dismiss).buttonStyle(PillButtonStyle()).padding(.top, 12)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
            .padding(.horizontal, 40)
            .scaleEffect(shown ? 1 : 0.7).opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = true } }
        }
    }
}

/// "Duomenys prieš X min." when the last refresh failed or the feed is getting old.
struct DataAgeNote: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            if let m = app.meta {
                let age = feedLag(dataUntil: m.dataUntilUtc, now: ctx.date)
                if app.feed.failed || age >= 10 {
                    Text("Duomenys prieš \(age) min.")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(W.text2)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Capsule().fill(.white)).shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                }
            }
        }
    }
}
