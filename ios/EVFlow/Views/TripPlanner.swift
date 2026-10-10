import SwiftUI
import MapKit

/// Apple's place autocomplete, biased to Lithuania (only the typed text leaves the phone).
@MainActor
final class PlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(center: .init(latitude: 55.17, longitude: 23.9), span: .init(latitudeDelta: 3.5, longitudeDelta: 6))
    }

    func update(_ q: String) {
        if q.trimmingCharacters(in: .whitespaces).isEmpty { completer.cancel(); results = [] } else { completer.queryFragment = q }
    }

    nonisolated func completerDidUpdateResults(_ c: MKLocalSearchCompleter) {
        let r = Array(c.results.prefix(8))
        Task { @MainActor in self.results = r }
    }
    nonisolated func completer(_ c: MKLocalSearchCompleter, didFailWithError error: Error) {}

    func resolve(_ c: MKLocalSearchCompletion) async -> TripPlace? {
        guard let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: c)).start().mapItems.first else { return nil }
        let coord: CLLocationCoordinate2D
        if #available(iOS 26, *) { coord = item.location.coordinate } else { coord = item.placemark.coordinate }
        return TripPlace(name: c.title, detail: c.subtitle, coordinate: coord)
    }
}

/// State of the "Planuoti kelionę" flow.
@MainActor
final class TripFlow: ObservableObject {
    enum Step: Int, Comparable { case destination, stops, time, plan; static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue } }
    @Published var step: Step = .destination
    /// direction of the last step change (for the slide)
    @Published var forward = true
    @Published var dest: TripPlace?
    @Published var route: Route?
    @Published var index: RouteIndex?
    @Published var stops = 1
    /// minutes after departure, one per stop
    @Published var stopMinutes: [Int] = []
    /// departure: minutes from now
    @Published var departIn = 0
    private var routeTask: Task<Void, Never>?

    var depart: Date { Date.now.addingTimeInterval(Double(departIn) * 60) }

    func go(_ s: Step) {
        forward = s > step
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { step = s }
    }

    func choose(_ p: TripPlace, from user: CLLocationCoordinate2D, views: [StationView], plugType: String?) {
        dest = p; route = nil; index = nil
        go(.stops)
        routeTask?.cancel()
        routeTask = Task {
            guard let r = await fetchRoutes(from: user, to: p.coordinate).first, !Task.isCancelled else { return }
            let idx = await Task.detached(priority: .userInitiated) { RouteIndex(route: r, views: views, plugType: plugType) }.value
            guard !Task.isCancelled else { return }
            route = r; index = idx
            stops = max(1, suggestedStops(totalKm: r.total))
            stopMinutes = defaultStopMinutes(count: stops, driveMin: r.minutes)
        }
    }

    func setStops(_ n: Int) {
        stops = n
        if let r = route { stopMinutes = defaultStopMinutes(count: n, driveMin: r.minutes) }
    }

    var plan: [TripStop] {
        guard let r = route, let idx = index else { return [] }
        return planTrip(route: r, index: idx, stopMinutes: stopMinutes, depart: depart)
    }
}

