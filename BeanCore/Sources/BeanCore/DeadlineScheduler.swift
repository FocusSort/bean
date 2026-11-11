import Foundation

/// A pending scheduled action that can be cancelled.
public protocol ScheduledDeadline: AnyObject {
    func cancel()
}

/// Schedules a one-shot action at an absolute wall-clock time.
public protocol DeadlineScheduling {
    func schedule(at date: Date, _ action: @escaping @MainActor () -> Void) -> ScheduledDeadline
}

/// Production scheduler: a one-shot `Timer` that fires at an absolute date.
///
/// Firing at a fixed date (instead of decrementing a counter every second)
/// means the end time never drifts. A timer that comes due while the Mac is
/// asleep fires as soon as the run loop resumes after wake, and the app also
/// calls `KeepAwakeSession.checkDeadline()` on wake as a second guard.
public struct RunLoopDeadlineScheduler: DeadlineScheduling {
    public init() {}

    public func schedule(at date: Date, _ action: @escaping @MainActor () -> Void) -> ScheduledDeadline {
        let timer = Timer(fire: date, interval: 0, repeats: false) { _ in
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = 0.5
        // .common so the timer still fires while a menu or the popover is tracking events.
        RunLoop.main.add(timer, forMode: .common)
        return TimerDeadline(timer: timer)
    }

    private final class TimerDeadline: ScheduledDeadline {
        private let timer: Timer
        init(timer: Timer) { self.timer = timer }
        func cancel() { timer.invalidate() }
    }
}
