// Generates Bean/AppIcon.icon (an Icon Composer document) from the bean mark in
// Bean/BeanGlyph.swift, so the app icon and the menu bar glyph share one drawing.
// SF Symbols may not be used in app icons; the bean is original artwork.
//
// Usage: scripts/make_icon.sh
import AppKit

let canvas: CGFloat = 1024
/// Side of the square the bean is drawn in, centred on the canvas.
let artwork: CGFloat = 700

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
    draw(cg)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make_icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
    }
    try png.write(to: url)
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
          "image-name" : "bean.png",
          "name" : "bean",
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
    FileHandle.standardError.write("usage: make_icon <AppIcon.icon>\n".data(using: .utf8)!)
    exit(64)
}
let iconURL = URL(fileURLWithPath: arguments[1])
let assets = iconURL.appendingPathComponent("Assets")
do {
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    try renderLayer(to: assets.appendingPathComponent("bean.png")) { cg in
        let inset = (canvas - artwork) / 2
        BeanGlyph.draw(
            in: cg,
            rect: CGRect(x: inset, y: inset, width: artwork, height: artwork),
            filled: true,
            color: NSColor.white.cgColor
        )
    }
    try iconJSON.write(to: iconURL.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
    print("Wrote \(iconURL.path)")
} catch {
    FileHandle.standardError.write("make_icon failed: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