/// Full-screen trip planner: 1 destination → 2 how many stops → 3 when → the plan.
struct TripPlannerScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var flow = TripFlow()
    @StateObject private var search = PlaceSearch()
    @State private var q = ""
    @State private var resolving: String?
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                switch flow.step {
                case .destination: destinationStep.transition(slide)
                case .stops: stopsStep.transition(slide)
                case .time: timeStep.transition(slide)
                case .plan: planStep.transition(slide)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .background(Color.white.ignoresSafeArea())
        .task { demo() }
    }

    private var slide: AnyTransition {
        .asymmetric(insertion: .move(edge: flow.forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: flow.forward ? .leading : .trailing).combined(with: .opacity))
    }

    // MARK: chrome

    var topBar: some View {
        HStack(spacing: 14) {
            Button {
                if flow.step == .destination { app.closePlanner() } else { typing = false; flow.go(TripFlow.Step(rawValue: flow.step.rawValue - 1)!) }
            } label: {
                Icon(flow.step == .destination ? "x" : "chevron-left", size: 20).frame(width: 40, height: 40).background(Circle().fill(W.field))
            }
            .buttonStyle(PressStyle())
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i <= flow.step.rawValue ? W.blue : W.line).frame(height: 5)
                }
            }
            .animation(.snappy, value: flow.step)
            Text(flow.step == .plan ? "Planas" : "\(flow.step.rawValue + 1) iš 3")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(W.text2).monospacedDigit()
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, W.margin).padding(.top, 6).padding(.bottom, 10)
    }

    func header(_ image: String, _ title: String, _ subtitle: String, height: CGFloat = 170) -> some View {
        VStack(spacing: 0) {
            Image(image).resizable().scaledToFit().frame(height: height).frame(maxWidth: .infinity).padding(.top, 8)
            Text(title).font(.system(size: 27, weight: .bold)).foregroundStyle(W.text).padding(.top, 18)
            Text(subtitle).font(.system(size: 15.5)).foregroundStyle(W.text2).multilineTextAlignment(.center).padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
    }

    func primary(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title) }
            .buttonStyle(PillButtonStyle())
            .disabled(!enabled).opacity(enabled ? 1 : 0.45)
            .padding(.horizontal, W.margin).padding(.top, 10).padding(.bottom, 8)
            .background(Color.white)
    }

    // MARK: 1 – destination

    var destinationStep: some View {
        VStack(spacing: 0) {
            if !typing {
                header("ill_trip_dest", "Kur važiuosi?", "Pasirink kelionės tikslą – parinksime, kur sustoti pasikrauti pakeliui")
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            HStack(spacing: 12) {
                Icon("search", size: 20, color: W.text2)
                TextField("Miestas ar adresas", text: $q)
                    .font(.system(size: 17)).focused($typing).submitLabel(.search)
                    .autocorrectionDisabled()
                    .onChange(of: q) { _, v in search.update(v) }
                if !q.isEmpty { Button { q = "" } label: { Icon("x", size: 18, color: W.text2) } }
            }
            .padding(.horizontal, 17).frame(height: W.searchH)
            .background(Capsule().fill(W.field))
            .padding(.horizontal, W.margin).padding(.top, typing ? 4 : 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if q.isEmpty {
                        Text("Populiarios kryptys").font(.system(size: 13)).foregroundStyle(Color(hex: 0x3c4043)).padding(.top, 20).padding(.bottom, 4)
                        ForEach(tripQuickPlaces) { p in
                            placeRow(icon: "flag", title: p.name, detail: "~\(Int((haversineKm(app.user, p.coordinate) * 1.25).rounded())) km") {
                                pickPlace(p)
                            }
                            Divline()
                        }
                    } else {
                        ForEach(search.results, id: \.self) { c in
                            placeRow(icon: "navigation", title: c.title, detail: c.subtitle, busy: resolving == c.title + c.subtitle) {
                                resolving = c.title + c.subtitle
                                Task {
                                    if let p = await search.resolve(c) { pickPlace(p) }
                                    resolving = nil
                                }
                            }
                            Divline()
                        }
                        if search.results.isEmpty {
                            Text("Ieškoma…").font(.system(size: 15)).foregroundStyle(W.text2).padding(.top, 20)
                        }
                    }
                }
                .padding(.horizontal, W.margin)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .animation(.snappy, value: typing)
    }

    func pickPlace(_ p: TripPlace) {
        typing = false
        flow.choose(p, from: app.user, views: app.views, plugType: app.plugType)
    }

    func placeRow(icon: String, title: String, detail: String, busy: Bool = false, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Icon(icon, size: 19, color: W.blueText).frame(width: 38, height: 38).background(Circle().fill(Color(hex: 0xe8f2ff)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(W.text).lineLimit(1)
                    if !detail.isEmpty { Text(detail).font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(1) }
                }
                Spacer()
                if busy { ProgressView() } else { Icon("arrow-right", size: 18, color: W.text3) }
            }
            .padding(.vertical, 13).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 2 – how many stops

    var stopsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    header("ill_trip_stops", "Kiek sustojimų?", "Kiek kartų planuoji pasikrauti pakeliui")
                    routeCard.padding(.top, 22)
                    HStack(spacing: 10) {
                        ForEach(1...Trip.maxStops, id: \.self) { n in stopCard(n) }
                    }
                    .padding(.top, 16)
                    if let r = flow.route, suggestedStops(totalKm: r.total) == 0 {
                        InsightBox(icon: "lightbulb", tint: W.blueText, bg: Color(hex: 0xeef6ff),
                                   text: Text("Kelionė neilga – dažniausiai užtenka vienos įkrovos. Sustojimą vis tiek gali susiplanuoti."))
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, W.margin).padding(.bottom, 12)
            }
            primary("Toliau", enabled: flow.route != nil) { flow.go(.time) }
        }
    }

    var routeCard: some View {
        HStack(spacing: 14) {
            Icon("flag", size: 20, color: .white).frame(width: 42, height: 42).background(Circle().fill(W.blue))
            VStack(alignment: .leading, spacing: 3) {
                Text("Iki: \(flow.dest?.name ?? "")").font(.system(size: 17, weight: .bold)).foregroundStyle(W.text).lineLimit(1)
                if let r = flow.route {
                    Text("\(Int(r.total.rounded())) km · \(fmtDuration(r.minutes)) kelio").font(.system(size: 14.5)).foregroundStyle(W.text2)
                } else {
                    Text("Skaičiuojamas maršrutas…").font(.system(size: 14.5)).foregroundStyle(W.text2)
                }
            }
            Spacer()
            if flow.route == nil { ProgressView() }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(W.field))
    }

    func stopCard(_ n: Int) -> some View {
        let on = flow.stops == n
        let suggested = flow.route.map { max(1, suggestedStops(totalKm: $0.total)) == n } ?? false
        return Button { withAnimation(.snappy) { flow.setStops(n) } } label: {
            VStack(spacing: 4) {
                Text("\(n)").font(.system(size: 40, weight: .bold)).foregroundStyle(on ? W.blueText : W.text)
                Text(n == 1 ? "sustojimas" : "sustojimai").font(.system(size: 14)).foregroundStyle(W.text2)
            }
            .frame(maxWidth: .infinity).frame(height: 112)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? Color(hex: 0xeef6ff) : .white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(on ? W.blue : W.chipLine, lineWidth: on ? 2 : 1))
            .overlay(alignment: .top) {
                if suggested {
                    Text("Siūlome").font(.system(size: 11.5, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).frame(height: 20).background(Capsule().fill(W.green)).offset(y: -10)
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 3 – when to stop

    var timeStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header("ill_trip_time", "Kada nori sustoti?", "Pasirink apytikslį laiką – ieškosime stotelės, kuri tuo metu dažniausiai laisva", height: 130)
                    Text("Išvykimas").font(.system(size: 13)).foregroundStyle(Color(hex: 0x3c4043)).padding(.top, 22)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(departOptions(), id: \.self) { m in
                                let on = flow.departIn == m
                                Button { withAnimation(.snappy) { flow.departIn = m } } label: {
                                    Text(m == 0 ? "Dabar" : fmtClock(.now.addingTimeInterval(Double(m) * 60)))
                                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(on ? .white : W.text)
                                        .padding(.horizontal, 16).frame(height: 38)
                                        .background(Capsule().fill(on ? W.blue : W.field))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 8)
                    if let r = flow.route {
                        TripTrack(route: r, stopMinutes: flow.stopMinutes).padding(.top, 22)
                        ForEach(flow.plan) { s in stopSlider(s, route: r).padding(.top, 12) }
                    }
                }
                .padding(.horizontal, W.margin).padding(.bottom, 12)
            }
            primary("Sudaryti planą", enabled: flow.route != nil) { flow.go(.plan) }
        }
    }

    /// "Dabar", then the next round half hours (14:30, 15:00, 16:00, 17:00): minutes from now
    func departOptions() -> [Int] {
        let now = Date.now
        let toHalf = 30 - Calendar.current.component(.minute, from: now) % 30
        let first = toHalf < 10 ? toHalf + 30 : toHalf
        return [0, first, first + 30, first + 90, first + 150]
    }

    func stopSlider(_ s: TripStop, route r: Route) -> some View {
        let i = s.index
        let binding = Binding<Double>(
            get: { Double(flow.stopMinutes[safe: i] ?? 0) },
            set: { v in
                guard flow.stopMinutes.indices.contains(i) else { return }
                flow.stopMinutes[i] = clampStop(Int((v / 5).rounded()) * 5, index: i, stops: flow.stopMinutes, driveMin: r.minutes)
            })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(i + 1) sustojimas").font(.system(size: 14, weight: .semibold)).foregroundStyle(W.text2)
                    Text("~\(fmtClock(s.arrival))").font(.system(size: 30, weight: .bold)).foregroundStyle(W.text).monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                Text("po \(fmtDuration(s.minute)) · \(Int(routeKm(atMinute: s.minute, route: r).rounded())) km")
                    .font(.system(size: 14)).foregroundStyle(W.text2).monospacedDigit()
            }
            Slider(value: binding, in: 0...Double(max(1, r.minutes)), step: 5).tint(W.blue)
            if let h = s.hit {
                HStack(spacing: 10) {
                    StationGlyph(color: levelColor(s.level), size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(h.v.s.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(W.text).lineLimit(1)
                        Text(levelLine(s)).font(.system(size: 13)).foregroundStyle(levelFg(s.level)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("Šalia šios vietos stotelių nerasta").font(.system(size: 13.5)).foregroundStyle(W.text2)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(W.chipLine, lineWidth: 1))
        .animation(.snappy, value: s.minute)
    }

    // MARK: plan

    var planStep: some View {
        let plan = flow.plan
        let r = flow.route
        let arrive = r.map { tripArrival(depart: flow.depart, driveMin: $0.minutes, stops: plan.count) }
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header("ill_trip_done", "Planas paruoštas",
                           arrive.map { "Atvyksi į \(flow.dest?.name ?? "") ~\(fmtClock($0)) (su \(plan.count) × ~\(Trip.stopMin) min. krovimo)" } ?? "",
                           height: 140)
                    VStack(alignment: .leading, spacing: 0) {
                        timelineRow(dot: AnyView(Circle().fill(W.text).frame(width: 12, height: 12)),
                                    time: flow.departIn == 0 ? "Dabar" : fmtClock(flow.depart), title: "Išvykimas", detail: "Tavo vieta", line: true)
                        ForEach(plan) { s in
                            Button { if let h = s.hit { app.closePlanner(); app.pick(h.v.id) } } label: {
                                timelineRow(dot: AnyView(Image("k_bolt").resizable().scaledToFit().frame(width: 16, height: 16)
                                                .frame(width: 30, height: 30).background(Circle().fill(Color(hex: 0xeef6ff)))),
                                            time: fmtClock(s.arrival), title: s.hit?.v.s.name ?? "Stotelė nerasta",
                                            detail: s.hit.map { stopDetail($0) } ?? "Pabandyk kitą laiką", badge: s.hit == nil ? nil : levelLine(s),
                                            badgeColor: levelFg(s.level), line: true, chevron: s.hit != nil)
                            }
                            .buttonStyle(.plain)
                        }
                        timelineRow(dot: AnyView(Icon("flag", size: 15, color: .white).frame(width: 30, height: 30).background(Circle().fill(W.blue))),
                                    time: arrive.map { fmtClock($0) } ?? "", title: flow.dest?.name ?? "", detail: r.map { "\(Int($0.total.rounded())) km" } ?? "", line: false)
                    }
                    .padding(.top, 22)
                }
                .padding(.horizontal, W.margin).padding(.bottom, 12)
            }
            HStack(spacing: 10) {
                Button("Keisti") { flow.go(.time) }.buttonStyle(PillButtonStyle(kind: .secondary)).frame(width: 120)
                Button("Važiuojam") {
                    guard let first = plan.first(where: { $0.hit != nil })?.hit else { return }
                    app.closePlanner(); app.selectedId = first.v.id; app.startRoute()
                }
                .buttonStyle(PillButtonStyle())
                .disabled(!plan.contains { $0.hit != nil })
            }
            .padding(.horizontal, W.margin).padding(.top, 10).padding(.bottom, 8)
        }
    }

    func timelineRow(dot: AnyView, time: String, title: String, detail: String, badge: String? = nil, badgeColor: Color = W.text2,
                     line: Bool, chevron: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(time).font(.system(size: 15, weight: .semibold)).foregroundStyle(W.text).monospacedDigit()
                .frame(width: 52, alignment: .leading).padding(.top, 5)
            VStack(spacing: 0) {
                dot.frame(width: 30, height: 30)
                if line { Rectangle().fill(W.chipLine).frame(width: 2).frame(maxHeight: .infinity) }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(W.text).lineLimit(1)
                if !detail.isEmpty { Text(detail).font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(2) }
                if let badge { Text(badge).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(badgeColor) }
            }
            .padding(.top, 4).padding(.bottom, line ? 22 : 0)
            Spacer(minLength: 0)
            if chevron { Icon("arrow-right", size: 16, color: W.text3).padding(.top, 8) }
        }
        .contentShape(Rectangle())
    }

    func stopDetail(_ h: RouteIndex.Hit) -> String {
        let off = h.offKm < 0.5 ? "prie pat kelio" : "\(fmtKm(h.offKm)) nuo kelio"
        return "\(h.v.s.operatorName) · \(Int(h.v.maxKw)) kW · \(off)"
    }

    func levelLine(_ s: TripStop) -> String {
        guard let l = s.level else { return "Mažai istorijos šiai valandai" }
        var t = levelLabel(l, levels: app.meta?.availabilityLevels) + String(format: " %02d:00", vilniusHour(s.arrival))
        if let w = s.wait, w > 0 { t += " · laukimas ~\(w) min." }
        return t
    }

    func levelColor(_ l: AvailLevel?) -> Color {
        switch l { case .green: W.green; case .yellow: Color(hex: 0xe0a800); case .red: W.red; case nil: W.grey }
    }
    func levelFg(_ l: AvailLevel?) -> Color {
        switch l { case .green: W.greenFg; case .yellow: Color(hex: 0xa87b00); case .red: W.redFg; case nil: W.text2 }
    }

    // MARK: demo screenshots (-demoScreen trip / tripStops / tripTime / tripPlan)

    func demo() {
        let d = UserDefaults.standard.string(forKey: "demoScreen") ?? ""
        guard ["tripStops", "tripTime", "tripPlan"].contains(d), flow.dest == nil else { return }
        pickPlace(tripQuickPlaces[0])
        guard d != "tripStops" else { return }
        Task {
            while flow.route == nil { try? await Task.sleep(for: .milliseconds(200)) }
            flow.go(d == "tripTime" ? .time : .plan)
        }
    }
}

/// Start ● ━━ ⚡ ━━ ⚡ ━━ 🏁: the stops on a straight track, proportional to drive time.
struct TripTrack: View {
    let route: Route
    let stopMinutes: [Int]
    var body: some View {
        GeometryReader { g in
            let w = g.size.width - 28
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xcfe6ff)).frame(height: 6).padding(.horizontal, 14)
                Circle().fill(W.text).frame(width: 14, height: 14).offset(x: 7)
                ForEach(Array(stopMinutes.enumerated()), id: \.offset) { _, m in
                    Image("k_bolt").resizable().scaledToFit().frame(width: 14, height: 14)
                        .frame(width: 28, height: 28).background(Circle().fill(.white)).overlay(Circle().stroke(W.blue, lineWidth: 2))
                        .offset(x: w * CGFloat(m) / CGFloat(max(1, route.minutes)))
                }
                Icon("flag", size: 13, color: .white).frame(width: 28, height: 28).background(Circle().fill(W.blue)).offset(x: w)
            }
            .animation(.snappy, value: stopMinutes)
        }
        .frame(height: 30)
    }
}
