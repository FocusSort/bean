import XCTest
@testable import CaffeineCore

@MainActor
final class KeepAwakeSessionTests: XCTestCase {
    private var provider: FakePowerAssertionProvider!
    private var scheduler: FakeScheduler!
    private var clock: ManualClock!
    private var session: KeepAwakeSession!

    override func setUp() async throws {
        provider = FakePowerAssertionProvider()
        scheduler = FakeScheduler()
        clock = ManualClock()
        let clock = clock!
        session = KeepAwakeSession(provider: provider, scheduler: scheduler, now: { clock.current })
    }

    // MARK: Start and stop

    func testStartTakesOneAssertionPerOption() throws {
        try session.start(options: [.display, .idleSystem], minutes: nil)
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(Set(provider.held.map(\.option)), [.display, .idleSystem])
        XCTAssertEqual(session.activeOptions, [.display, .idleSystem])
    }

    func testAllFiveOptionsCanBeHeldTogether() throws {
        try session.start(options: Set(KeepAwakeOption.allCases), minutes: nil)
        XCTAssertEqual(provider.held.count, 5)
        session.stop()
        XCTAssertTrue(provider.held.isEmpty)
    }

    func testStopReleasesEveryAssertion() throws {
        try session.start(options: [.display, .disk, .userActive], minutes: 10)
        session.stop()
        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(provider.held.isEmpty)
        XCTAssertEqual(provider.releaseLog.count, 3)
        XCTAssertTrue(scheduler.live.isEmpty, "Stop must cancel the pending deadline")
    }

    func testStopWhenIdleIsHarmless() {
        session.stop()
        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(provider.releaseLog.isEmpty)
    }

    func testStopTwiceReleasesOnlyOnce() throws {
        try session.start(options: [.display], minutes: nil)
        session.stop()
        session.stop()
        XCTAssertEqual(provider.releaseLog.count, 1)
    }

    func testSecondStartWhileActiveIsRejectedAndTakesNothing() throws {
        try session.start(options: [.display], minutes: nil)
        XCTAssertThrowsError(try session.start(options: [.disk], minutes: nil)) {
            XCTAssertEqual($0 as? KeepAwakeStartError, .alreadyActive)
        }
        XCTAssertEqual(provider.held.map(\.option), [.display])
    }

    func testStartWithNoOptionsIsRejected() {
        XCTAssertThrowsError(try session.start(options: [], minutes: nil)) {
            XCTAssertEqual($0 as? KeepAwakeStartError, .noOptionsSelected)
        }
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(provider.acquireLog.isEmpty)
    }

    func testOutOfRangeDurationIsRejected() {
        for bad in [0, -5, DurationInput.maximumMinutes + 1] {
            XCTAssertThrowsError(try session.start(options: [.display], minutes: bad)) {
                XCTAssertEqual($0 as? KeepAwakeStartError, .invalidDuration)
            }
        }
        XCTAssertTrue(provider.acquireLog.isEmpty)
    }

    func testPartialAssertionFailureRollsBackEverything() {
        provider.failingOption = .disk
        XCTAssertThrowsError(try session.start(options: [.display, .idleSystem, .disk], minutes: 5)) { error in
            guard case .assertionFailed(let underlying)? = error as? KeepAwakeStartError else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(underlying.option, .disk)
        }
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(provider.held.isEmpty, "Assertions taken before the failure must be released")
        XCTAssertTrue(scheduler.entries.isEmpty, "No deadline should be scheduled for a failed start")
    }

    // MARK: Timer

    func testIndefiniteSessionHasNoDeadline() throws {
        try session.start(options: [.display], minutes: nil)
        XCTAssertNil(session.endsAt)
        XCTAssertNil(session.remainingSeconds())
        XCTAssertTrue(scheduler.entries.isEmpty)
        clock.advance(by: 7 * 24 * 3600)
        session.checkDeadline()
        XCTAssertTrue(session.isActive, "An indefinite session only ends on Stop or quit")
    }

    func testTimedSessionSchedulesAbsoluteDeadline() throws {
        let start = clock.current
        try session.start(options: [.display], minutes: 30)
        XCTAssertEqual(session.endsAt, start.addingTimeInterval(1800))
        XCTAssertEqual(scheduler.live.single?.date, start.addingTimeInterval(1800))
    }

    func testRemainingSecondsIsComputedFromDeadlineNotACounter() throws {
        try session.start(options: [.display], minutes: 2)
        XCTAssertEqual(session.remainingSeconds(), 120)
        clock.advance(by: 0.4)
        XCTAssertEqual(session.remainingSeconds(), 120, "Rounds up so the display never shows 0 early")
        clock.advance(by: 59.6)
        XCTAssertEqual(session.remainingSeconds(), 60)
        // A UI that skipped many refreshes still shows the true value.
        clock.advance(by: 45)
        XCTAssertEqual(session.remainingSeconds(), 15)
    }

    func testDeadlineFiringEndsSessionAndReleasesAssertions() throws {
        try session.start(options: [.display, .idleSystem], minutes: 1)
        clock.advance(by: 60)
        scheduler.fireDue(at: clock.current)
        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(provider.held.isEmpty)
    }

    func testEarlyTimerFireDoesNotEndSession() throws {
        try session.start(options: [.display], minutes: 1)
        clock.advance(by: 59)
        session.checkDeadline()
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(provider.held.count, 1)
    }

    func testWakeAfterDeadlinePassedDuringSleepEndsSession() throws {
        try session.start(options: [.display], minutes: 15)
        // The Mac sleeps (lid closed) for two hours; no timer fires meanwhile.
        clock.advance(by: 2 * 3600)
        // On wake, the app calls checkDeadline().
        session.checkDeadline()
        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(provider.held.isEmpty)
        XCTAssertEqual(session.remainingSeconds(), nil)
    }

    func testWakeBeforeDeadlineKeepsSessionWithCorrectRemainingTime() throws {
        try session.start(options: [.display], minutes: 60)
        clock.advance(by: 20 * 60) // slept 20 minutes
        session.checkDeadline()
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.remainingSeconds(), 40 * 60)
    }

    func testStaleDeadlineFromEarlierSessionCannotStopNewSession() throws {
        try session.start(options: [.display], minutes: 1)
        session.stop()
        try session.start(options: [.display], minutes: 10)
        clock.advance(by: 60)
        // The first session's timer was cancelled; even if a stale callback ran,
        // checkDeadline compares against the *current* deadline.
        scheduler.entries.first?.action()
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(scheduler.entries.first?.isCancelled, true)
    }

    // MARK: Quit

    func testShutdownReleasesAssertionsAndCancelsTimer() throws {
        try session.start(options: Set(KeepAwakeOption.allCases), minutes: 30)
        session.shutdown()
        XCTAssertTrue(provider.held.isEmpty)
        XCTAssertTrue(scheduler.live.isEmpty)
        XCTAssertEqual(session.state, .idle)
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
