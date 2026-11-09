import SwiftUI
import AppKit

/// Shows the privacy policy inside the app, as guideline 5.1.1(i) requires.
@MainActor
final class PrivacyWindowController: ObservableObject {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Caffeine Privacy Policy"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PrivacyView())
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.bringToFront()
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy Policy").font(.title2.bold())
                Text("Effective October 23, 2026").font(.caption).foregroundStyle(.secondary)

                section("No data collection",
                        "Caffeine does not collect, store, sell or share any personal data. It contains no analytics, advertising or tracking code, and it never connects to the internet.")
                section("What stays on your Mac",
                        "Caffeine saves only your own preferences: which keep-awake options you chose, whether a session is timed, and the number of minutes. They are stored on this Mac inside Caffeine's private app container. Deleting the app removes them.")
                section("How keeping awake works",
                        "When you start a session, Caffeine asks macOS directly to delay sleep. The request ends when you press Stop, when the timer runs out, or when you quit Caffeine.")
                section("Launch at Login",
                        "If you turn on Launch at Login, macOS records that choice in its own Login Items list. You can turn it off in Caffeine or in System Settings at any time.")
                section("Changes",
                        "If this policy ever changes, the new version will ship inside an app update and be published with the source code on the project's GitHub page.")
                section("Open source",
                        "Caffeine is free and open source under the MIT License, so anyone can read exactly what it does.")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 420, height: 360)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body).fixedSize(horizontal: false, vertical: true)
        }
    }
}
