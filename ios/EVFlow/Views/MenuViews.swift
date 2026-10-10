import SwiftUI

/// Waze side menu: close button top-right, mascot + greeting, plain list rows.
struct MenuScreen: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Spacer()
                    Button { withAnimation(.snappy) { app.screen = .home } } label: {
                        Icon("x", size: 22).frame(width: 44, height: 44)
                            .background(Circle().fill(.white)).shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                    }
                }
                HStack(spacing: 14) {
                    ProfilePic(size: 66, corner: 16)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Labas, vairuotojau!").font(.system(size: 22, weight: .bold))
                        Button { withAnimation(.snappy) { app.screen = .profile } } label: {
                            Text("Peržiūrėti profilį").font(.system(size: 15, weight: .semibold)).foregroundStyle(W.blueText)
                                .padding(.horizontal, 14).frame(height: 34).background(Capsule().fill(W.field))
                        }
                    }
                }
                .padding(.top, 6).padding(.bottom, 20)
                Divline()

                VStack(spacing: 0) {
                    item(.charge, "Mano krovimai") { app.screen = .profile }
                    item(.gift, "Taškai ir prizai", badge: "\(app.game.points)") { app.screen = .profile }
                    item(.message, "Pranešimai", dot: true) {}
                    item(.sliders, "Nustatymai") { app.screen = .settings }
                    item(.help, "Pagalba ir atsiliepimai") {}
                    item(.reset, "Atstatyti demo", muted: true) { app.resetGame(); app.screen = .home }
                }.padding(.top, 6)

                if let m = app.meta {
                    VStack(spacing: 4) {
                        Text("EVFlow v0.1 · Via Lietuva duomenys \(m.dataUntilUtc.formatted(date: .numeric, time: .shortened))")
                        Text("Žemėlapis © OpenStreetMap bendruomenė, OpenFreeMap, MapLibre")
                    }
                    .font(.system(size: 12)).foregroundStyle(W.text3).frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding(.horizontal, W.margin)
        }
        .background(Color.white.ignoresSafeArea())
        .transition(.move(edge: .leading))
    }

    func item(_ glyph: Glyph, _ title: String, badge: String? = nil, dot: Bool = false, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            HStack(spacing: 16) {
                GlyphView(glyph, size: 24, color: muted ? W.text3 : W.text)
                Text(title).font(.system(size: 16))
                if dot { Circle().fill(W.red).frame(width: 7, height: 7) }
                Spacer()
                if let badge { Text(badge).font(.system(size: 15, weight: .semibold)).foregroundStyle(W.purple) }
            }
            .foregroundStyle(muted ? W.text3 : W.text)
            .frame(height: 55).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

/// Profile: who you are, your numbers, the Arbus prize shop and your history.
struct ProfileScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var shop = ShopStore()
    @State private var shown = 12
    @State private var redeem: ShopProduct?
    @State private var favorites = Set((UserDefaults.standard.string(forKey: "evflow.favorites") ?? "").split(separator: ",").map(String.init))

    var body: some View {
        let g = app.game
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // header
                VStack(spacing: 10) {
                    ProfilePic(size: 92, corner: 26)
                    Text("Vairuotojas").font(.system(size: 24, weight: .bold))
                    HStack(spacing: 6) {
                        Icon("star", size: 14, color: Color(hex: 0xf5b400))
                        Text(g.level).font(.system(size: 14, weight: .semibold)).foregroundStyle(W.text2)
                    }
                    .padding(.horizontal, 12).frame(height: 30)
                    .background(Capsule().fill(W.field))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                StatStrip(items: [
                    .init(value: "\(g.points)", label: "taškai", color: W.purple),
                    .init(value: "\(g.reputation)", label: "reputacija"),
                    .init(value: "\(g.streak)", label: "iš eilės laiku"),
                ])
                .padding(.top, 22)

                // shop
                section("Prizai")
                LazyVStack(spacing: 14) {
                    ForEach(shop.products.prefix(shown)) { p in
                        PrizeCard(p: p, points: g.points, favorite: favorites.contains(p.id), onFavorite: { toggleFavorite(p.id) })
                            .onTapGesture { redeem = p }
                    }
                    if shop.products.count > shown {
                        Button("Rodyti daugiau") { shown += 12 }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                    if shop.products.isEmpty {
                        Text("Prizų nepavyko įkelti").font(.system(size: 14)).foregroundStyle(W.text2).padding(.vertical, 20)
                    }
                }
                .confirmationDialog(redeem.map { g.points >= $0.points ? "Iškeisti už \($0.points) taškų?" : "Trūksta \($0.points - g.points) taškų" } ?? "",
                                    isPresented: Binding(get: { redeem != nil }, set: { if !$0 { redeem = nil } }), titleVisibility: .visible) {
                    if let p = redeem, g.points >= p.points {
                        Button("Iškeisti: \(p.title)") {
                            app.add(.redeem, pts: -p.points, label: "Iškeista: \(p.title)")
                            app.celebration = .init(title: "Prizas jūsų!", text: "\(p.title) – kodą rasite skiltyje „Pranešimai“.", pts: -p.points, mood: .love)
                        }
                    }
                }

                section("Istorija")
                VStack(spacing: 0) {
                    ForEach(Array(g.events.enumerated()), id: \.element.id) { i, e in
                        HStack(spacing: 14) {
                            Circle().fill((e.kind == .late ? W.orange : e.kind == .ontime ? W.green : W.grey).opacity(0.12))
                                .frame(width: 36, height: 36)
                                .overlay(Icon(e.kind == .ontime ? "check" : e.kind == .report ? "camera" : e.kind == .redeem ? "gift" : "hourglass",
                                              size: 17, color: e.kind == .late ? W.orangeFg : e.kind == .ontime ? W.greenFg : W.text2))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.label).font(.system(size: 14.5)).foregroundStyle(W.text).lineLimit(1)
                                Text(e.at, format: .relative(presentation: .named)).font(.system(size: 12.5)).foregroundStyle(W.text2)
                            }
                            Spacer(minLength: 8)
                            if e.pts != 0 {
                                Text(e.pts > 0 ? "+\(e.pts)" : "\(e.pts)").font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(e.pts > 0 ? W.greenFg : W.text2)
                            }
                        }
                        .padding(.vertical, 10)
                        if i < g.events.count - 1 { Divline().padding(.leading, 50) }
                    }
                }
            }
            .padding(.horizontal, W.margin).padding(.bottom, 30)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { withAnimation(.snappy) { app.screen = .menu } } label: {
                    Icon("chevron-left", size: 18).frame(width: 36, height: 36).background(Circle().fill(W.field))
                }
                Spacer()
                Text("Profilis").font(.system(size: 17, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, W.margin).padding(.vertical, 8)
            .background(Color.white)
        }
        .background(Color.white.ignoresSafeArea())
        .transition(.move(edge: .trailing))
        .task { await shop.load() }
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        UserDefaults.standard.set(favorites.joined(separator: ","), forKey: "evflow.favorites")
    }

    func section(_ t: String) -> some View {
        Text(t).font(.system(size: 20, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 28).padding(.bottom, 12)
    }
}

