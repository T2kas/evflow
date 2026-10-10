import SwiftUI

/// "Važiuojam" → pick the map app (with its icon) or our own route screen.
struct NavPickerSheet: View {
    @EnvironmentObject var app: AppState
    let v: StationView

    var body: some View {
        let installed = app.installedNavApps
        BottomSheet {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kuo važiuosi?").font(.system(size: 20, weight: .bold))
                        Text(v.s.name).font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(1)
                    }
                    Spacer()
                    CloseButton { app.closeNavPicker() }
                }
                .padding(.bottom, 8)

                ForEach([NavApp.google, .apple, .waze, .inApp]) { a in
                    Button { app.open(a, to: v) } label: {
                        HStack(spacing: 14) {
                            Image(a.icon).resizable().scaledToFit().frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(W.line, lineWidth: 1))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a == .inApp ? "EVFlow" : a.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(W.text)
                                if let sub = subtitle(a, installed: installed.contains(a)) {
                                    Text(sub).font(.system(size: 13)).foregroundStyle(W.text2)
                                }
                            }
                            Spacer()
                            Icon("chevron-left", size: 16, color: W.text3).rotationEffect(.degrees(180))
                        }
                        .padding(.vertical, 10).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if a != .inApp { Divline().padding(.leading, 60) }
                }
            }
            .padding(.horizontal, W.margin).padding(.bottom, 6)
        }
    }

    func subtitle(_ a: NavApp, installed: Bool) -> String? {
        if a == .inApp { return "Rodyti maršrutą čia" }
        if !installed { return "Neįdiegta · atsisiųsti" }
        return a == app.lastNav ? "Paskutinį kartą naudota" : nil
    }
}
