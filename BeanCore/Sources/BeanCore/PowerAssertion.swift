import Foundation
import IOKit.pwr_mgt
import os

/// A held power assertion. Release it exactly once through the provider that created it.
public struct PowerAssertionToken: Hashable, Sendable {
    public let option: KeepAwakeOption
    public let id: UInt32

    public init(option: KeepAwakeOption, id: UInt32) {
        self.option = option
        self.id = id
    }
}

public struct PowerAssertionError: Error, Equatable, LocalizedError {
    public let option: KeepAwakeOption
    /// The IOReturn code from IOKit.
    public let code: Int32

    public init(option: KeepAwakeOption, code: Int32) {
        self.option = option
        self.code = code
    }

    public var errorDescription: String? {
        "macOS refused the “\(option.title)” keep-awake request (IOReturn \(String(format: "0x%08X", UInt32(bitPattern: code))))."
    }
}

/// Abstraction over IOKit power assertions so session logic can be unit tested.
public protocol PowerAssertionProviding: AnyObject {
    func acquire(_ option: KeepAwakeOption, reason: String) throws -> PowerAssertionToken
    func release(_ token: PowerAssertionToken)
}

/// The real provider. Uses public IOKit power-management APIs, which need no
/// special privileges or entitlements and work inside the App Sandbox.
/// The system also drops every assertion a process holds when that process
/// exits, so a crash or force quit can never leave the Mac stuck awake.
public final class IOKitPowerAssertionProvider: PowerAssertionProviding {
    public init() {}

    public func acquire(_ option: KeepAwakeOption, reason: String) throws -> PowerAssertionToken {
        // AssertionName may be no longer than 128 characters per IOPMLib.h.
        let name = String(reason.prefix(128)) as CFString
        var assertionID = IOPMAssertionID(0)
        let result: IOReturn

        switch option {
        case .userActive:
            result = IOPMAssertionDeclareUserActivity(name, kIOPMUserActiveLocal, &assertionID)
        default:
            result = IOPMAssertionCreateWithName(
                Self.assertionType(for: option),
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                name,
                &assertionID
            )
        }

        guard result == kIOReturnSuccess else {
            throw PowerAssertionError(option: option, code: result)
        }
        return PowerAssertionToken(option: option, id: assertionID)
    }

    public func release(_ token: PowerAssertionToken) {
        let result = IOPMAssertionRelease(IOPMAssertionID(token.id))
        guard result != kIOReturnSuccess else { return }
        // The assertion no longer exists. This is expected for user-activity assertions,
        // which macOS expires on its own, and leaves nothing to clean up. It is logged,
        // never fatal: an assert here crashed a Debug build on Stop after a long session.
        Self.logger.notice("""
            Power assertion \(token.id, privacy: .public) (\(token.option.rawValue, privacy: .public)) \
            was already released by the system (IOReturn \(result, privacy: .public)).
            """)
    }

    private static let logger = Logger(subsystem: "com.scottjones.bean", category: "power-assertions")

    static func assertionType(for option: KeepAwakeOption) -> CFString {
        switch option {
        case .display: return kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        case .idleSystem: return kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        case .disk: return kIOPMAssertPreventDiskIdle as CFString
        case .systemOnAC: return kIOPMAssertionTypePreventSystemSleep as CFString
        case .userActive: return kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString // unused: handled above
        }
    }
}
