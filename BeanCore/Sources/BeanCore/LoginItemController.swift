import Foundation
import ServiceManagement

/// What the Launch at Login control should show. Always derived from the
/// live system status, never cached across reads.
public enum LoginItemState: Equatable {
    case off
    case on
    /// Registered, but the user must allow it in System Settings › Login Items.
    case needsApproval
}

/// Abstraction over `SMAppService.mainApp` for testing.
public protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

public struct MainAppLoginItemService: LoginItemService {
    public init() {}
    public var status: SMAppService.Status { SMAppService.mainApp.status }
    public func register() throws { try SMAppService.mainApp.register() }
    public func unregister() throws { try SMAppService.mainApp.unregister() }
    public func openSystemSettingsLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
public final class LoginItemController: ObservableObject {
    @Published public private(set) var state: LoginItemState = .off
    @Published public private(set) var errorMessage: String?

    private let service: LoginItemService

    public init(service: LoginItemService = MainAppLoginItemService()) {
        self.service = service
        refresh()
    }

    public static func state(for status: SMAppService.Status) -> LoginItemState {
        switch status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        case .notRegistered: return .off
        // Observed on macOS 27 for a fresh copy that has never been registered:
        // mainApp reports .notFound rather than .notRegistered. Treat it as off;
        // if registering then fails, setEnabled(_:) surfaces the real error.
        case .notFound: return .off
        @unknown default: return .off
        }
    }

    /// Re-reads the system status. Call whenever the UI becomes visible, because
    /// the user can change login items in System Settings at any time.
    public func refresh() {
        state = Self.state(for: service.status)
    }

    /// Registers or unregisters only in response to the user's choice.
    public func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = enabled
                ? "Couldn't turn on Launch at Login: \(error.localizedDescription)"
                : "Couldn't turn off Launch at Login: \(error.localizedDescription)"
        }
        refresh()
    }

    public func openSystemSettings() {
        service.openSystemSettingsLoginItems()
    }
}
