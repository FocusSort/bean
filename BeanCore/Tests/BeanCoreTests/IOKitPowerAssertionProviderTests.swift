import XCTest
import IOKit.pwr_mgt
@testable import BeanCore

/// Integration tests against the real power-management system. They take and
/// release short-lived assertions held by the test process itself; nothing
/// outlives the test run, because the system drops a process's assertions on exit.
final class IOKitPowerAssertionProviderTests: XCTestCase {
    private let provider = IOKitPowerAssertionProvider()
    private let reason = "BeanCoreTests \(UUID().uuidString.prefix(8))"

    /// Names of the assertions this process currently holds, by assertion type.
    private func heldAssertions() -> [(type: String, name: String)] {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byProcess = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return [] }
        let mine = byProcess[NSNumber(value: getpid())] ?? []
        return mine.compactMap { entry in
            guard let type = entry[kIOPMAssertionTypeKey] as? String,
                  let name = entry[kIOPMAssertionNameKey] as? String else { return nil }
            return (type, name)
        }
    }

    func testEachSleepOptionCreatesTheMatchingAssertionType() throws {
        let expected: [KeepAwakeOption: String] = [
            .display: kIOPMAssertionTypePreventUserIdleDisplaySleep,
            .idleSystem: kIOPMAssertionTypePreventUserIdleSystemSleep,
            .disk: kIOPMAssertPreventDiskIdle,
            .systemOnAC: kIOPMAssertionTypePreventSystemSleep,
        ]
        for (option, type) in expected {
            let token = try provider.acquire(option, reason: reason)
            XCTAssertNotEqual(token.id, 0)
            XCTAssertTrue(
                heldAssertions().contains { $0.type == type && $0.name == reason },
                "\(option) should hold a \(type) assertion named \(reason)"
            )
            provider.release(token)
            XCTAssertFalse(
                heldAssertions().contains { $0.type == type && $0.name == reason },
                "\(option) assertion should be gone after release"
            )
        }
    }

    func testUserActiveDeclaresActivityAndReleases() throws {
        let token = try provider.acquire(.userActive, reason: reason)
        XCTAssertEqual(token.option, .userActive)
        XCTAssertNotEqual(token.id, 0)
        provider.release(token)
    }

    func testFullSessionLeavesNoAssertionsBehind() throws {
        let session = MainActor.assumeIsolated { KeepAwakeSession(provider: provider) }
        try MainActor.assumeIsolated {
            try session.start(options: [.display, .idleSystem, .disk, .systemOnAC], minutes: 5)
        }
        let name = MainActor.assumeIsolated { KeepAwakeSession.assertionReason }
        XCTAssertEqual(heldAssertions().filter { $0.name == name }.count, 4)
        MainActor.assumeIsolated { session.stop() }
        XCTAssertTrue(heldAssertions().filter { $0.name == name }.isEmpty)
    }

    /// Regression: a 1.0 Debug build crashed on Stop after a five-day session because
    /// IOPMAssertionRelease failed for an assertion macOS had already dropped (user-activity
    /// assertions expire on their own). Releasing an assertion that no longer exists must be harmless.
    func testReleasingAnAssertionThatNoLongerExistsDoesNotCrash() throws {
        let token = try provider.acquire(.display, reason: reason)
        provider.release(token)
        provider.release(token) // already gone: IOKit returns an error, which must not trap
        let userActivity = try provider.acquire(.userActive, reason: reason)
        provider.release(userActivity)
        provider.release(userActivity)
    }

    func testOverlongReasonIsTruncatedNotRejected() throws {
        let token = try provider.acquire(.display, reason: String(repeating: "x", count: 300))
        provider.release(token)
    }
}
