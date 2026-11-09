// Generates Caffeine/AppIcon.icon (an Icon Composer document) from original
// vector artwork. SF Symbols may not be used in app icons, so the cup and steam
// here are drawn from scratch.
//
// Usage: swift scripts/make_icon.swift <path-to-AppIcon.icon>
import AppKit

let canvas: CGFloat = 1024

func renderLayer(to url: URL, draw: (CGContext) -> Void) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "make_icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap"])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))
    cg.setFillColor(NSColor.white.cgColor)
    cg.setStrokeColor(NSColor.white.cgColor)
    draw(cg)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make_icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
    }
    try png.write(to: url)
}

/// Cup, handle and saucer. Coordinates have their origin at the bottom left.
func drawCup(_ cg: CGContext) {
    let cupCenterX: CGFloat = 470
    let bodyBottom: CGFloat = 330, bodyTop: CGFloat = 620
    let topHalfWidth: CGFloat = 215, bottomHalfWidth: CGFloat = 165

    // Body: a tapered bowl with a rounded base.
    let body = CGMutablePath()
    body.move(to: CGPoint(x: cupCenterX - topHalfWidth, y: bodyTop))
    body.addLine(to: CGPoint(x: cupCenterX + topHalfWidth, y: bodyTop))
    body.addCurve(
        to: CGPoint(x: cupCenterX + bottomHalfWidth - 40, y: bodyBottom),
        control1: CGPoint(x: cupCenterX + topHalfWidth - 5, y: bodyBottom + 130),
        control2: CGPoint(x: cupCenterX + bottomHalfWidth + 10, y: bodyBottom)
    )
    body.addLine(to: CGPoint(x: cupCenterX - bottomHalfWidth + 40, y: bodyBottom))
    body.addCurve(
        to: CGPoint(x: cupCenterX - topHalfWidth, y: bodyTop),
        control1: CGPoint(x: cupCenterX - bottomHalfWidth - 10, y: bodyBottom),
        control2: CGPoint(x: cupCenterX - topHalfWidth + 5, y: bodyBottom + 130)
    )
    body.closeSubpath()
    cg.addPath(body)
    cg.fillPath()

    // Handle: a thick ring on the right, drawn as a stroked arc.
    cg.setLineWidth(46)
    cg.setLineCap(.round)
    cg.addArc(center: CGPoint(x: cupCenterX + 222, y: 505), radius: 72,
              startAngle: .pi * 0.62, endAngle: -.pi * 0.55, clockwise: true)
    cg.strokePath()

    // Saucer: a wide, flat rounded plate under the cup.
    let saucer = CGPath(
        roundedRect: CGRect(x: 512 - 320, y: 262, width: 640, height: 58),
        cornerWidth: 29, cornerHeight: 29, transform: nil
    )
    cg.addPath(saucer)
    cg.fillPath()
}

/// Three rising wisps of steam.
func drawSteam(_ cg: CGContext) {
    cg.setLineWidth(38)
    cg.setLineCap(.round)
    for x in [CGFloat(385), 470, 555] {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: 672))
        path.addCurve(to: CGPoint(x: x, y: 842),
                      control1: CGPoint(x: x + 52, y: 728),
                      control2: CGPoint(x: x - 52, y: 786))
        cg.addPath(path)
    }
    cg.strokePath()
}

let iconJSON = """
{
  "fill" : {
    "automatic-gradient" : "extended-srgb:0.72157,0.38431,0.16863,1.00000"
  },
  "groups" : [
    {
      "layers" : [
        {
          "glass" : true,
          "hidden" : false,
          "image-name" : "steam.png",
          "name" : "steam",
          "position" : { "scale" : 1, "translation-in-points" : [ 0, 0 ] }
        },
        {
          "glass" : true,
          "hidden" : false,
          "image-name" : "cup.png",
          "name" : "cup",
          "position" : { "scale" : 1, "translation-in-points" : [ 0, 0 ] }
        }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.4 }
    }
  ],
  "supported-platforms" : {
    "squares" : [ "macOS" ]
  }
}
"""

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("usage: swift make_icon.swift <AppIcon.icon>\n".data(using: .utf8)!)
    exit(64)
}
let iconURL = URL(fileURLWithPath: arguments[1])
let assets = iconURL.appendingPathComponent("Assets")
do {
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    try renderLayer(to: assets.appendingPathComponent("cup.png"), draw: drawCup)
    try renderLayer(to: assets.appendingPathComponent("steam.png"), draw: drawSteam)
    try iconJSON.write(to: iconURL.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
    print("Wrote \(iconURL.path)")
} catch {
    FileHandle.standardError.write("make_icon failed: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