/// Nustatymai (from the menu): navigation app, how we calculate, unrecognised QR codes.
struct SettingsScreen: View {
    @EnvironmentObject var app: AppState
    @State private var showQR = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Menu {
                    Button("Klausti kiekvieną kartą") { app.alwaysNav = nil }
                    ForEach(app.installedNavApps) { a in Button(a.title) { app.alwaysNav = a } }
                } label: {
                    row(.route, title: "Navigacija", sub: app.alwaysNav.map { "Visada: \($0.title)" } ?? "Klausti kiekvieną kartą", chevron: "chevron-down")
                }
                Divline().padding(.leading, 58)
                Button { withAnimation(.snappy) { app.screen = .howItWorks } } label: {
                    row(.chart, title: "Kaip skaičiuojame", sub: "Prognozės, krovimo laikas ir taškai", chevron: "arrow-right")
                }
                let unknown = app.unknownQRs
                if !unknown.isEmpty {
                    Divline().padding(.leading, 58)
                    Button { showQR = true } label: {
                        row(.qr, title: "Neatpažinti QR (\(unknown.count))", sub: "Operatorių kodų formatai (debug)", chevron: "arrow-right")
                    }
                    .sheet(isPresented: $showQR) {
                        NavigationStack {
                            List(unknown) { q in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(q.text).font(.system(size: 14, design: .monospaced)).textSelection(.enabled)
                                    Text("\(q.stationId ?? "–") · \(q.scannedAt.formatted(date: .numeric, time: .shortened))")
                                        .font(.system(size: 12)).foregroundStyle(W.text2)
                                }
                            }
                            .navigationTitle("Neatpažinti QR").navigationBarTitleDisplayMode(.inline)
                        }
                    }
                }
            }
            .padding(.horizontal, W.margin).padding(.top, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { withAnimation(.snappy) { app.screen = .menu } } label: {
                    Icon("chevron-left", size: 18).frame(width: 36, height: 36).background(Circle().fill(W.field))
                }
                Spacer()
                Text("Nustatymai").font(.system(size: 17, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, W.margin).padding(.vertical, 8)
            .background(Color.white)
        }
        .background(Color.white.ignoresSafeArea())
        .transition(.move(edge: .trailing))
    }

    func row(_ glyph: Glyph, title: String, sub: String, chevron: String) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(W.field).frame(width: 44, height: 44)
                .overlay(GlyphView(glyph, size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(W.text)
                Text(sub).font(.system(size: 13)).foregroundStyle(W.text2).lineLimit(1)
            }
            Spacer(minLength: 8)
            Icon(chevron, size: 16, color: W.text3)
        }
        .padding(.vertical, 12).contentShape(Rectangle())
    }
}

