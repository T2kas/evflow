import SwiftUI
import Charts

/// Waze-style place card for a charging station.
struct StationSheet: View {
    @EnvironmentObject var app: AppState
    let r: Reco
    @State private var contentH: CGFloat = 300
    /// MKDirections drive time for "Ar bus laisva, kai atvažiuosiu"
    @State private var drive: Int?

    var body: some View {
        let v = r.v
        BottomSheet {
            VStack(spacing: 0) {
                ScrollView {
                    // feed numbers are valid at dataUntilUtc: re-derive them every minute
                    TimelineView(.periodic(from: .now, by: 60)) { ctx in
                        details(v, lag: app.meta.map { feedLag(dataUntil: $0.dataUntilUtc, now: ctx.date) } ?? 0, now: ctx.date)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentH = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(max(contentH, 120), 480))

                // reporting lives on the yellow button on the map
                HStack(spacing: 12) {
                    Button { app.qrScan = .init(stationId: v.id) } label: {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 22, weight: .semibold)).foregroundStyle(W.text)
                            .frame(width: 56, height: 56).background(Circle().fill(W.field))
                    }
                    .accessibilityLabel("Skenuoti QR")
                    // route first ("Važiuojam / Ne"); the map-app picker lives there, so you only pick once
                    Button { app.startRoute() } label: {
                        Text("Važiuojam").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 56).background(Capsule().fill(W.blue))
                    }
                }
                .padding(.horizontal, W.margin).padding(.top, 14).padding(.bottom, 4)
            }
        }
        .task(id: v.id) { drive = await app.etaMinutes(to: v) }
    }

    func details(_ v: StationView, lag: Int, now: Date) -> some View {
        let s = v.s
        let drive = self.drive ?? r.drive
        let wait = arrivalWait(s, driveMin: drive, lag: lag, arrivalHour: vilniusHour(now.addingTimeInterval(Double(drive) * 60)))
        let level = reliabilityLevel(s.reliability)
        // one quiet line, only when there is something worth saying
        let hint = [level == .reliable ? nil : reliabilityText(level)].compactMap { $0 }
        // history at the arrival hour – text only, no coloured dot (map colours mean "now")
        let usual = availabilityText(s, arrival: now.addingTimeInterval(Double(drive) * 60), now: now, levels: app.meta?.availabilityLevels)
        // 9 iš 10 kartų laukimas baigiasi per waitHi; over 3 h it says little → "Sunku nuspėti" + a free station nearby
        let hardWait = wait > 0 && hardToPredict(s.waitLikelyByMin)
        let waitHi = hardWait ? nil : likelyByNow(s.waitLikelyByMin, lag: lag).flatMap { $0 > wait + 2 ? $0 : nil }
        return VStack(alignment: .leading, spacing: 0) {
            // header
            HStack(alignment: .center, spacing: 12) {
                StationGlyph(color: W.pin(v.pin), size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.name).font(.system(size: 20, weight: .bold)).lineLimit(2)
                    Text("\(s.operatorName) · \(fmtKm(r.km))").font(.system(size: 15)).foregroundStyle(W.text2).lineLimit(1)
                }
                Spacer(minLength: 0)
                CloseButton { app.selectedId = nil; withAnimation(.snappy) { app.screen = .home } }
            }

            // three key numbers
            StatStrip(items: [
                .init(value: "\(v.free)/\(v.total)", label: "laisvos", color: v.free > 0 ? W.greenFg : W.redFg),
                wait == 0 ? .init(value: "\(drive) min", label: "kelio")
                    : hardWait ? .init(value: "?", label: "laukti", color: W.orangeFg)
                    : .init(value: "~\(tileMin(wait))", label: waitHi.map { "laukti · iki \(tileMin($0))" } ?? "laukti", color: W.orangeFg),
                .init(value: v.price.map { String(format: "%.2f €", $0).replacingOccurrences(of: ".", with: ",") } ?? "—", label: "už kWh"),
            ])
            .padding(.top, 16)

            if hardWait, let raw = s.waitLikelyByMin {
                Text(hardToPredictText(likelyBy: raw, lag: lag))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(W.orangeFg)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 12)
                if let alt = nearestFreeOption(than: r, among: app.recos) {
                    SuggestRow(text: "\(alt.v.s.name): laisva, \(alt.drive) min. kelio") { app.selectedId = alt.id; app.startRoute() }
                        .padding(.top, 8)
                }
            }

            if let usual {
                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Icon("clock", size: 15, color: W.text2)
                        Text(usual).font(.system(size: 14, weight: .semibold)).foregroundStyle(W.text)
                    }
                    if let share = freeShareText(s, historyDays: app.meta?.historyDays) {
                        Text(share).font(.system(size: 12.5)).foregroundStyle(W.text3)
                    }
                }
                .frame(maxWidth: .infinity).padding(.top, 12)
            }

            if !hint.isEmpty {
                Text(hint.joined(separator: " · "))
                    .font(.system(size: 13.5)).foregroundStyle(level == .reliable ? W.text2 : W.orangeFg)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity).padding(.top, 10)
            }

            // connectors (tap for details, prediction explanation and "Kraunu čia")
            VStack(spacing: 0) {
                ForEach(Array(s.connectors.enumerated()), id: \.element.id) { i, c in
                    Button { app.pickConnector(c.id) } label: {
                        CompactConnectorRow(c: c, lag: lag).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if i < s.connectors.count - 1 { Divline().padding(.leading, 42) }
                }
            }
            .padding(.top, 6)

            if let busy = s.history.busyByHour, busy.contains(where: { $0 != nil }) {
                Text("Populiarūs laikai").font(.system(size: 13)).foregroundStyle(W.text2).padding(.top, 14)
                PopularTimes(busy: busy, hour: vilniusHour(now)).padding(.top, 6)
            }

            if v.stale {
                note("clock", W.text2, "Operatorius duomenų nesiuntė \(fmtMin(Double(s.reliability.dataAgeMin ?? 0))) – būsena gali būti netiksli.")
            }
        }
        .padding(.horizontal, W.margin)
    }

    func note(_ icon: String, _ tint: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon(icon, size: 16, color: tint).padding(.top, 1)
            Text(text).font(.system(size: 13.5)).foregroundStyle(W.text2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }
}

