import SwiftUI

enum ChargePhase { case charging, charged, late, confirming }

extension ChargingSession {
    func phase(at now: Date) -> ChargePhase {
        manualEndAt != nil ? .confirming : now > deadline ? .late : now >= chargedAt ? .charged : .charging
    }
    /// share of expectedChargeMin already spent (time based – we don't know the car's battery level)
    func progress(at now: Date) -> Double {
        min(1, max(0, now.timeIntervalSince(startedAt) / (Double(max(expectedChargeMin, 1)) * 60)))
    }
}

extension ChargePhase {
    var color: Color {
        switch self { case .charging, .charged: W.green; case .late: W.orange; case .confirming: W.blue }
    }
    var fg: Color {
        switch self { case .charging, .charged: W.greenFg; case .late: W.orangeFg; case .confirming: W.blueText }
    }
}

/// whole minutes from now until `d` (never negative)
private func minutes(until d: Date, from now: Date) -> Int { max(0, Int(ceil(d.timeIntervalSince(now) / 60))) }

/// Progress ring: fills in on appear; while `live`, its glow breathes and the head dot pulses.
struct ChargeRing<Content: View>: View {
    let progress: Double
    let color: Color
    var live = false
    var size: CGFloat = 200
    var line: CGFloat = 14
    var track: Color = W.field
    var glow = true
    @ViewBuilder var content: () -> Content
    @State private var shown = false

    var body: some View {
        let p = shown ? max(0.015, min(1, progress)) : 0
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !live)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let breath = live ? (sin(t * 2.2) + 1) / 2 : 0.4
            ZStack {
                Circle().stroke(track, lineWidth: line)
                Circle().trim(from: 0, to: p)
                    .stroke(p >= 1 ? AnyShapeStyle(color)
                                   : AnyShapeStyle(AngularGradient(colors: [color.opacity(0.45), color], center: .center,
                                                                   startAngle: .degrees(0), endAngle: .degrees(360 * p))),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(glow ? 0.15 + 0.35 * breath : 0), radius: glow ? 4 + 8 * breath : 0)
                if live && p > 0 && p < 1 {
                    Circle().fill(.white).frame(width: line * 0.45, height: line * 0.45)
                        .scaleEffect(0.8 + 0.4 * breath)
                        .offset(y: -size / 2)
                        .rotationEffect(.degrees(360 * p))
                }
                content()
            }
            .frame(width: size, height: size)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { shown = true } }
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
}

/// 180° gauge of spaced ticks, red on the left → green on the right. Lit ticks show progress;
/// they sweep in once on appear, then simply follow progress.
struct TickGauge: View {
    let progress: Double
    var width: CGFloat = 270
    /// one colour for every lit tick instead of the red → green sweep (e.g. orange for an overstay)
    var tint: Color? = nil
    private let ticks = 41, tickW: CGFloat = 5
    private var tickLen: CGFloat { width * 0.08 }
    @State private var appeared = Date.now
    @State private var introDone = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: introDone)) { ctx in
            let t = ctx.date.timeIntervalSince(appeared)
            let intro = introDone ? 1 : 1 - pow(1 - min(1, t / 1.1), 3) // ease-out sweep
            let shown = min(1, max(0, progress)) * intro
            let lit = min(ticks - 1, Int((shown * Double(ticks - 1)).rounded(.down))) // index of the leading tick
            Canvas { c, size in
                let center = CGPoint(x: size.width / 2, y: size.height - tickW / 2)
                let rOut = size.width / 2 - tickW / 2, rIn = rOut - tickLen
                for i in 0..<ticks {
                    let f = Double(i) / Double(ticks - 1)
                    let a = Double.pi + f * Double.pi // left → over the top → right
                    var p = Path()
                    p.move(to: CGPoint(x: center.x + rIn * cos(a), y: center.y + rIn * sin(a)))
                    p.addLine(to: CGPoint(x: center.x + rOut * cos(a), y: center.y + rOut * sin(a)))
                    let on = i <= lit
                    let color = (tint ?? gaugeColor(f)).opacity(on ? 1 : 0.16)
                    c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: tickW, lineCap: .round))
                }
            }
        }
        .frame(width: width, height: width / 2 + tickW)
        .onAppear {
            appeared = .now
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { introDone = true }
        }
    }
}

/// red → amber → green along the gauge
private func gaugeColor(_ f: Double) -> Color {
    let stops: [(Double, (Double, Double, Double))] = [(0, (0.94, 0.27, 0.23)), (0.5, (1.0, 0.69, 0.13)), (1, (0.11, 0.73, 0.33))]
    let i = f < 0.5 ? 0 : 1
    let (f0, a) = stops[i], (f1, b) = stops[i + 1]
    let k = (f - f0) / (f1 - f0)
    return Color(.sRGB, red: a.0 + (b.0 - a.0) * k, green: a.1 + (b.1 - a.1) * k, blue: a.2 + (b.2 - a.2) * k)
}