/// "Kaip skaičiuojame": plain-language rules (from Nustatymai).
struct HowItWorksScreen: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                block("Kada atsilaisvins",
                      "Imame praeities tos pačios galios įkrovimus, kurie jau truko tiek pat, kiek dabartinis, ir žiūrime, kokia jų dalis baigėsi per 30 min. Tai ir yra tikimybė.")
                block("Kiek tau krautis",
                      "Stotelė rodo tik „užimta“ arba „laisva“, bet ne tai, ar automobilis dar kraunasi. Todėl krovimo laiką vertiname pagal jungties galią, o kai turi bent \(Rewards.historyMinSessions) savo krovimus – pagal tavo įprastą laiką. Jei dar kraunasi, gali pratęsti „Dar kraunasi +\(Rewards.extendMin) min.“ (iki \(Rewards.maxExtensions) kartų).")
                block("Taškai",
                      "Krovimo pabaigą nustatome tik iš stotelės duomenų – kai jungtis vėl „laisva“. Atlaisvinus per \(Rewards.graceMin) min. po numatyto laiko gauni +\(Rewards.onTimePoints) taškų. Vėluojant už kiekvienas pradėtas \(Rewards.lateBlockMin) min. reputacija mažėja. Jei nematome, kad krautum, sesija atšaukiama be baudos.")
                block("Ko nematome",
                      "Jei kabelis ištrauktas, bet automobilis liko stovėti, stotelė rodo „laisva“. Tokius atvejus padeda pastebėti kitų vartotojų pranešimai.")
            }
            .padding(.horizontal, W.margin).padding(.top, 8).padding(.bottom, 30)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { withAnimation(.snappy) { app.screen = .settings } } label: {
                    Icon("chevron-left", size: 18).frame(width: 36, height: 36).background(Circle().fill(W.field))
                }
                Spacer()
                Text("Kaip skaičiuojame").font(.system(size: 17, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, W.margin).padding(.vertical, 8)
            .background(Color.white)
        }
        .background(Color.white.ignoresSafeArea())
        .transition(.move(edge: .trailing))
    }

    func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 17, weight: .bold))
            Text(text).font(.system(size: 15)).foregroundStyle(W.text2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Shop card (IKI-style): tags + heart, big photo, title, points pill and share. Tap the card to redeem.
struct PrizeCard: View {
    let p: ShopProduct
    let points: Int
    let favorite: Bool
    let onFavorite: () -> Void

    var body: some View {
        let can = points >= p.points
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 6) {
                if p.isFeatured == true { tag("REKOMENDUOJAME", bg: Color(hex: 0x12813d), fg: .white) }
                if let c = p.category, !c.isEmpty { tag(c.uppercased(), bg: Color(hex: 0xffe37a), fg: W.text) }
                Spacer(minLength: 0)
                Button(action: onFavorite) {
                    Image(systemName: favorite ? "heart.fill" : "heart").font(.system(size: 22))
                        .foregroundStyle(favorite ? W.red : W.text)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 16) {
                RemoteImage(url: p.image)
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text([p.title, p.subtitle].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(W.text).lineLimit(3)
                    Spacer(minLength: 10)
                    HStack(spacing: 8) {
                        Text("\(p.points)").font(.system(size: 18, weight: .bold)).foregroundStyle(can ? W.text : W.text3)
                            .padding(.horizontal, 14).frame(height: 40).background(Capsule().fill(W.field))
                        Spacer(minLength: 0)
                        ShareLink(item: p.image ?? URL(string: "https://evflow.lt")!,
                                  message: Text("\(p.title) – EVFlow prizas už \(p.points) taškų")) {
                            HStack(spacing: 6) {
                                GlyphView(.share, size: 18, color: .white)
                                Text("Dalintis").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14).frame(height: 40).background(Capsule().fill(W.blue))
                        }
                    }
                }
                .frame(height: 128)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(W.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    func tag(_ t: String, bg: Color, fg: Color) -> some View {
        Text(t).font(.system(size: 12, weight: .bold)).foregroundStyle(fg).lineLimit(1)
            .padding(.horizontal, 12).frame(height: 28).background(Capsule().fill(bg))
    }
}
