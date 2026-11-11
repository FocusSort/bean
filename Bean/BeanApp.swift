import SwiftUI
import BeanCore

@main
struct BeanApp: App {
    // The delegate owns every long-lived object, so quitting always reaches the
    // session even if the popover was never opened.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appDelegate.session)
                .environmentObject(appDelegate.loginItems)
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.privacyWindow)
        } label: {
            MenuBarIcon(session: appDelegate.session)
        }
        .menuBarExtraStyle(.window)
    }
}
