import SwiftUI
import CoreLocation

// MARK: - Route preview (Waze "Leave later / Go now")

struct RoutePreview: View {
    @EnvironmentObject var app: AppState
    let r: Reco
    @State private var avoidHighways = false
    @State private var avoidTolls = false

    var body: some View {
        VStack(spacing: 0) {
            // header: back + "Your location → destination"
            HStack(spacing: 0) {
                Button { withAnimation(.snappy) { app.screen = .station } } label: {
                    Icon("chevron-left", size: 26).frame(width: 44, height: 44)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text("Jūsų vieta")
                    Icon("arrow-right", size: 16, color: W.text2)
                    Text(r.v.s.name).lineLimit(1)
                }
                .font(.system(size: 15)).foregroundStyle(W.text)
                Spacer(minLength: 44)
            }
            .padding(.horizontal, 8).frame(height: 52)
            .background(Color.white.ignoresSafeArea(edges: .top).shadow(color: .black.opacity(0.08), radius: 3, y: 2))

            HStack {
                Menu {
                    Toggle("Greitkelių", isOn: $avoidHighways)
                    Toggle("Mokamų kelių", isOn: $avoidTolls)
                } label: {
                    HStack(spacing: 8) {
                        Text("Vengti").font(.system(size: 17, weight: .semibold))
                        Icon("chevron-down", size: 16, color: W.blueText)
                    }
                    .foregroundStyle(W.blueText)
                    .padding(.horizontal, 18).frame(height: 46)
                    .background(Capsule().fill(.white))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                }
                Spacer()
            }
            .padding(.horizontal, W.margin).padding(.top, 16)

            Spacer()

            // bottom card
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color(hex: 0xc4c7cb)).frame(width: 36, height: 4).frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 18)
                if let rt = app.route {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(rt.minutes) min").font(.system(size: 30, weight: .bold))
                        Spacer()
                        Text(fmtKm(rt.km)).font(.system(size: 16)).foregroundStyle(W.text2)
                    }
                    Text(rt.via.isEmpty ? r.v.s.address : "Per \(rt.via)").font(.system(size: 17, weight: .semibold)).lineLimit(1).padding(.top, 6)
                    Text("Atvyksi \(hhmm(.now.addingTimeInterval(Double(rt.minutes) * 60))) · \(arrivalText(r.v.s, driveMin: rt.minutes, lag: app.lag, now: .now, levels: app.meta?.availabilityLevels))")
                        .font(.system(size: 15)).foregroundStyle(W.text2).padding(.top, 4)
                    // waiting long here and a clearly better station nearby → suggest it
                    if let alt = betterOption(than: r, among: app.recos) {
                        let extra = alt.drive - rt.minutes
                        SuggestRow(text: "\(alt.v.s.name): \(alt.wait == 0 ? "laisva" : "~\(alt.wait) min. laukti"), \(extra >= 0 ? "+" : "−")\(abs(extra)) min. kelio") {
                            app.selectedId = alt.id; app.startRoute()
                        }
                        .padding(.top, 10)
                    }
                } else {
                    HStack(spacing: 10) { ProgressView(); Text("Skaičiuojamas maršrutas…").foregroundStyle(W.text2) }
                        .font(.system(size: 16)).padding(.vertical, 22)
                }
                Divline().padding(.top, 18).padding(.horizontal, -W.margin)
                HStack(spacing: 12) {
                    Button { withAnimation(.snappy) { app.screen = .station } } label: {
                        Text("Ne").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 104).frame(height: 56)
                            .background(Capsule().fill(Color(hex: 0xff6159)))
                    }
                    // same map-app picker as on the station (EVFlow = drive here)
                    Button { app.go(to: r.v) } label: {
                        Text("Važiuojam").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Capsule().fill(W.blue))
                    }
                }
                .padding(.top, 14).padding(.bottom, 4)
            }
            .padding(.horizontal, W.margin)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous).fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: -2).ignoresSafeArea(edges: .bottom)
            )
        }
    }

}

/// Green "go there instead" row: route preview (clearly better station) and station card (wait hard to predict).
struct SuggestRow: View {
    let text: String
    let go: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(text).font(.system(size: 14, weight: .semibold)).lineLimit(2)
            Spacer(minLength: 4)
            Button("Važiuoti ten", action: go)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 12).frame(height: 32).background(Capsule().fill(W.green))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(W.green.opacity(0.1)))
    }
}

// MARK: - Turn-by-turn simulation (drives the route at ~8x speed)

struct ManeuverIcon: View {
    let type: String
    let modifier: String?
    var size: CGFloat = 44
    var color: Color = .white
    var body: some View { Icon(name, size: size, color: color) }
    var name: String {
        if type == "arrive" { return "flag" }
        switch modifier {
        case "uturn": return "rotate-ccw"
        case "right", "sharp right": return "corner-up-right"
        case "left", "sharp left": return "corner-up-left"
        case "slight right": return "arrow-up-right"
        case "slight left": return "arrow-up-left"
        default: return "arrow-up"
        }
    }
}

struct NavigationScreen: View {
    @EnvironmentObject var app: AppState
    let r: Reco
    let route: Route
    @State private var d: Double = 0
    @State private var timer: Timer?

