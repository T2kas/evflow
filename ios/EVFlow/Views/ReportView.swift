import SwiftUI

/// Report menu: pick what's wrong → full-screen camera → review / send / done (inside CameraScreen).
struct ReportView: View {
    @EnvironmentObject var app: AppState
    let r: Reco?

    struct Kind: Identifiable { let id: String; let label: String; let icon: String; let bg: Color }
    static let kinds: [Kind] = [
        .init(id: "overstay", label: "Užsistovėjęs", icon: "k_hourglass", bg: Color(hex: 0xfff1e0)),
        .init(id: "notplugged", label: "Neprijungtas", icon: "k_car_unplugged", bg: Color(hex: 0xffe9e7)),
        .init(id: "ice", label: "Ne elektromobilis", icon: "k_fuel", bg: Color(hex: 0xffe9e7)),
        .init(id: "broken", label: "Neveikia", icon: "k_tools", bg: Color(hex: 0xeef0f2)),
        .init(id: "blocked", label: "Užstatyta", icon: "k_noparking", bg: Color(hex: 0xe8eefc)),
        .init(id: "other", label: "Kita", icon: "k_warning", bg: Color(hex: 0xfff6d6)),
    ]

    /// setting this presents the camera for that report type (item-based, so it can't open empty)
    @State private var kind: Kind?

    var body: some View {
        BottomSheet {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("Pranešti").font(.system(size: 20, weight: .bold))
                    Spacer()
                    CloseButton { close() }
                }
                if let v = r?.v { Text(v.s.name).font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(1).padding(.top, 2) }

                VStack(spacing: 16) {
                    ForEach(Array(stride(from: 0, to: Self.kinds.count, by: 3)), id: \.self) { start in
                        HStack(spacing: 8) {
                            ForEach(Self.kinds[start..<min(start + 3, Self.kinds.count)]) { k in
                                Button { kind = k } label: {
                                    VStack(spacing: 8) {
                                        Circle().fill(k.bg).frame(width: 70, height: 70)
                                            .overlay(Image(k.icon).resizable().scaledToFit().frame(width: 44, height: 44))
                                        Text(k.label).font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.center)
                                            .foregroundStyle(W.text).frame(height: 32, alignment: .top)
                                    }
                                    .frame(maxWidth: .infinity)
                                }.buttonStyle(PressStyle())
                            }
                            if Self.kinds.count - start < 3 {
                                ForEach(0..<(3 - (Self.kinds.count - start)), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                            }
                        }
                    }
                }
                .padding(.top, 18).padding(.bottom, 4)
            }
            .padding(.horizontal, W.margin).padding(.bottom, 6)
        }
        .onAppear {
            if (UserDefaults.standard.string(forKey: "demoScreen") ?? "").hasPrefix("camera") { kind = Self.kinds[0] }
        }
        .fullScreenCover(item: $kind) { k in
            CameraScreen(report: summary(k)) { sent in
                kind = nil
                if let pts = sent {
                    app.add(.report, pts: pts, label: "Pranešimas · \(r?.v.s.name ?? "")")
                    close()
                }
            }
        }
    }

    /// What our real-time data says about this report (shown while sending).
    func summary(_ k: Kind) -> ReportSummary {
        let v = r?.v
        let worst = v?.connectors.filter { $0.state == .overstay }.max { $0.overstayBy < $1.overstayBy }
        let confirms: Bool = {
            guard let v else { return false }
            switch k.id {
            case "overstay": return v.overstays > 0
            case "broken": return v.connectors.contains { $0.state == .broken }
            case "notplugged", "ice", "blocked": return v.free > 0 // shown free but physically taken
            default: return false
            }
        }()
        let dataText: String = {
            guard confirms else { return "Pranešimą patvirtins kiti vairuotojai" }
            switch k.id {
            case "overstay": return "Jungtis užimta \(fmtMin(Double(worst?.busyNow ?? 0))), nors pasikrauti reikia ~\(worst?.c.expectedChargeMin ?? 0) min"
            case "broken": return "Operatorius jungtį irgi rodo kaip neveikiančią"
            default: return "Sistema vietą rodo kaip laisvą, nors ji fiziškai užimta"
            }
        }()
        return ReportSummary(kind: k.label, icon: k.icon, station: v?.s.name ?? "Stotelė", op: v?.s.operatorName ?? "Operatorius",
                             confirms: confirms, dataText: dataText, points: confirms ? Rewards.reportConfirmedPoints : Rewards.reportPoints)
    }

    func close() { withAnimation(.snappy) { app.screen = app.selectedId != nil ? .station : .home } }
}

struct ReportSummary {
    let kind: String
    let icon: String
    let station: String
    let op: String
    let confirms: Bool
    let dataText: String
    let points: Int
}
