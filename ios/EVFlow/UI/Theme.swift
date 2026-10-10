import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: alpha)
    }
}

/// Waze-like design tokens. Metrics measured from Waze iOS screenshots (588 px ≈ 393 pt).
enum W {
    static let text = Color(hex: 0x202124)
    static let text2 = Color(hex: 0x5f6368)
    static let text3 = Color(hex: 0x9aa0a6)
    static let line = Color(hex: 0xe8eaed)
    static let chipLine = Color(hex: 0xdadce0)
    static let field = Color(hex: 0xf1f3f4)
    static let blue = Color(hex: 0x1a8cff)
    static let blueText = Color(hex: 0x0b6fde)
    static let purple = Color(hex: 0x7b3ff2)
    static let purpleDark = Color(hex: 0x4b1fa8)
    static let yellow = Color(hex: 0xffd43b)
    static let green = Color(hex: 0x1db954)
    static let red = Color(hex: 0xf0453a)
    static let orange = Color(hex: 0xff8a00)
    static let grey = Color(hex: 0x9aa0a6)
    static let navCyan = Color(hex: 0x3dc2f5)
    static let greenFg = Color(hex: 0x12813d)
    static let redFg = Color(hex: 0xc5221f)
    static let orangeFg = Color(hex: 0xb85c00)
    static let lilacBg = Color(hex: 0xf5f1ff)
    /// background of the default profile picture
    static let pfpBlue = Color(hex: 0x45a5d8)

    // metrics
    static let margin: CGFloat = 16
    static let fab: CGFloat = 56
    static let report: CGFloat = 70
    static let searchH: CGFloat = 56
    static let chipH: CGFloat = 63
    static let buttonH: CGFloat = 46

    static func pin(_ p: PinState) -> Color {
        switch p { case .free: green; case .busy: red; case .overstay: orange; case .broken: grey; case .stale: Color(hex: 0xb9bec4) }
    }
    static func charger(_ s: ChargerState) -> Color {
        switch s { case .free: green; case .busy: red; case .overstay: orange; case .broken: grey; case .unknown: Color(hex: 0xb9bec4) }
    }
    /// darker status tints for glyphs and text on white
    static func chargerFg(_ s: ChargerState) -> Color {
        switch s { case .free: greenFg; case .busy: redFg; case .overstay: orangeFg; case .broken, .unknown: text3 }
    }
    static func pinFg(_ p: PinState) -> Color {
        switch p { case .free: greenFg; case .busy: redFg; case .overstay: orangeFg; case .broken, .stale: text3 }
    }
    /// P(free within 30 min): ≥ 0.6 green, 0.3–0.6 yellow, < 0.3 red
    static func likelihood(_ l: Likelihood) -> Color {
        switch l { case .high: greenFg; case .medium: Color(hex: 0xa87b00); case .low: redFg }
    }
}

/// Line icon (Lucide, ISC) rendered as a template image.
struct Icon: View {
    let name: String
    var size: CGFloat = 22
    var color: Color = W.text
    init(_ name: String, size: CGFloat = 22, color: Color = W.text) { self.name = name; self.size = size; self.color = color }
    var body: some View {
        Image("ic_\(name)").renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).foregroundStyle(color)
    }
}

/// Colour icon (Fluent Emoji flat, MIT) – used sparingly, like Waze's Home/Work chips.
struct Emoji: View {
    let name: String
    var size: CGFloat = 22
    init(_ name: String, size: CGFloat = 22) { self.name = name; self.size = size }
    var body: some View { Image("emoji_\(name)").resizable().scaledToFit().frame(width: size, height: size) }
}

// MARK: - Buttons

struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity).frame(height: W.buttonH)
            .foregroundStyle(kind == .primary ? .white : W.text)
            .background(Capsule().fill(kind == .primary ? (configuration.isPressed ? Color(hex: 0x0a6fd6) : W.blue) : (configuration.isPressed ? Color(hex: 0xe3e5e8) : W.field)))
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// White floating map button (square = hamburger, round = others)
struct MapFab<Content: View>: View {
    var round = true
    var size: CGFloat = W.fab
    var fill: Color = .white
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        Button(action: action) {
            content()
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: round ? size / 2 : 13, style: .continuous).fill(fill))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        }.buttonStyle(PressStyle())
    }
}

struct Pill: View {
    let text: String
    var fg: Color = W.text
    var body: some View {
        Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(fg).lineLimit(1)
            .padding(.horizontal, 10).frame(height: 26)
            .background(Capsule().fill(W.field))
    }
}

struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) { Icon("x", size: 18).frame(width: 32, height: 32).background(Circle().fill(W.field)) }
    }
}

/// Waze-style bottom sheet: rounded top, thin grabber, soft shadow.
struct BottomSheet<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(hex: 0xb8bbbf)).frame(width: 56, height: 4).padding(.top, 12).padding(.bottom, 14)
            content()
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .transition(.move(edge: .bottom))
    }
}

struct InsightBox: View {
    var icon = "lightbulb"
    var tint: Color = W.purple
    var bg: Color = W.lilacBg
    let text: Text
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Icon(icon, size: 17, color: tint).padding(.top, 1)
            text.font(.system(size: 13.5)).foregroundStyle(W.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg))
    }
}

/// Grey box with 2-3 key numbers separated by hairlines.
struct StatStrip: View {
    struct Item { let value: String; let label: String; var color: Color = W.text }
    let items: [Item]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                if i > 0 { Rectangle().fill(W.chipLine).frame(width: 1, height: 34) }
                VStack(spacing: 2) {
                    Text(items[i].value).font(.system(size: 21, weight: .bold)).foregroundStyle(items[i].color)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(items[i].label).font(.system(size: 13)).foregroundStyle(W.text2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(W.field))
    }
}

struct Divline: View {
    var body: some View { Rectangle().fill(W.line).frame(height: 1) }
}

/// User's profile picture (default for now: the duck)
struct ProfilePic: View {
    var size: CGFloat = 56
    var corner: CGFloat = 13
    var body: some View {
        Image("pfp_default").resizable().scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

extension AnyTransition {
    /// Sheet swap like Waze: the outgoing sheet slides down first, then the incoming one slides up.
    static var sheetSwap: AnyTransition {
        .asymmetric(
            insertion: AnyTransition.move(edge: .bottom).animation(.snappy(duration: 0.32).delay(0.18)),
            removal: AnyTransition.move(edge: .bottom).animation(.easeIn(duration: 0.18))
        )
    }
}

/// Minimal station glyph (Krea) tinted by status – list rows
struct StationGlyph: View {
    let color: Color
    var size: CGFloat = 38
    var body: some View {
        Image("k_station").renderingMode(.template).resizable().scaledToFit()
            .frame(width: size * 0.66, height: size * 0.66).foregroundStyle(color)
            .frame(width: size, height: size)
    }
}
