import SwiftUI

/// One connector: live status + "Kraunu čia". Centred layout like the charging screen.
struct ConnectorSheet: View {
    @EnvironmentObject var app: AppState
    let v: StationView
    let cv: ConnectorView

    var body: some View {
        let c = cv.c
        BottomSheet {
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                let lag = app.meta.map { feedLag(dataUntil: $0.dataUntilUtc, now: ctx.date) } ?? 0
                let state = c.liveState(lag: lag)
                let (headline, color) = status(state)
                let charging = app.activeSession?.connectorId == c.id
                let check = app.startCheck(c, at: v)
                VStack(spacing: 0) {
                    if let g = gauge(c, state, lag) {
                        // busy / overstay: one number on a gauge instead of sentences
                        TickGauge(progress: g.progress, width: 230, tint: g.tint)
                            .overlay(alignment: .bottom) {
                                VStack(spacing: 0) {
                                    Text(g.value).font(.system(size: 40, weight: .bold)).monospacedDigit()
                                        .foregroundStyle(g.tint == nil ? W.text : W.orangeFg)
                                    Text(g.label).font(.system(size: 14, weight: .medium)).foregroundStyle(g.tint == nil ? W.text2 : W.orangeFg)
                                }
                            }
                            .padding(.top, 8)
                    } else {
                        // free: ready charger; broken / unknown: the same, greyed out
                        Image("ill_charge_ready").resizable().scaledToFit()
                            .frame(height: 150)
                            .saturation(state == .free ? 1 : 0)
                            .opacity(state == .free ? 1 : 0.55)
                    }

                    Text("\(plugName(c.type)) · \(Int(c.powerKw)) kW").font(.system(size: 24, weight: .bold)).padding(.top, 18)
                    Text(v.s.name).font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(1).padding(.top, 2)
                    if state == .free || state == .broken || state == .unknown {
                        Text(headline).font(.system(size: 16, weight: .semibold)).foregroundStyle(color).padding(.top, 14)
                    }

                    Text("~\(tileMin(app.chargeTime(c).minutes)) pasikrauti · \(c.priceText)/kWh · +\(Rewards.onTimePoints) taškų")
                        .font(.system(size: 14)).foregroundStyle(W.text2).padding(.top, 14)

                    let blocked = !charging && !check.canStart
                    Button(charging ? "Peržiūrėti krovimą" : "Krauti čia") {
                        if charging { withAnimation(.snappy) { app.screen = .charging } } else { app.requestStart(c, at: v) }
                    }
                    .buttonStyle(PillButtonStyle(kind: blocked ? .secondary : .primary))
                    .disabled(blocked).opacity(blocked ? 0.6 : 1)
                    .padding(.top, 20)
                    if !charging, case .denied(let why) = check {
                        Text(why).font(.system(size: 13.5)).foregroundStyle(W.text2).padding(.top, 8)
                        // taken: offer the station's free connectors instead
                        if c.isBusy {
                            ForEach(v.connectors.filter { $0.c.isFree && $0.c.restriction == nil }.prefix(3)) { f in
                                HStack {
                                    Text("\(plugName(f.c.type)) · \(Int(f.c.powerKw)) kW").font(.system(size: 15, weight: .semibold))
                                    Text("Laisva").font(.system(size: 13, weight: .semibold)).foregroundStyle(W.greenFg)
                                    Spacer()
                                    Button("Krauti čia") { app.requestStart(f.c, at: v) }
                                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 14).frame(height: 32).background(Capsule().fill(W.blue))
                                }
                                .padding(.top, 10)
                            }
                        }
                    } else if !charging, case .allowedWithWarning(let warn) = check {
                        Text(warn).font(.system(size: 13.5)).foregroundStyle(W.orangeFg).padding(.top, 8)
                    }

                    if state == .overstay {
                        Button("Pranešti apie užsistovėjusį") { withAnimation(.snappy) { app.screen = .report } }
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(W.redFg).padding(.top, 14)
                    }

                    if let r = c.restriction {
                        Text("Jungtis – \(restrictionText(r))").font(.system(size: 12.5)).foregroundStyle(W.text3).padding(.top, 10)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    HStack {
                        Button { withAnimation(.snappy) { app.screen = .station } } label: {
                            Icon("chevron-left", size: 18).frame(width: 32, height: 32).background(Circle().fill(W.field))
                        }
                        Spacer()
                        CloseButton { app.selectedId = nil; withAnimation(.snappy) { app.screen = .home } }
                    }
                    .offset(y: -8)
                }
                .padding(.horizontal, W.margin).padding(.bottom, 6)
            }
            .onAppear { app.location.start() } // for the "Būk prie stotelės" check (skipped without permission)
        }
    }

    /// status line for states without a gauge
    func status(_ state: ChargerState) -> (String, Color) {
        switch state {
        case .free: ("Laisva dabar", W.greenFg)
        case .broken: ("Neveikia", W.text2)
        default: ("Būsena nežinoma", W.text3)
        }
    }

    struct Gauge { let progress: Double; let value: String; let label: String; var tint: Color? = nil }

    /// busy: how far the session is towards freeing up (green = soon); overstay: full orange with the overtime
    func gauge(_ c: Connector, _ state: ChargerState, _ lag: Int) -> Gauge? {
        let gt = c.busyMinIsLowerBound == true ? ">" : ""
        switch state {
        case .overstay:
            return Gauge(progress: 1, value: "+\(gt)\(c.overstayByNow(lag: lag))", label: "min per ilgai", tint: W.orange)
        case .busy:
            let busy = c.busyNow(lag: lag) ?? 0
            if let rem = c.remainingNow(lag: lag) {
                return Gauge(progress: Double(busy) / Double(max(1, busy + max(0, rem))),
                             value: rem <= 0 ? "~0" : freesInShort(remainingNow: rem).replacingOccurrences(of: " min.", with: ""),
                             label: rem > 90 ? "iki atsilaisvins" : "min. iki atsilaisvins")
            }
            return Gauge(progress: min(1, Double(busy) / Double(max(1, c.expectedChargeMin))), value: "\(gt)\(busy)", label: "min. užimta")
        default:
            return nil
        }
    }
}
