import Foundation

/// One independent way of keeping the Mac awake. Each case maps to an IOKit
/// power assertion, mirroring the caffeinate(8) flag the app used to pass.
public enum KeepAwakeOption: String, CaseIterable, Identifiable, Codable, Sendable {
    /// caffeinate -d
    case display
    /// caffeinate -i
    case idleSystem
    /// caffeinate -m
    case disk
    /// caffeinate -s (only honoured by the system while on AC power)
    case systemOnAC
    /// caffeinate -u
    case userActive

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .display: return "Display"
        case .idleSystem: return "Idle"
        case .disk: return "Disk"
        case .systemOnAC: return "System (AC)"
        case .userActive: return "User active"
        }
    }

    public var subtitle: String {
        switch self {
        case .display: return "Keep the display awake"
        case .idleSystem: return "Prevent idle sleep"
        case .disk: return "Prevent disk sleep"
        case .systemOnAC: return "Prevent sleep on AC power"
        case .userActive: return "Declare the user is active"
        }
    }

    /// The options a first launch starts with (caffeinate -d -i).
    public static let defaultSelection: Set<KeepAwakeOption> = [.display, .idleSystem]

    /// Maps the single-character flag IDs stored by version 1.0 builds
    /// ("d", "i", "m", "s", "u") so existing settings survive the upgrade.
    public init?(legacyFlag: Character) {
        switch legacyFlag {
        case "d": self = .display
        case "i": self = .idleSystem
        case "m": self = .disk
        case "s": self = .systemOnAC
        case "u": self = .userActive
        default: return nil
        }
    }
}
