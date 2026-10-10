import SwiftUI

/// "Kištukas" – our own plug mascot (original artwork, drawn in code).
struct Mascot: View {
    enum Mood { case love, happy, sleepy }
    var size: CGFloat = 96
    var mood: Mood = .love

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 120
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: x * s, y: y * s) }
            let ink = Color(hex: 0x1b1b1b)

            // prongs
            for x in [44.0, 76.0] {
                var pr = Path(); pr.move(to: p(x, 14)); pr.addLine(to: p(x, 30))
                ctx.stroke(pr, with: .color(Color(hex: 0x2b2b2b)), style: .init(lineWidth: 7 * s, lineCap: .round))
            }
            // body
            var body = Path()
            body.move(to: p(22, 52))
            body.addCurve(to: p(60, 28), control1: p(22, 35), control2: p(34, 28))
            body.addCurve(to: p(98, 52), control1: p(86, 28), control2: p(98, 35))
            body.addLine(to: p(98, 70))
            body.addCurve(to: p(60, 104), control1: p(98, 92), control2: p(82, 104))
            body.addCurve(to: p(22, 70), control1: p(38, 104), control2: p(22, 92))
            body.closeSubpath()
            ctx.fill(body, with: .color(Color(hex: 0x7be0a6)))
            ctx.stroke(body, with: .color(ink), lineWidth: 5 * s)
            // cable
            var cable = Path(); cable.move(to: p(60, 104)); cable.addQuadCurve(to: p(72, 114), control: p(60, 114))
            ctx.stroke(cable, with: .color(ink), style: .init(lineWidth: 5 * s, lineCap: .round))
            // eyes
            switch mood {
            case .love:
                for cx in [41.0, 79.0] {
                    var h = Path()
                    h.move(to: p(cx, 64))
                    h.addCurve(to: p(cx - 10, 52), control1: p(cx - 6, 59), control2: p(cx - 12, 56))
                    h.addCurve(to: p(cx, 50), control1: p(cx - 8, 46), control2: p(cx - 2, 46))
                    h.addCurve(to: p(cx + 10, 52), control1: p(cx + 2, 46), control2: p(cx + 8, 46))
                    h.addCurve(to: p(cx, 64), control1: p(cx + 12, 56), control2: p(cx + 6, 59))
                    ctx.fill(h, with: .color(Color(hex: 0xff4d6d)))
                    ctx.stroke(h, with: .color(ink), lineWidth: 3 * s)
                }
            case .happy:
                for cx in [44.0, 76.0] { ctx.fill(Path(ellipseIn: CGRect(x: (cx - 6) * s, y: 50 * s, width: 12 * s, height: 12 * s)), with: .color(ink)) }
            case .sleepy:
                for cx in [41.0, 79.0] {
                    var e = Path(); e.move(to: p(cx - 8, 57)); e.addQuadCurve(to: p(cx + 8, 57), control: p(cx, 63))
                    ctx.stroke(e, with: .color(ink), style: .init(lineWidth: 4 * s, lineCap: .round))
                }
            }
            // smile + cheeks
            var m = Path(); m.move(to: p(48, 76)); m.addQuadCurve(to: p(72, 76), control: p(60, 88))
            ctx.stroke(m, with: .color(ink), style: .init(lineWidth: 5 * s, lineCap: .round))
            for cx in [34.0, 86.0] {
                ctx.fill(Path(ellipseIn: CGRect(x: (cx - 5) * s, y: 67 * s, width: 10 * s, height: 10 * s)), with: .color(Color(hex: 0xff9db0, alpha: 0.7)))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Report button glyph: rounded warning triangle with a plus.
struct ReportGlyph: View {
    var size: CGFloat = 48
    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 48
            var t = Path()
            t.move(to: .init(x: 24 * s, y: 7 * s))
            t.addLine(to: .init(x: 42 * s, y: 39 * s))
            t.addLine(to: .init(x: 6 * s, y: 39 * s))
            t.closeSubpath()
            ctx.fill(t, with: .color(Color(hex: 0xffd60a)))
            ctx.stroke(t, with: .color(Color(hex: 0x1b1b1b)), style: .init(lineWidth: 3.6 * s, lineJoin: .round))
            var plus = Path()
            plus.move(to: .init(x: 24 * s, y: 20 * s)); plus.addLine(to: .init(x: 24 * s, y: 32 * s))
            plus.move(to: .init(x: 18 * s, y: 26 * s)); plus.addLine(to: .init(x: 30 * s, y: 26 * s))
            ctx.stroke(plus, with: .color(Color(hex: 0x1b1b1b)), style: .init(lineWidth: 3.6 * s, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}
