import CoreGraphics

/// The coffee-bean mark, drawn from scratch. The menu bar glyph and the app
/// icon (scripts/make_icon.sh compiles this same file) both use it, so they
/// always match.
enum BeanGlyph {
    // Proportions, as fractions of the square the bean is drawn in.
    static let tilt: CGFloat = 35 * .pi / 180
    static let halfLength: CGFloat = 0.40
    static let halfWidth: CGFloat = 0.29
    /// Where the crease starts and ends, as a fraction of the half-length.
    static let creaseEnd: CGFloat = 0.80
    /// The crease's S-bend: control points as fractions of half-length (x) and half-width (y).
    static let creaseBend = CGPoint(x: 0.30, y: 0.60)
    static let creaseWidth: CGFloat = 0.09
    static let outlineWidth: CGFloat = 0.085

    /// Draws the bean centred in `rect`. `filled` draws a solid bean with the
    /// crease cut out of it; otherwise the bean is drawn as an outline.
    static func draw(in cg: CGContext, rect: CGRect, filled: Bool, color: CGColor) {
        let side = min(rect.width, rect.height)
        let a = side * halfLength
        let b = side * halfWidth

        cg.saveGState()
        defer { cg.restoreGState() }
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: tilt)
        cg.setFillColor(color)
        cg.setStrokeColor(color)
        cg.setLineCap(.round)

        let body = CGRect(x: -a, y: -b, width: 2 * a, height: 2 * b)
        let crease = CGMutablePath()
        crease.move(to: CGPoint(x: -creaseEnd * a, y: 0))
        crease.addCurve(
            to: CGPoint(x: creaseEnd * a, y: 0),
            control1: CGPoint(x: -creaseBend.x * a, y: creaseBend.y * b),
            control2: CGPoint(x: creaseBend.x * a, y: -creaseBend.y * b)
        )

        if filled {
            cg.fillEllipse(in: body)
            // Cut the crease out so it shows whatever is behind the bean.
            cg.setBlendMode(.clear)
            cg.setLineWidth(side * creaseWidth)
            cg.addPath(crease)
            cg.strokePath()
        } else {
            let width = side * outlineWidth
            cg.setLineWidth(width)
            cg.strokeEllipse(in: body.insetBy(dx: width / 2, dy: width / 2))
            cg.addPath(crease)
            cg.strokePath()
        }
    }
}
