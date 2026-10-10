import SwiftUI

/// EVFlow's own monochrome icon set: one 24 pt grid, 1.8 pt rounded strokes, small solid accents.
enum Glyph {
    case charge, gift, message, sliders, help, reset, route, chart, qr, share
}

struct GlyphView: View {
    let glyph: Glyph
    var size: CGFloat = 24
    var color: Color = W.text

    init(_ glyph: Glyph, size: CGFloat = 24, color: Color = W.text) {
        self.glyph = glyph; self.size = size; self.color = color
    }

    var body: some View {
        Canvas { ctx, sz in
            ctx.scaleBy(x: sz.width / 24, y: sz.height / 24)
            let line = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            let (strokes, fills) = Self.paths(glyph)
            for p in strokes { ctx.stroke(p, with: .color(color), style: line) }
            for p in fills { ctx.fill(p, with: .color(color)) }
        }
        .frame(width: size, height: size)
    }

    private static func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
    }
    private static func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    /// (stroked, filled)
    private static func paths(_ g: Glyph) -> ([Path], [Path]) {
        switch g {
        case .charge: // battery with a bolt
            var bolt = Path()
            bolt.move(to: .init(x: 12, y: 8.6)); bolt.addLine(to: .init(x: 8.9, y: 12.4)); bolt.addLine(to: .init(x: 11.3, y: 12.4))
            bolt.addLine(to: .init(x: 10.4, y: 15.4)); bolt.addLine(to: .init(x: 13.7, y: 11.4)); bolt.addLine(to: .init(x: 11.3, y: 11.4)); bolt.closeSubpath()
            return ([rr(2.8, 7, 16.4, 10, 2.8)], [rr(20.2, 10.2, 1.6, 3.6, 0.8), bolt])

        case .gift:
            var bow = Path()
            bow.move(to: .init(x: 12, y: 8)); bow.addCurve(to: .init(x: 8.3, y: 4.6), control1: .init(x: 10.6, y: 5.4), control2: .init(x: 9.4, y: 4.2))
            bow.addCurve(to: .init(x: 12, y: 8), control1: .init(x: 6.9, y: 5.2), control2: .init(x: 8.6, y: 8))
            bow.move(to: .init(x: 12, y: 8)); bow.addCurve(to: .init(x: 15.7, y: 4.6), control1: .init(x: 13.4, y: 5.4), control2: .init(x: 14.6, y: 4.2))
            bow.addCurve(to: .init(x: 12, y: 8), control1: .init(x: 17.1, y: 5.2), control2: .init(x: 15.4, y: 8))
            var ribbon = Path(); ribbon.move(to: .init(x: 12, y: 8)); ribbon.addLine(to: .init(x: 12, y: 20.5))
            return ([rr(3.5, 8, 17, 4.2, 1.6), rr(5, 12.2, 14, 8.3, 1.8), ribbon, bow], [])

        case .message: // speech bubble with two lines
            var bubble = Path()
            bubble.addRoundedRect(in: CGRect(x: 3.3, y: 4.3, width: 17.4, height: 12.6), cornerSize: .init(width: 4, height: 4), style: .continuous)
            var tail = Path(); tail.move(to: .init(x: 8, y: 16.9)); tail.addLine(to: .init(x: 6.8, y: 20.6)); tail.addLine(to: .init(x: 11.6, y: 16.9))
            var lines = Path()
            lines.move(to: .init(x: 7.8, y: 9.4)); lines.addLine(to: .init(x: 16.2, y: 9.4))
            lines.move(to: .init(x: 7.8, y: 12.6)); lines.addLine(to: .init(x: 12.8, y: 12.6))
            return ([bubble, tail, lines], [])

        case .sliders: // three tracks with knobs
            var tracks = Path()
            for (y, k) in [(6.5, 9.0), (12.0, 15.5), (17.5, 7.5)] {
                tracks.move(to: .init(x: 3.5, y: y)); tracks.addLine(to: .init(x: k - 2.6, y: y))
                tracks.move(to: .init(x: k + 2.6, y: y)); tracks.addLine(to: .init(x: 20.5, y: y))
            }
            return ([tracks, dot(9, 6.5, 2.2), dot(15.5, 12, 2.2), dot(7.5, 17.5, 2.2)], [])

        case .help: // circle with a question mark
            var q = Path()
            q.move(to: .init(x: 9.6, y: 9.7))
            q.addCurve(to: .init(x: 14.4, y: 9.7), control1: .init(x: 9.8, y: 6.6), control2: .init(x: 14.2, y: 6.6))
            q.addCurve(to: .init(x: 12, y: 13.3), control1: .init(x: 14.6, y: 11.9), control2: .init(x: 12, y: 11.6))
            return ([dot(12, 12, 8.7), q], [dot(12, 16.4, 1.1)])

        case .reset: // open circle with an arrow head
            var arc = Path()
            arc.addArc(center: .init(x: 12, y: 12.5), radius: 7.3, startAngle: .degrees(-150), endAngle: .degrees(160), clockwise: false)
            var head = Path()
            head.move(to: .init(x: 4.6, y: 5.6)); head.addLine(to: .init(x: 5.7, y: 8.9)); head.addLine(to: .init(x: 9.1, y: 8.1))
            return ([arc, head], [])

        case .route: // start dot, curved route, destination pin
            var path = Path()
            path.move(to: .init(x: 7.6, y: 16.6))
            path.addCurve(to: .init(x: 16, y: 11.4), control1: .init(x: 15.5, y: 18.5), control2: .init(x: 8.5, y: 11))
            var pin = Path()
            pin.move(to: .init(x: 17.5, y: 11.6))
            pin.addCurve(to: .init(x: 14, y: 6.6), control1: .init(x: 16.2, y: 10.2), control2: .init(x: 14, y: 8.6))
            pin.addArc(center: .init(x: 17.5, y: 6.6), radius: 3.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            pin.addCurve(to: .init(x: 17.5, y: 11.6), control1: .init(x: 21, y: 8.6), control2: .init(x: 18.8, y: 10.2))
            return ([dot(6, 18, 2), path, pin], [dot(17.5, 6.6, 1.1)])

        case .chart: // three bars on a baseline
            var base = Path(); base.move(to: .init(x: 3.5, y: 20.2)); base.addLine(to: .init(x: 20.5, y: 20.2))
            return ([rr(5, 12.5, 3.4, 4.8, 1.4), rr(10.3, 8.5, 3.4, 8.8, 1.4), rr(15.6, 4.5, 3.4, 12.8, 1.4), base], [])

        case .qr: // scan corners + modules
            var c = Path()
            for (x, y, dx, dy) in [(3.5, 3.5, 1.0, 1.0), (20.5, 3.5, -1.0, 1.0), (3.5, 20.5, 1.0, -1.0), (20.5, 20.5, -1.0, -1.0)] {
                c.move(to: .init(x: x, y: y + 4.6 * dy)); c.addLine(to: .init(x: x, y: y)); c.addLine(to: .init(x: x + 4.6 * dx, y: y))
            }
            return ([c], [rr(7.6, 7.6, 3.6, 3.6, 0.9), rr(12.8, 7.6, 3.6, 3.6, 0.9), rr(7.6, 12.8, 3.6, 3.6, 0.9),
                          rr(12.8, 12.8, 1.7, 1.7, 0.5), rr(14.7, 14.7, 1.7, 1.7, 0.5)])

        case .share: // tray with an up arrow
            var tray = Path()
            tray.move(to: .init(x: 8.4, y: 10)); tray.addLine(to: .init(x: 6.8, y: 10))
            tray.addQuadCurve(to: .init(x: 5, y: 11.8), control: .init(x: 5, y: 10)); tray.addLine(to: .init(x: 5, y: 18.7))
            tray.addQuadCurve(to: .init(x: 6.8, y: 20.5), control: .init(x: 5, y: 20.5)); tray.addLine(to: .init(x: 17.2, y: 20.5))
            tray.addQuadCurve(to: .init(x: 19, y: 18.7), control: .init(x: 19, y: 20.5)); tray.addLine(to: .init(x: 19, y: 11.8))
            tray.addQuadCurve(to: .init(x: 17.2, y: 10), control: .init(x: 19, y: 10)); tray.addLine(to: .init(x: 15.6, y: 10))
            var arrow = Path()
            arrow.move(to: .init(x: 12, y: 14.2)); arrow.addLine(to: .init(x: 12, y: 3.4))
            arrow.move(to: .init(x: 8.7, y: 6.6)); arrow.addLine(to: .init(x: 12, y: 3.4)); arrow.addLine(to: .init(x: 15.3, y: 6.6))
            return ([tray, arrow], [])
        }
    }
}
