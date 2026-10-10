import SwiftUI

struct RecoRow: View {
    let r: Reco
    let onPick: () -> Void
    var body: some View {
        let v = r.v
        Button(action: onPick) {
            HStack(alignment: .top, spacing: 0) {
                StationGlyph(color: W.pin(v.pin)).frame(width: 55, alignment: .leading).padding(.top, -6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(v.s.name).font(.system(size: 18, weight: .bold)).lineLimit(1)
                    Text("\(v.s.operatorName) · \(Int(v.maxKw)) kW · \(v.priceText)")
                        .font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(1)
                    (status + Text(" · \(r.explanation)").foregroundColor(W.text2)).font(.system(size: 14)).lineLimit(2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(r.score) min").font(.system(size: 15, weight: .semibold))
                    Text("iki krovimo").font(.system(size: 12)).foregroundStyle(W.text2)
                }
            }
            .padding(.vertical, 19)
            .foregroundStyle(W.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var status: Text {
        let v = r.v
        if v.free > 0 { return Text("\(v.free) \(v.free == 1 ? "laisva" : "laisvos")").fontWeight(.semibold).foregroundColor(W.greenFg) }
        if r.wait > 0 { return Text("užimta").fontWeight(.semibold).foregroundColor(W.redFg) }
        return Text("atsilaisvins").fontWeight(.semibold).foregroundColor(W.orangeFg)
    }
}

/// Waze "Home / Work / New" chip
struct FilterChip: View {
    let emoji: String
    let title: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(emoji).resizable().scaledToFit().frame(width: 24, height: 24)
                Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(W.text)
            }
            .padding(.horizontal, 14).frame(height: W.chipH)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(on ? W.blue : W.chipLine, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct HomeSheet: View {
    @EnvironmentObject var app: AppState
    @Binding var expanded: Bool
    /// compact: only the search bar and a peek (~25 %) of the chips
    @Binding var mini: Bool
    @State private var q = ""
    @State private var drag: CGFloat = 0
    @State private var pickingPlug = false
    @FocusState private var focused: Bool

    /// Waze shows search + chips + the start of the list (≈ 300 pt above the home indicator)
    static let collapsedHeight: CGFloat = 307
    /// above the home-indicator area: grabber 30 + search 56 + gap 16 = 102 → the chips peek ~25 % into the safe area below
    static let miniHeight: CGFloat = 90

    var body: some View {
        GeometryReader { geo in
            // geo excludes the bottom safe area, but the sheet extends under the home indicator
            let full = geo.size.height + geo.safeAreaInsets.bottom
            let target = expanded ? full : (mini ? HomeSheet.miniHeight : HomeSheet.collapsedHeight) + geo.safeAreaInsets.bottom
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                sheet
                    .frame(height: max(HomeSheet.miniHeight * 0.8, min(full, target - drag)), alignment: .top)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // collapsing the sheet (drag down / tap on the dimmed map) also closes the keyboard
        .onChange(of: expanded) { _, e in if !e { focused = false } }
    }

    var sheet: some View {
        BottomSheet {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Icon("search", size: 21, color: W.text2)
                    TextField("Kur krausime?", text: $q)
                        .font(.system(size: 17)).focused($focused)
                        .submitLabel(.search)
                        .onSubmit { focused = false }
                        .onChange(of: focused) { _, f in if f { withAnimation(.snappy) { mini = false; expanded = true } } }
                    if expanded {
                        Button { q = ""; focused = false; withAnimation(.snappy) { expanded = false } } label: { Icon("x", size: 20) }
                    } else {
                        Icon("mic", size: 20)
                    }
                }
                .padding(.leading, 17).padding(.trailing, 20).frame(height: W.searchH)
                .background(Capsule().fill(W.field))
                .padding(.horizontal, W.margin)

                if q.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            FilterChip(emoji: "k_plug", title: "Visi", on: app.filter == .all) { app.filter = .all }
                            FilterChip(emoji: "k_bolt", title: "Greitas krovimas", on: false) { go(.fast) }
                            FilterChip(emoji: "k_coin", title: "Pigiausias krovimas", on: false) { go(.cheap) }
                        }
                        .padding(.horizontal, W.margin).padding(.vertical, 1)
                    }
                    .padding(.top, 16)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if q.isEmpty {
                            Text("Rekomenduojama dabar")
                                .font(.system(size: 13)).foregroundStyle(Color(hex: 0x3c4043))
                                .padding(.top, 34).padding(.bottom, 0)
                            ForEach(Array(app.recos.prefix(expanded ? 10 : 3).enumerated()), id: \.element.id) { i, r in
                                RecoRow(r: r) { focused = false; expanded = false; app.pick(r.id) }
                                Divline()
                            }
                            if expanded { moreOptions }
                        } else {
                            let needle = q.lowercased()
                            let found = app.views.filter { "\($0.s.name) \($0.s.address) \($0.s.operator) \($0.s.city)".lowercased().contains(needle) }.prefix(30)
                            ForEach(Array(found)) { v in
                                Button { focused = false; expanded = false; app.pick(v.id) } label: {
                                    HStack(alignment: .top, spacing: 0) {
                                        StationGlyph(color: W.pin(v.pin)).frame(width: 55, alignment: .leading).padding(.top, -6)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(v.s.name).font(.system(size: 18, weight: .bold)).lineLimit(1)
                                            Text("\(v.s.address), \(v.s.city) · \(v.free)/\(v.total) laisvos").font(.system(size: 14)).foregroundStyle(W.text2).lineLimit(2)
                                        }
                                        Spacer()
                                    }.padding(.vertical, 19).foregroundStyle(W.text).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Divline()
                            }
                            if found.isEmpty { Text("Nieko nerasta").font(.system(size: 15)).foregroundStyle(W.text2).padding(.top, 20) }
                        }
                    }
                    .padding(.horizontal, W.margin)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollDisabled(!expanded)
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { g in
                    // when expanded, only a pull-down that starts near the top collapses (the list scrolls otherwise)
                    if !expanded || g.startLocation.y < 200 { drag = g.translation.height }
                }
                .onEnded { g in
                    // three stops: compact ↔ normal ↔ full
                    withAnimation(.snappy) {
                        if g.translation.height < -50 {
                            if mini { mini = false } else { expanded = true }
                        } else if g.translation.height > 50 && (!expanded || g.startLocation.y < 200) {
                            if expanded { expanded = false; focused = false } else { mini = true }
                        }
                        drag = 0
                    }
                }
        )
    }

    func go(_ kind: Filter) {
        focused = false
        withAnimation(.snappy) { expanded = false }
        app.quickRoute(kind)
    }

    /// Waze "More options": icon, bold title, blue action line
    var moreOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Daugiau galimybių")
                .font(.system(size: 13)).foregroundStyle(Color(hex: 0x3c4043))
                .padding(.top, 34).padding(.bottom, 0)
            option(image: "avatar_car", title: "Mano automobilis",
                   action: app.plugType.map { t in "Jungtis: " + (plugChoices.first { $0.type == t }?.label ?? plugName(t)) } ?? "Nurodykite jungtį") { pickingPlug = true }
                .confirmationDialog("Jūsų automobilio jungtis", isPresented: $pickingPlug, titleVisibility: .visible) {
                    ForEach(plugChoices, id: \.label) { ch in Button(ch.label) { app.plugType = ch.type } }
                }
            Divline()
            option(image: "k_bolt", title: "Greičiausias įkrovimas", action: "Vesti į artimiausią laisvą DC") { go(.fast) }
            Divline()
            option(image: "k_coin", title: "Pigiausia elektra dabar", action: "Vesti į pigiausią šalia") { go(.cheap) }
            Divline()
            option(icon: "bell", title: "Priminti pasikrauti", action: "Prijungti kalendorių") {}
            Divline()
            option(icon: "gift", title: "Taškai ir prizai", action: "\(app.game.points) taškų") { expanded = false; app.screen = .profile }
        }
        .padding(.bottom, 30)
    }

    func option(image: String? = nil, icon: String? = nil, title: String, action: String, tap: @escaping () -> Void) -> some View {
        Button { focused = false; withAnimation(.snappy) { tap() } } label: {
            HStack(alignment: .top, spacing: 0) {
                Group {
                    if let image { Image(image).resizable().scaledToFit().frame(width: 26, height: 26) }
                    if let icon { Icon(icon, size: 24) }
                }
                .frame(width: 53, alignment: .leading).padding(.leading, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(W.text)
                    Text(action).font(.system(size: 15)).foregroundStyle(W.blueText)
                }
                Spacer()
            }
            .padding(.vertical, 16).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
