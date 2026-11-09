import AppKit
import CaffeineCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let session: KeepAwakeSession
    let loginItems: LoginItemController
    let settings: SettingsStore
    let privacyWindow: PrivacyWindowController

    private var wakeObserver: NSObjectProtocol?

    override init() {
        session = KeepAwakeSession()
        loginItems = LoginItemController()
        settings = SettingsStore()
        privacyWindow = PrivacyWindowController()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = Self.otherRunningInstance() {
            // Second launch: hand over to the copy that is already in the menu bar.
            other.activate()
            NSApp.terminate(nil)
            return
        }

        // LSUIElement already hides the Dock icon; this keeps debug runs consistent.
        NSApp.setActivationPolicy(.accessory)

        // A timed session whose end time passed while the Mac slept ends on wake.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.session.checkDeadline() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Release assertions explicitly. The system would also drop them when the
        // process exits, but an explicit release is immediate and visible in pmset.
        session.shutdown()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    /// Another copy of this app (same bundle ID) that is already running, if any.
    static func otherRunningInstance() -> NSRunningApplication? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let current = NSRunningApplication.current
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first { $0.processIdentifier != current.processIdentifier && !$0.isTerminated }
    }
}

extension NSApplication {
    /// `activate(ignoringOtherApps:)` is deprecated from macOS 14.
    func bringToFront() {
        if #available(macOS 14.0, *) {
            activate()
        } else {
            activate(ignoringOtherApps: true)
        }
    }
}
