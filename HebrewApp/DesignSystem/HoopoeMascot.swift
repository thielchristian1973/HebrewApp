import SwiftUI

/// The four Wiedehopf (hoopoe) mascot expressions approved 21.09.2026 alongside the blue
/// rebrand (Documentation/DECISIONS.md, "Rebranding-Entscheidung").
enum HoopoeExpression: CaseIterable {
    case waving
    case flying
    case happy
    case celebrating
}

struct HoopoeMascotView: View {
    var expression: HoopoeExpression

    var body: some View {
        let box = HoopoeArt.viewBox(for: expression)
        Canvas { context, size in
            let scale = min(size.width / box.width, size.height / box.height)
            var canvas = context
            canvas.translateBy(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)
            canvas.scaleBy(x: scale, y: scale)
            canvas.translateBy(x: -box.minX, y: -box.minY)
            HoopoeArt.draw(expression, in: canvas)
        }
        .aspectRatio(box.width / box.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Direct port of the vector artwork worked out and visually approved during the rebrand
/// design round ("das passt so und kann übernommen werden") — the coordinates below reproduce
/// that specific approved illustration, not an arbitrary redesign. Each pose mirrors the
/// structure of its source SVG one-to-one so it stays easy to diff against.
private enum HoopoeArt {
    static func viewBox(for expression: HoopoeExpression) -> CGRect {
        switch expression {
        case .waving, .flying, .happy:
            return CGRect(x: -30, y: -35, width: 170, height: 180)
        case .celebrating:
            return CGRect(x: -40, y: -45, width: 190, height: 200)
        }
    }

    static func draw(_ expression: HoopoeExpression, in context: GraphicsContext) {
        switch expression {
        case .waving: drawWaving(in: context)
        case .flying: drawFlying(in: context)
        case .happy: drawHappy(in: context)
        case .celebrating: drawCelebrating(in: context)
        }
    }

    // MARK: - Palette

    private static let ink = Color(hex: 0x2B2420)
    private static let crest = ColorTokens.accent
    private static let bodyBase = Color(hex: 0xE8AD72)
    private static let bodyShadow = Color(hex: 0xCE8A4C)
    private static let bodyHighlight = Color(hex: 0xF6CBA0)
    private static let headBase = Color(hex: 0xEDBB85)
    private static let headShadow = Color(hex: 0xDA9C5C)
    private static let headHighlight = Color(hex: 0xFAD9B4)
    private static let blush = Color(hex: 0xDD8F6C)
    private static let plumageLight = Color(hex: 0xF4F3EC)
    private static let speedLine = Color(hex: 0xC3CBE4)

    // MARK: - Group primitives (mirror SVG `<g transform="...">`)

    private static func path(_ build: (inout Path) -> Void) -> Path { Path(build) }

    private static func rotated(_ context: GraphicsContext, degrees: Double, anchor: CGPoint, _ draw: (GraphicsContext) -> Void) {
        guard degrees != 0 else { draw(context); return }
        var group = context
        group.translateBy(x: anchor.x, y: anchor.y)
        group.rotate(by: .degrees(degrees))
        group.translateBy(x: -anchor.x, y: -anchor.y)
        draw(group)
    }

    private static func mirrored(_ context: GraphicsContext, _ draw: (GraphicsContext) -> Void) {
        var group = context
        group.translateBy(x: 120, y: 0)
        group.scaleBy(x: -1, y: 1)
        draw(group)
    }

    private static func clipped(_ context: GraphicsContext, to clipPath: Path, _ draw: (GraphicsContext) -> Void) {
        var group = context
        group.clip(to: clipPath)
        draw(group)
    }

    // MARK: - Shared shapes

    private static func drawWing(
        _ context: GraphicsContext,
        fill: Path,
        clip: Path,
        bars: [CGRect],
        barRotation: Double,
        barAnchor: CGPoint,
        groupRotation: Double = 0,
        groupAnchor: CGPoint = .zero
    ) {
        rotated(context, degrees: groupRotation, anchor: groupAnchor) { g in
            g.fill(fill, with: .color(plumageLight))
            clipped(g, to: clip) { g2 in
                rotated(g2, degrees: barRotation, anchor: barAnchor) { g3 in
                    for rect in bars {
                        g3.fill(Path(rect), with: .color(ink))
                    }
                }
            }
        }
    }

    private static func drawCrest(_ context: GraphicsContext, feather: Path, pivot: CGPoint, dot: CGPoint) {
        let dotPath = Path(ellipseIn: CGRect(x: dot.x - 2.9, y: dot.y - 2.9, width: 5.8, height: 5.8))
        for angle in [0.0, -24, 24, -46, 46] {
            rotated(context, degrees: angle, anchor: pivot) { g in
                g.fill(feather, with: .color(crest))
                g.fill(dotPath, with: .color(ink))
            }
        }
    }

    /// The beak's local shape is identical across every pose, offset only by the head's
    /// (pre-rotation) center Y — verified against all four source SVGs before factoring out.
    private static func beakPath(headCenterY cy: CGFloat) -> Path {
        path { p in
            p.move(to: CGPoint(x: 55.5, y: cy + 8))
            p.addCurve(to: CGPoint(x: 60, y: cy + 37), control1: CGPoint(x: 56, y: cy + 18), control2: CGPoint(x: 57.3, y: cy + 27))
            p.addCurve(to: CGPoint(x: 64.5, y: cy + 8), control1: CGPoint(x: 62.7, y: cy + 27), control2: CGPoint(x: 64, y: cy + 18))
            p.addQuadCurve(to: CGPoint(x: 55.5, y: cy + 8), control: CGPoint(x: 60, y: cy + 4))
            p.closeSubpath()
        }
    }

    private static func drawRestingLegsFeetTail(_ context: GraphicsContext) {
        let leg = path { p in
            p.move(to: CGPoint(x: 54, y: 102))
            p.addCurve(to: CGPoint(x: 50, y: 121), control1: CGPoint(x: 52, y: 108), control2: CGPoint(x: 50.5, y: 115))
            p.addLine(to: CGPoint(x: 53.5, y: 121.5))
            p.addCurve(to: CGPoint(x: 57, y: 102), control1: CGPoint(x: 54.5, y: 115), control2: CGPoint(x: 55.5, y: 108))
            p.closeSubpath()
        }
        let foot = path { p in
            p.move(to: CGPoint(x: 44, y: 122))
            p.addCurve(to: CGPoint(x: 53, y: 121), control1: CGPoint(x: 47, y: 120.5), control2: CGPoint(x: 50, y: 120))
            p.addCurve(to: CGPoint(x: 44, y: 122), control1: CGPoint(x: 50, y: 122.5), control2: CGPoint(x: 47, y: 123.5))
            p.closeSubpath()
            p.move(to: CGPoint(x: 53, y: 121))
            p.addCurve(to: CGPoint(x: 62, y: 121.5), control1: CGPoint(x: 56, y: 120), control2: CGPoint(x: 59, y: 120))
            p.addCurve(to: CGPoint(x: 53, y: 121), control1: CGPoint(x: 59, y: 122.5), control2: CGPoint(x: 56, y: 122.5))
            p.closeSubpath()
        }
        context.fill(leg, with: .color(ink))
        mirrored(context) { $0.fill(leg, with: .color(ink)) }
        context.fill(foot, with: .color(ink))
        mirrored(context) { $0.fill(foot, with: .color(ink)) }

        let tailOuter = path { p in
            p.move(to: CGPoint(x: 60, y: 102))
            p.addLine(to: CGPoint(x: 51, y: 117))
            p.addLine(to: CGPoint(x: 60, y: 114))
            p.addLine(to: CGPoint(x: 69, y: 117))
            p.closeSubpath()
        }
        let tailInner = path { p in
            p.move(to: CGPoint(x: 60, y: 106))
            p.addLine(to: CGPoint(x: 55, y: 115))
            p.addLine(to: CGPoint(x: 60, y: 113.5))
            p.addLine(to: CGPoint(x: 65, y: 115))
            p.closeSubpath()
        }
        context.fill(tailOuter, with: .color(plumageLight))
        context.fill(tailInner, with: .color(ink))
    }

    private static func bodyGroup(_ context: GraphicsContext, centerY: CGFloat, rotationDegrees: Double) {
        let center = CGPoint(x: 60, y: centerY)
        rotated(context, degrees: rotationDegrees, anchor: center) { g in
            let bodyRect = CGRect(x: center.x - 27, y: center.y - 27, width: 54, height: 54)
            g.fill(Path(ellipseIn: bodyRect), with: .color(bodyBase))
            clipped(g, to: Path(ellipseIn: bodyRect)) { g2 in
                let shadowRect = CGRect(x: center.x + 14 - 23, y: center.y + 14 - 21, width: 46, height: 42)
                let highlightRect = CGRect(x: center.x - 13 - 15, y: center.y - 16 - 13, width: 30, height: 26)
                g2.fill(Path(ellipseIn: shadowRect), with: .color(bodyShadow))
                g2.fill(Path(ellipseIn: highlightRect), with: .color(bodyHighlight.opacity(0.95)))
            }
        }
    }

    private static func headGroup(
        _ context: GraphicsContext,
        centerY: CGFloat,
        rotationDegrees: Double,
        content: (GraphicsContext) -> Void
    ) {
        let center = CGPoint(x: 60, y: centerY)
        rotated(context, degrees: rotationDegrees, anchor: center) { g in
            let headRect = CGRect(x: center.x - 22, y: center.y - 22, width: 44, height: 44)
            g.fill(Path(ellipseIn: headRect), with: .color(headBase))
            clipped(g, to: Path(ellipseIn: headRect)) { g2 in
                let shadowRect = CGRect(x: center.x + 12 - 18, y: center.y + 10 - 16, width: 36, height: 32)
                let highlightRect = CGRect(x: center.x - 11 - 11, y: center.y - 11 - 10, width: 22, height: 20)
                g2.fill(Path(ellipseIn: shadowRect), with: .color(headShadow))
                g2.fill(Path(ellipseIn: highlightRect), with: .color(headHighlight.opacity(0.95)))
            }
            content(g)
        }
    }

    // MARK: - Poses

    private static func drawWaving(in context: GraphicsContext) {
        drawRestingLegsFeetTail(context)

        let wingLFill = path { p in
            p.move(to: CGPoint(x: 36, y: 68))
            p.addCurve(to: CGPoint(x: 9, y: 92), control1: CGPoint(x: 14, y: 60), control2: CGPoint(x: 2, y: 74))
            p.addCurve(to: CGPoint(x: 40, y: 91), control1: CGPoint(x: 19, y: 104), control2: CGPoint(x: 34, y: 103))
            p.addCurve(to: CGPoint(x: 36, y: 68), control1: CGPoint(x: 38, y: 83), control2: CGPoint(x: 37, y: 75))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingLFill, clip: wingLFill,
            bars: [
                CGRect(x: -20, y: 55, width: 90, height: 7),
                CGRect(x: -20, y: 71, width: 90, height: 7),
                CGRect(x: -20, y: 87, width: 90, height: 7),
            ],
            barRotation: -24, barAnchor: CGPoint(x: 24, y: 80),
            groupRotation: 6, groupAnchor: CGPoint(x: 36, y: 80)
        )

        bodyGroup(context, centerY: 86, rotationDegrees: -3)

        headGroup(context, centerY: 46, rotationDegrees: -7) { g in
            drawCrest(
                g,
                feather: path { p in
                    p.move(to: CGPoint(x: 60, y: 26))
                    p.addCurve(to: CGPoint(x: 60, y: -6), control1: CGPoint(x: 57, y: 13), control2: CGPoint(x: 57.5, y: 1))
                    p.addCurve(to: CGPoint(x: 60, y: 26), control1: CGPoint(x: 62.5, y: 1), control2: CGPoint(x: 63, y: 13))
                    p.closeSubpath()
                },
                pivot: CGPoint(x: 60, y: 26), dot: CGPoint(x: 60, y: -3)
            )

            g.fill(Path(ellipseIn: CGRect(x: 43 - 5.5, y: 54 - 3.4, width: 11, height: 6.8)), with: .color(blush.opacity(0.4)))
            g.fill(Path(ellipseIn: CGRect(x: 77 - 5.5, y: 54 - 3.4, width: 11, height: 6.8)), with: .color(blush.opacity(0.4)))

            g.fill(beakPath(headCenterY: 46), with: .color(ink))

            let eyebrow = path { p in
                p.move(to: CGPoint(x: 39, y: 34))
                p.addCurve(to: CGPoint(x: 57, y: 31), control1: CGPoint(x: 44, y: 29), control2: CGPoint(x: 51, y: 28))
                p.addLine(to: CGPoint(x: 56, y: 33.4))
                p.addCurve(to: CGPoint(x: 41, y: 35.6), control1: CGPoint(x: 51, y: 31), control2: CGPoint(x: 45.5, y: 31.8))
                p.closeSubpath()
            }
            g.fill(eyebrow, with: .color(ink))
            mirrored(g) { $0.fill(eyebrow, with: .color(ink)) }

            for (cx, cy) in [(49.0, 47.0), (73.0, 47.0)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 9.5, y: cy - 9.5, width: 19, height: 19)), with: .color(.white))
            }
            for (cx, cy) in [(51.0, 49.5), (75.0, 49.5)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 5.2, y: cy - 5.2, width: 10.4, height: 10.4)), with: .color(ink))
            }
            for (cx, cy) in [(48.8, 45.3), (72.8, 45.3)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4)), with: .color(.white))
            }
        }

        let wingRFill = path { p in
            p.move(to: CGPoint(x: 84, y: 68))
            p.addCurve(to: CGPoint(x: 111, y: 92), control1: CGPoint(x: 106, y: 60), control2: CGPoint(x: 118, y: 74))
            p.addCurve(to: CGPoint(x: 80, y: 91), control1: CGPoint(x: 101, y: 104), control2: CGPoint(x: 86, y: 103))
            p.addCurve(to: CGPoint(x: 84, y: 68), control1: CGPoint(x: 82, y: 83), control2: CGPoint(x: 83, y: 75))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingRFill, clip: wingRFill,
            bars: [
                CGRect(x: 50, y: 55, width: 90, height: 7),
                CGRect(x: 50, y: 71, width: 90, height: 7),
                CGRect(x: 50, y: 87, width: 90, height: 7),
            ],
            barRotation: 24, barAnchor: CGPoint(x: 96, y: 80),
            groupRotation: -95, groupAnchor: CGPoint(x: 88, y: 82)
        )

        let motionLines = path { p in
            p.move(to: CGPoint(x: 122, y: 34)); p.addLine(to: CGPoint(x: 129, y: 29))
            p.move(to: CGPoint(x: 126, y: 44)); p.addLine(to: CGPoint(x: 134, y: 42))
            p.move(to: CGPoint(x: 120, y: 24)); p.addLine(to: CGPoint(x: 126, y: 19))
        }
        context.stroke(motionLines, with: .color(ink.opacity(0.5)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    private static func drawFlying(in context: GraphicsContext) {
        let speedLines = path { p in
            p.move(to: CGPoint(x: -22, y: 38)); p.addLine(to: CGPoint(x: -4, y: 35))
            p.move(to: CGPoint(x: -25, y: 54)); p.addLine(to: CGPoint(x: -6, y: 53))
            p.move(to: CGPoint(x: -20, y: 70)); p.addLine(to: CGPoint(x: -3, y: 69))
        }
        context.stroke(speedLines, with: .color(speedLine), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let leg = path { p in
            p.move(to: CGPoint(x: 54, y: 100))
            p.addCurve(to: CGPoint(x: 50, y: 118), control1: CGPoint(x: 52, y: 106), control2: CGPoint(x: 50.5, y: 112))
            p.addLine(to: CGPoint(x: 53.5, y: 118.5))
            p.addCurve(to: CGPoint(x: 57, y: 100), control1: CGPoint(x: 54.5, y: 112), control2: CGPoint(x: 55.5, y: 106))
            p.closeSubpath()
        }
        let foot = path { p in
            p.move(to: CGPoint(x: 44, y: 119))
            p.addCurve(to: CGPoint(x: 53, y: 118), control1: CGPoint(x: 47, y: 117.5), control2: CGPoint(x: 50, y: 117))
            p.addCurve(to: CGPoint(x: 44, y: 119), control1: CGPoint(x: 50, y: 119.5), control2: CGPoint(x: 47, y: 120.5))
            p.closeSubpath()
            p.move(to: CGPoint(x: 53, y: 118))
            p.addCurve(to: CGPoint(x: 62, y: 118.5), control1: CGPoint(x: 56, y: 117), control2: CGPoint(x: 59, y: 117))
            p.addCurve(to: CGPoint(x: 53, y: 118), control1: CGPoint(x: 59, y: 119.5), control2: CGPoint(x: 56, y: 119.5))
            p.closeSubpath()
        }
        context.fill(leg, with: .color(ink))
        mirrored(context) { $0.fill(leg, with: .color(ink)) }
        context.fill(foot, with: .color(ink))
        mirrored(context) { $0.fill(foot, with: .color(ink)) }

        let tailOuter = path { p in
            p.move(to: CGPoint(x: 60, y: 100))
            p.addLine(to: CGPoint(x: 51, y: 115))
            p.addLine(to: CGPoint(x: 60, y: 112))
            p.addLine(to: CGPoint(x: 69, y: 115))
            p.closeSubpath()
        }
        let tailInner = path { p in
            p.move(to: CGPoint(x: 60, y: 104))
            p.addLine(to: CGPoint(x: 55, y: 113))
            p.addLine(to: CGPoint(x: 60, y: 111.5))
            p.addLine(to: CGPoint(x: 65, y: 113))
            p.closeSubpath()
        }
        context.fill(tailOuter, with: .color(plumageLight))
        context.fill(tailInner, with: .color(ink))

        let wingLFill = path { p in
            p.move(to: CGPoint(x: 36, y: 60))
            p.addCurve(to: CGPoint(x: -5, y: 83), control1: CGPoint(x: 6, y: 47), control2: CGPoint(x: -12, y: 60))
            p.addCurve(to: CGPoint(x: 43, y: 81), control1: CGPoint(x: 5, y: 99), control2: CGPoint(x: 30, y: 97))
            p.addCurve(to: CGPoint(x: 36, y: 60), control1: CGPoint(x: 40, y: 74), control2: CGPoint(x: 38, y: 67))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingLFill, clip: wingLFill,
            bars: [
                CGRect(x: -25, y: 52, width: 90, height: 7),
                CGRect(x: -25, y: 68, width: 90, height: 7),
                CGRect(x: -25, y: 84, width: 90, height: 7),
                CGRect(x: -25, y: 100, width: 90, height: 7),
            ],
            barRotation: 24, barAnchor: CGPoint(x: 20, y: 72),
            groupRotation: 9, groupAnchor: CGPoint(x: 40, y: 63)
        )

        let wingRFill = path { p in
            p.move(to: CGPoint(x: 84, y: 60))
            p.addCurve(to: CGPoint(x: 125, y: 83), control1: CGPoint(x: 114, y: 47), control2: CGPoint(x: 132, y: 60))
            p.addCurve(to: CGPoint(x: 77, y: 81), control1: CGPoint(x: 115, y: 99), control2: CGPoint(x: 90, y: 97))
            p.addCurve(to: CGPoint(x: 84, y: 60), control1: CGPoint(x: 80, y: 74), control2: CGPoint(x: 82, y: 67))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingRFill, clip: wingRFill,
            bars: [
                CGRect(x: 35, y: 52, width: 90, height: 7),
                CGRect(x: 35, y: 68, width: 90, height: 7),
                CGRect(x: 35, y: 84, width: 90, height: 7),
                CGRect(x: 35, y: 100, width: 90, height: 7),
            ],
            barRotation: -24, barAnchor: CGPoint(x: 100, y: 72),
            groupRotation: -9, groupAnchor: CGPoint(x: 80, y: 63)
        )

        bodyGroup(context, centerY: 84, rotationDegrees: -8)

        headGroup(context, centerY: 42, rotationDegrees: -13) { g in
            drawCrest(
                g,
                feather: path { p in
                    p.move(to: CGPoint(x: 60, y: 22))
                    p.addCurve(to: CGPoint(x: 60, y: -10), control1: CGPoint(x: 57, y: 9), control2: CGPoint(x: 57.5, y: -3))
                    p.addCurve(to: CGPoint(x: 60, y: 22), control1: CGPoint(x: 62.5, y: -3), control2: CGPoint(x: 63, y: 9))
                    p.closeSubpath()
                },
                pivot: CGPoint(x: 60, y: 22), dot: CGPoint(x: 60, y: -7)
            )

            g.fill(Path(ellipseIn: CGRect(x: 43 - 5.5, y: 50 - 3.4, width: 11, height: 6.8)), with: .color(blush.opacity(0.4)))
            g.fill(Path(ellipseIn: CGRect(x: 77 - 5.5, y: 50 - 3.4, width: 11, height: 6.8)), with: .color(blush.opacity(0.4)))

            g.fill(beakPath(headCenterY: 42), with: .color(ink))

            let eyebrow = path { p in
                p.move(to: CGPoint(x: 38, y: 31))
                p.addLine(to: CGPoint(x: 55, y: 34.5))
                p.addLine(to: CGPoint(x: 54.3, y: 36.8))
                p.addLine(to: CGPoint(x: 38, y: 33))
                p.closeSubpath()
            }
            g.fill(eyebrow, with: .color(ink))
            mirrored(g) { $0.fill(eyebrow, with: .color(ink)) }

            for (cx, cy) in [(49.0, 44.0), (73.0, 44.0)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 9.5, y: cy - 9.5, width: 19, height: 19)), with: .color(.white))
            }
            for (cx, cy) in [(51.5, 46.5), (75.5, 46.5)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 5.4, y: cy - 5.4, width: 10.8, height: 10.8)), with: .color(ink))
            }
            for (cx, cy) in [(49.3, 42.3), (73.3, 42.3)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4)), with: .color(.white))
            }
        }
    }

    private static func drawHappy(in context: GraphicsContext) {
        drawRestingLegsFeetTail(context)

        let wingLFill = path { p in
            p.move(to: CGPoint(x: 36, y: 68))
            p.addCurve(to: CGPoint(x: 9, y: 92), control1: CGPoint(x: 14, y: 60), control2: CGPoint(x: 2, y: 74))
            p.addCurve(to: CGPoint(x: 40, y: 91), control1: CGPoint(x: 19, y: 104), control2: CGPoint(x: 34, y: 103))
            p.addCurve(to: CGPoint(x: 36, y: 68), control1: CGPoint(x: 38, y: 83), control2: CGPoint(x: 37, y: 75))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingLFill, clip: wingLFill,
            bars: [
                CGRect(x: -20, y: 55, width: 90, height: 7),
                CGRect(x: -20, y: 71, width: 90, height: 7),
                CGRect(x: -20, y: 87, width: 90, height: 7),
            ],
            barRotation: -24, barAnchor: CGPoint(x: 24, y: 80),
            groupRotation: 5, groupAnchor: CGPoint(x: 36, y: 80)
        )

        let wingRFill = path { p in
            p.move(to: CGPoint(x: 84, y: 68))
            p.addCurve(to: CGPoint(x: 111, y: 92), control1: CGPoint(x: 106, y: 60), control2: CGPoint(x: 118, y: 74))
            p.addCurve(to: CGPoint(x: 80, y: 91), control1: CGPoint(x: 101, y: 104), control2: CGPoint(x: 86, y: 103))
            p.addCurve(to: CGPoint(x: 84, y: 68), control1: CGPoint(x: 82, y: 83), control2: CGPoint(x: 83, y: 75))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingRFill, clip: wingRFill,
            bars: [
                CGRect(x: 50, y: 55, width: 90, height: 7),
                CGRect(x: 50, y: 71, width: 90, height: 7),
                CGRect(x: 50, y: 87, width: 90, height: 7),
            ],
            barRotation: 24, barAnchor: CGPoint(x: 96, y: 80),
            groupRotation: -5, groupAnchor: CGPoint(x: 84, y: 80)
        )

        bodyGroup(context, centerY: 86, rotationDegrees: 2)

        headGroup(context, centerY: 46, rotationDegrees: 4) { g in
            drawCrest(
                g,
                feather: path { p in
                    p.move(to: CGPoint(x: 60, y: 26))
                    p.addCurve(to: CGPoint(x: 60, y: -6), control1: CGPoint(x: 57, y: 13), control2: CGPoint(x: 57.5, y: 1))
                    p.addCurve(to: CGPoint(x: 60, y: 26), control1: CGPoint(x: 62.5, y: 1), control2: CGPoint(x: 63, y: 13))
                    p.closeSubpath()
                },
                pivot: CGPoint(x: 60, y: 26), dot: CGPoint(x: 60, y: -3)
            )

            g.fill(Path(ellipseIn: CGRect(x: 43 - 6, y: 55 - 3.8, width: 12, height: 7.6)), with: .color(blush.opacity(0.45)))
            g.fill(Path(ellipseIn: CGRect(x: 77 - 6, y: 55 - 3.8, width: 12, height: 7.6)), with: .color(blush.opacity(0.45)))

            g.fill(beakPath(headCenterY: 46), with: .color(ink))

            let happyEyeL = path { p in
                p.move(to: CGPoint(x: 40, y: 46))
                p.addCurve(to: CGPoint(x: 51.5, y: 45.2), control1: CGPoint(x: 43.5, y: 40.5), control2: CGPoint(x: 48, y: 40.5))
            }
            let happyEyeR = path { p in
                p.move(to: CGPoint(x: 68.5, y: 45.2))
                p.addCurve(to: CGPoint(x: 80, y: 46), control1: CGPoint(x: 72, y: 40.5), control2: CGPoint(x: 76.5, y: 40.5))
            }
            g.stroke(happyEyeL, with: .color(ink), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            g.stroke(happyEyeR, with: .color(ink), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            g.fill(Path(ellipseIn: CGRect(x: 47.5 - 1.6, y: 39.5 - 1.6, width: 3.2, height: 3.2)), with: .color(ink.opacity(0.65)))
            g.fill(Path(ellipseIn: CGRect(x: 72.5 - 1.6, y: 39.5 - 1.6, width: 3.2, height: 3.2)), with: .color(ink.opacity(0.65)))
        }
    }

    private static func drawCelebrating(in context: GraphicsContext) {
        let sparklePoints: [[CGPoint]] = [
            [
                CGPoint(x: -18, y: 20), CGPoint(x: -15, y: 27), CGPoint(x: -8, y: 30), CGPoint(x: -15, y: 33),
                CGPoint(x: -18, y: 40), CGPoint(x: -21, y: 33), CGPoint(x: -28, y: 30), CGPoint(x: -21, y: 27),
            ],
            [
                CGPoint(x: 138, y: 32), CGPoint(x: 140.5, y: 37), CGPoint(x: 146, y: 39), CGPoint(x: 140.5, y: 41),
                CGPoint(x: 138, y: 46), CGPoint(x: 135.5, y: 41), CGPoint(x: 130, y: 39), CGPoint(x: 135.5, y: 37),
            ],
            [
                CGPoint(x: 118, y: -8), CGPoint(x: 120, y: -4), CGPoint(x: 124, y: -2), CGPoint(x: 120, y: 0),
                CGPoint(x: 118, y: 4), CGPoint(x: 116, y: 0), CGPoint(x: 112, y: -2), CGPoint(x: 116, y: -4),
            ],
        ]
        for points in sparklePoints {
            let sparkle = path { p in
                p.move(to: points[0])
                for point in points.dropFirst() { p.addLine(to: point) }
                p.closeSubpath()
            }
            context.fill(sparkle, with: .color(bodyBase))
        }

        drawRestingLegsFeetTail(context)

        bodyGroup(context, centerY: 86, rotationDegrees: 2)

        headGroup(context, centerY: 44, rotationDegrees: 3) { g in
            drawCrest(
                g,
                feather: path { p in
                    p.move(to: CGPoint(x: 60, y: 24))
                    p.addCurve(to: CGPoint(x: 60, y: -8), control1: CGPoint(x: 57, y: 11), control2: CGPoint(x: 57.5, y: -1))
                    p.addCurve(to: CGPoint(x: 60, y: 24), control1: CGPoint(x: 62.5, y: -1), control2: CGPoint(x: 63, y: 11))
                    p.closeSubpath()
                },
                pivot: CGPoint(x: 60, y: 24), dot: CGPoint(x: 60, y: -5)
            )

            g.fill(Path(ellipseIn: CGRect(x: 43 - 6, y: 52 - 3.8, width: 12, height: 7.6)), with: .color(blush.opacity(0.45)))
            g.fill(Path(ellipseIn: CGRect(x: 77 - 6, y: 52 - 3.8, width: 12, height: 7.6)), with: .color(blush.opacity(0.45)))

            g.fill(beakPath(headCenterY: 44), with: .color(ink))

            let eyebrow = path { p in
                p.move(to: CGPoint(x: 38, y: 30))
                p.addCurve(to: CGPoint(x: 58, y: 26), control1: CGPoint(x: 43, y: 24), control2: CGPoint(x: 51, y: 22))
                p.addLine(to: CGPoint(x: 56.7, y: 28.6))
                p.addCurve(to: CGPoint(x: 40, y: 32.4), control1: CGPoint(x: 51, y: 25.4), control2: CGPoint(x: 44.5, y: 27))
                p.closeSubpath()
            }
            g.fill(eyebrow, with: .color(ink))
            mirrored(g) { $0.fill(eyebrow, with: .color(ink)) }

            for (cx, cy) in [(49.0, 45.0), (73.0, 45.0)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 10, y: cy - 10, width: 20, height: 20)), with: .color(.white))
            }
            for (cx, cy) in [(51.0, 47.5), (75.0, 47.5)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 5.4, y: cy - 5.4, width: 10.8, height: 10.8)), with: .color(ink))
            }
            for (cx, cy) in [(48.5, 43.0), (72.5, 43.0)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 2.2, y: cy - 2.2, width: 4.4, height: 4.4)), with: .color(.white))
            }
            for (cx, cy) in [(53.0, 49.5), (77.0, 49.5)] {
                g.fill(Path(ellipseIn: CGRect(x: cx - 1, y: cy - 1, width: 2, height: 2)), with: .color(.white.opacity(0.8)))
            }
        }

        let wingUpRFill = path { p in
            p.move(to: CGPoint(x: 76, y: 76))
            p.addCurve(to: CGPoint(x: 108, y: 18), control1: CGPoint(x: 92, y: 58), control2: CGPoint(x: 106, y: 38))
            p.addCurve(to: CGPoint(x: 70, y: 64), control1: CGPoint(x: 100, y: 20), control2: CGPoint(x: 84, y: 40))
            p.addCurve(to: CGPoint(x: 76, y: 76), control1: CGPoint(x: 68, y: 69), control2: CGPoint(x: 71, y: 73))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingUpRFill, clip: wingUpRFill,
            bars: [
                CGRect(x: 55, y: 20, width: 90, height: 7),
                CGRect(x: 55, y: 36, width: 90, height: 7),
                CGRect(x: 55, y: 52, width: 90, height: 7),
            ],
            barRotation: -52, barAnchor: CGPoint(x: 92, y: 46)
        )

        let wingUpLFill = path { p in
            p.move(to: CGPoint(x: 44, y: 76))
            p.addCurve(to: CGPoint(x: 12, y: 18), control1: CGPoint(x: 28, y: 58), control2: CGPoint(x: 14, y: 38))
            p.addCurve(to: CGPoint(x: 50, y: 64), control1: CGPoint(x: 20, y: 20), control2: CGPoint(x: 36, y: 40))
            p.addCurve(to: CGPoint(x: 44, y: 76), control1: CGPoint(x: 52, y: 69), control2: CGPoint(x: 49, y: 73))
            p.closeSubpath()
        }
        drawWing(
            context, fill: wingUpLFill, clip: wingUpLFill,
            bars: [
                CGRect(x: -45, y: 20, width: 90, height: 7),
                CGRect(x: -45, y: 36, width: 90, height: 7),
                CGRect(x: -45, y: 52, width: 90, height: 7),
            ],
            barRotation: 52, barAnchor: CGPoint(x: 28, y: 46)
        )
    }
}
