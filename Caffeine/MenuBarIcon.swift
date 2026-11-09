import SwiftUI
import AppKit
import CaffeineCore

/// Menu bar glyph. System symbols are drawn in black and clear (template images),
/// so the menu bar recolours them for light mode, dark mode and the selected state.
struct MenuBarIcon: View {
    @ObservedObject var session: KeepAwakeSession

    var body: some View {
        // The accessibility description is attached to the NSImage itself: SwiftUI's
        // .accessibilityLabel is not carried through to the status item, which
        // otherwise announces the symbol's built-in name.
        Image(nsImage: Self.image(named: symbolName, description: accessibilityText))
            .help(accessibilityText)
    }

    static func image(named name: String, description: String) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
            ?? NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: description)
            ?? NSImage()
        image.isTemplate = true
        return image
    }

    private var symbolName: String {
        guard session.isActive else { return "cup.and.saucer" }
        if #available(macOS 15.0, *) {
            return "cup.and.heat.waves.fill"
        }
        return "cup.and.saucer.fill"
    }

    private var accessibilityText: String {
        session.isActive ? "Caffeine: keeping your Mac awake" : "Caffeine: off"
    }
}