    var body: some View {
        let total = route.total
        let ni = route.stepAt.indices.first(where: { $0 > 0 && route.stepAt[$0] > d + 0.01 }) ?? route.steps.count - 1
        let next = route.steps[ni]
        let then = ni + 1 < route.steps.count ? route.steps[ni + 1] : nil
        let toNext = max(0, route.stepAt[ni] - d)
        let remainKm = max(0, total - d)
        let remainMin = max(1, Int((Double(route.minutes) * remainKm / max(total, 0.01)).rounded()))
        let eta = Date.now.addingTimeInterval(Double(remainMin) * 60)

        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    ManeuverIcon(type: next.type, modifier: next.modifier).frame(width: 52)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(toNext < 1 ? "\(Int((toNext * 100).rounded()) * 10) m" : fmtKm(toNext))
                            .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        Text(next.type == "arrive" ? r.v.s.name : (next.name.isEmpty ? "Tęskite" : next.name))
                            .font(.system(size: 22, weight: .bold)).foregroundStyle(W.navCyan).lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Color.black.ignoresSafeArea(edges: .top))
                if let then {
                    HStack(spacing: 8) {
                        Text("ir tada").font(.system(size: 14, weight: .semibold))
                        ManeuverIcon(type: then.type, modifier: then.modifier, size: 18, color: W.navCyan)
                        Spacer()
                    }
                    .foregroundStyle(W.navCyan).padding(.horizontal, 20).padding(.vertical, 9)
                    .background(Color(hex: 0x1f2124))
                }
            }
            Spacer()
            HStack {
                if let lim = app.speedLimit { Speedometer(speed: d >= total ? 0 : Int(navSpeedKmh), limit: lim) }
                Spacer()
            }.padding(.horizontal, W.margin).padding(.bottom, 12)

            HStack {
                circle("search")
                Spacer()
                VStack(spacing: 1) {
                    Text(eta, format: .dateTime.hour().minute()).font(.system(size: 24, weight: .bold))
                    Text("\(remainMin) min • \(fmtKm(remainKm))").font(.system(size: 14)).foregroundStyle(W.text2)
                }
                Spacer()
                circle("split")
            }
            .padding(.horizontal, W.margin).padding(.top, 12).padding(.bottom, 4)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous).fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: -2).ignoresSafeArea(edges: .bottom)
            )
        }
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate() }
    }

    func circle(_ name: String) -> some View {
        Button { timer?.invalidate(); app.navStart = nil; withAnimation(.snappy) { app.screen = .station } } label: {
            Icon(name, size: 20).frame(width: 44, height: 44).background(Circle().fill(W.field))
        }
    }

    /// The map moves the camera and car at 60 fps from `navStart`; this only refreshes the text (4×/s).
    func start() {
        let total = route.total
        let started = Date.now
        app.navStart = started
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { t in
            Task { @MainActor in
                d = navDistance(route, start: started, at: .now)
                app.user = route.along(d).0
                if d >= total {
                    t.invalidate()
                    try? await Task.sleep(for: .milliseconds(700))
                    app.navStart = nil
                    withAnimation(.snappy) { app.screen = .arrived }
                }
            }
        }
    }
}

struct ArrivedSheet: View {
    @EnvironmentObject var app: AppState
    let r: Reco
    var body: some View {
        BottomSheet {
            let v = r.v
            let free = v.free > 0
            VStack(spacing: 0) {
                Image("ill_arrived").resizable().scaledToFit().frame(height: 140)

                Text("Atvykai?").font(.system(size: 24, weight: .bold)).padding(.top, 18)
                Text(v.s.name).font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(1).padding(.top, 2)
                let freeNames = v.connectors.filter { $0.c.isFree }.map { "\(plugName($0.c.type)) \(Int($0.c.powerKw)) kW" }
                    .reduce(into: [(String, Int)]()) { acc, n in
                        if let i = acc.firstIndex(where: { $0.0 == n }) { acc[i].1 += 1 } else { acc.append((n, 1)) }
                    }
                    .map { $0.1 > 1 ? "\($0.1)× \($0.0)" : $0.0 }
                Text(freeNames.isEmpty ? stationHeadline(v.s, lag: v.lag) : "Laisvos: " + freeNames.prefix(3).joined(separator: " · "))
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(free ? W.greenFg : W.orangeFg).padding(.top, 14)

                HStack(spacing: 12) {
                    Button { app.qrScan = .init(stationId: v.id) } label: {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 20, weight: .semibold)).foregroundStyle(W.text)
                            .frame(width: W.buttonH, height: W.buttonH).background(Circle().fill(W.field))
                    }
                    .accessibilityLabel("Skenuoti QR")
                    Button("Krauti čia") { app.startChargingAnywhere(at: v) }
                        .buttonStyle(PillButtonStyle())
                }
                .padding(.top, 20)
                Button("Vieta užimta? Pranešti") { withAnimation(.snappy) { app.screen = .report } }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(W.text2).padding(.top, 14)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, W.margin).padding(.bottom, 6)
        }
    }
}

/// 24 h "14:32" regardless of the phone's 12/24 h setting (short times read as durations otherwise).
func hhmm(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current
    return f.string(from: d)
}
