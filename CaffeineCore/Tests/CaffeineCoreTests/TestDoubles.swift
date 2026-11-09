import Foundation
import ServiceManagement
@testable import CaffeineCore

/// Records every acquire/release so tests can assert nothing leaks.
final class FakePowerAssertionProvider: PowerAssertionProviding {
    private(set) var held: [PowerAssertionToken] = []
    private(set) var releaseLog: [PowerAssertionToken] = []
    private(set) var acquireLog: [KeepAwakeOption] = []
    var failingOption: KeepAwakeOption?
    private var nextID: UInt32 = 100

    func acquire(_ option: KeepAwakeOption, reason: String) throws -> PowerAssertionToken {
        acquireLog.append(option)
        if option == failingOption {
            throw PowerAssertionError(option: option, code: -536870212) // kIOReturnError
        }
        nextID += 1
        let token = PowerAssertionToken(option: option, id: nextID)
        held.append(token)
        return token
    }

    func release(_ token: PowerAssertionToken) {
        releaseLog.append(token)
        held.removeAll { $0 == token }
    }
}

/// Lets tests move time forward and fire scheduled deadlines on demand.
@MainActor
final class ManualClock {
    var current: Date
    init(_ start: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) { current = start }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

final class FakeScheduler: DeadlineScheduling {
    final class Entry: ScheduledDeadline {
        let date: Date
        let action: @MainActor () -> Void
        private(set) var isCancelled = false
        init(date: Date, action: @escaping @MainActor () -> Void) { self.date = date; self.action = action }
        func cancel() { isCancelled = true }
    }

    private(set) var entries: [Entry] = []
    var live: [Entry] { entries.filter { !$0.isCancelled } }

    func schedule(at date: Date, _ action: @escaping @MainActor () -> Void) -> ScheduledDeadline {
        let entry = Entry(date: date, action: action)
        entries.append(entry)
        return entry
    }

    /// Fires every live entry due at or before `date`, as a run loop would.
    @MainActor func fireDue(at date: Date) {
        for entry in live where entry.date <= date { entry.action() }
    }
}

final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var statusAfterRegister: SMAppService.Status = .enabled
    var registerError: Error?
    var unregisterError: Error?
    private(set) var openedSettings = false

    func register() throws {
        if let registerError { throw registerError }
        status = statusAfterRegister
    }

    func unregister() throws {
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }

    func openSystemSettingsLoginItems() { openedSettings = true }
}

struct FakeError: LocalizedError {
    var errorDescription: String? { "Operation not permitted" }
}
