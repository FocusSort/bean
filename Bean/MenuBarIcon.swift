import SwiftUI
import AppKit
import BeanCore

/// Menu bar glyph: an outline bean when idle, a solid bean while keeping the
/// Mac awake. It is a template image (black and clear), so the menu bar
/// recolours it for light mode, dark mode and the selected state.
struct MenuBarIcon: View {
    @ObservedObject var session: KeepAwakeSession

    var body: some View {
        // The accessibility description is attached to the NSImage itself: SwiftUI's
        // .accessibilityLabel is not carried through to the status item.
        Image(nsImage: Self.image(active: session.isActive, description: accessibilityText))
            .help(accessibilityText)
    }

    static func image(active: Bool, description: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            BeanGlyph.draw(in: context, rect: rect, filled: active, color: CGColor(gray: 0, alpha: 1))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }

    private var accessibilityText: String {
        session.isActive ? "Bean: keeping your Mac awake" : "Bean: off"
    }
}