/// One line per connector on the station card; the full story (explain, overstay report, "Kraunu čia") is one tap away.
struct CompactConnectorRow: View {
    let c: Connector
    let lag: Int

    var body: some View {
        HStack(spacing: 12) {
            StationGlyph(color: W.charger(state), size: 30)
            Text("\(Int(c.powerKw)) kW · \(plugName(c.type))").font(.system(size: 16, weight: .semibold))
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(title.0).font(.system(size: 14, weight: .semibold)).foregroundStyle(title.1)
                if let sub { Text(sub).font(.system(size: 12.5)).foregroundStyle(W.text2) }
            }
        }
        .padding(.vertical, 11)
    }

    var state: ChargerState { c.liveState(lag: lag) }

    var title: (String, Color) {
        switch state {
        case .free: ("Laisva", W.greenFg)
        case .overstay: ("Užsistovėjęs", W.redFg)
        case .busy: ("Užimta", c.prediction.map { W.likelihood(likelihood(pFree30: $0.pFree30min)) } ?? W.redFg)
        case .broken: ("Neveikia", W.text2)
        case .unknown: ("Nežinoma", W.text3)
        }
    }

    var sub: String? {
        let gt = c.busyMinIsLowerBound == true ? ">" : ""
        switch state {
        case .overstay: return "+\(gt)\(c.overstayByNow(lag: lag)) min per ilgai"
        case .busy:
            if let raw = c.prediction?.likelyByMin, hardToPredict(raw) { return hardToPredictText(likelyBy: raw, lag: lag) }
            if let rem = c.remainingNow(lag: lag) {
                return "atsilaisvins \(freesInShortLikely(remainingNow: rem, likelyBy: c.prediction?.likelyByMin, lag: lag))"
            }
            return c.busyNow(lag: lag).map { "\(gt)\($0) min" }
        default: return nil
        }
    }
}

func restrictionText(_ r: String) -> String {
    switch r { case "CUSTOMERS": "tik klientams"; case "DISABLED": "neįgaliesiems"; default: r.lowercased() }
}

/// 24 bars from history.busyByHour (Vilnius hours), current hour highlighted.
struct PopularTimes: View {
    let busy: [Double?]
    let hour: Int
    var body: some View {
        Chart(0..<24, id: \.self) { h in
            BarMark(x: .value("Valanda", h), y: .value("Užimtumas", busy[safe: h].flatMap { $0 } ?? 0))
                .foregroundStyle(h == hour ? W.blue : W.blue.opacity(0.28))
                .cornerRadius(2)
        }
        .chartXScale(domain: -0.5...23.5)
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { v in
                AxisValueLabel { Text("\(v.as(Int.self) ?? 0):00").font(.system(size: 10)).foregroundStyle(W.text3) }
            }
        }
        .frame(height: 64)
    }
}

/// Narrow stat tiles: "51 min", "3,5 val."
func tileMin(_ m: Int) -> String {
    m < 60 ? "\(m) min" : String(format: "%g", (Double(m) / 30).rounded() / 2).replacingOccurrences(of: ".", with: ",") + " val."
}

/// Compact duration for tiles: "14 min", "2 val. 23 min"
func shortMin(_ m: Int) -> String { m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m / 60) val." : "\(m / 60) val. \(m % 60) min") }