/// Active "Kraunu čia" session. Only the feed ends it; "Baigiau ir patraukiau" just marks it as waiting.
struct ChargingView: View {
    @EnvironmentObject var app: AppState
    let s: ChargingSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = ctx.date
            let phase = s.phase(at: now)
            let left = max(0, Int(ceil(s.chargedAt.timeIntervalSince(now) / 60)))
            let over = max(1, Int(now.timeIntervalSince(s.deadline) / 60))
            let (big, small) = inside(phase, left: left, over: over)

            VStack {
                Spacer()
                BottomSheet {
                    VStack(spacing: 0) {
                        Text("\(s.stationName) · \(Int(s.connectorKw)) kW")
                            .font(.system(size: 13)).foregroundStyle(W.text2).lineLimit(1).padding(.horizontal, 44)

                        TickGauge(progress: s.progress(at: now))
                            .overlay(alignment: .bottom) {
                                VStack(spacing: 0) {
                                    Text(big).font(.system(size: 44, weight: .bold)).monospacedDigit()
                                        .foregroundStyle(phase == .late ? W.orangeFg : W.text)
                                        .contentTransition(.numericText()).animation(.snappy, value: big)
                                    Text(small).font(.system(size: 14, weight: .medium)).foregroundStyle(phase.fg)
                                }
                            }
                            .padding(.top, 26)

                        Text(line(phase, now: now))
                            .font(.system(size: 15)).foregroundStyle(W.text2).multilineTextAlignment(.center)
                            .padding(.top, 22)
                        if phase == .charging {
                            Text((s.fromHistory ? ChargeTimeSource.history : .feed).label + " · patrauk per \(Rewards.graceMin) min. po to – +\(Rewards.onTimePoints) taškų")
                                .font(.system(size: 12.5)).foregroundStyle(W.text3).multilineTextAlignment(.center).padding(.top, 4)
                        }

                        Button(phase == .confirming ? "Tikrinama…" : "Baigiau ir patraukiau") { app.finishManually() }
                            .buttonStyle(PillButtonStyle())
                            .disabled(phase == .confirming).opacity(phase == .confirming ? 0.5 : 1)
                            .padding(.top, 22)
                        HStack(spacing: 28) {
                            if s.canExtend && phase != .confirming {
                                Button("Dar kraunasi +\(Rewards.extendMin) min.") { app.extendCharging() }
                                    .foregroundStyle(W.blueText)
                            }
                            Button("Atšaukti") { app.cancelCharging() }.foregroundStyle(W.text2)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.top, 14)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) {
                        Button { withAnimation(.snappy) { app.screen = .home } } label: {
                            Icon("chevron-down", size: 18).frame(width: 32, height: 32).background(Circle().fill(W.field))
                        }
                        .offset(y: -8)
                    }
                    .padding(.horizontal, W.margin).padding(.bottom, 6)
                }
            }
        }
    }

    /// big number + caption inside the ring
    func inside(_ p: ChargePhase, left: Int, over: Int) -> (String, String) {
        switch p {
        case .charging: left < 60 ? ("\(left)", "min liko") : ("\(left / 60):\(String(format: "%02d", left % 60))", "val. liko")
        case .charged: ("Įkrauta", "patrauk automobilį")
        case .late: ("+\(over)", "min per ilgai")
        case .confirming: ("Ačiū", "tikriname")
        }
    }

    func line(_ p: ChargePhase, now: Date) -> String {
        switch p {
        case .charging: "Turėtum pasikrauti per ~\(s.expectedChargeMin + Rewards.extendMin * s.extensions) min."
        case .charged: "Patrauk per \(minutes(until: s.deadline, from: now)) min. ir gausi +\(Rewards.onTimePoints) taškų"
        case .late: "Kitas vairuotojas laukia vietos"
        case .confirming: "Laiką patikrinsime pagal Via Lietuva duomenis (~3 min.)"
        }
    }
}

/// Small floating card on the map while a session is active.
struct ChargingChip: View {
    let s: ChargingSession
    let action: () -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let phase = s.phase(at: ctx.date)
            let left = max(0, Int(ceil(s.chargedAt.timeIntervalSince(ctx.date) / 60)))
            Button(action: action) {
                HStack(spacing: 10) {
                    if phase == .confirming {
                        Icon("search", size: 20, color: .white).frame(width: 26, height: 26)
                    } else {
                        ChargeRing(progress: s.progress(at: ctx.date), color: .white, live: phase == .charging, size: 26, line: 4,
                                   track: .white.opacity(0.3), glow: false) { EmptyView() }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(phase == .charging ? "Kraunama" : phase == .charged ? "Įkrauta" : phase == .late ? "Užsistovėjote" : "Tikrinama")
                            .font(.system(size: 14, weight: .semibold))
                        Text(phase == .charging ? "liko \(shortMin(left))" : phase == .confirming ? "per kelias min." : "patrauk per \(minutes(until: s.deadline, from: ctx.date)) min.")
                            .font(.system(size: 12)).opacity(0.85).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                }
                // same build as the profile button: blue tile inset in a white frame
                .padding(.horizontal, 12).frame(height: W.fab - 6)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(W.pfpBlue))
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            }
            .buttonStyle(PressStyle())
            .disabled(phase == .confirming) // nothing to do but wait
        }
    }
}
