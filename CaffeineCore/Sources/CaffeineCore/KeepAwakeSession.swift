import Foundation
import Combine

/// Why a session could not start.
public enum KeepAwakeStartError: Error, Equatable, LocalizedError {
    case alreadyActive
    case noOptionsSelected
    case invalidDuration
    case assertionFailed(PowerAssertionError)

    public var errorDescription: String? {
        switch self {
        case .alreadyActive: return "Caffeine is already running."
        case .noOptionsSelected: return "Choose at least one option to keep awake."
        case .invalidDuration: return DurationInput.rangeDescription
        case .assertionFailed(let error): return error.errorDescription
        }
    }
}

/// Owns the power assertions for one keep-awake session and ends the session
/// on Stop, at its deadline, after wake if the deadline passed while asleep,
/// and on quit. All state lives on the main actor.
@MainActor
public final class KeepAwakeSession: ObservableObject {
    public enum State: Equatable {
        case idle
        /// `endsAt` is nil for "Run until I stop it".
        case active(endsAt: Date?)
    }

    @Published public private(set) var state: State = .idle

    /// Assertion name shown by `pmset -g assertions`.
    public static let assertionReason = "Caffeine menu bar app: keep-awake session"

    private let provider: PowerAssertionProviding
    private let scheduler: DeadlineScheduling
    private let now: () -> Date
    private var tokens: [PowerAssertionToken] = []
    private var pendingDeadline: ScheduledDeadline?

    public init(
        provider: PowerAssertionProviding = IOKitPowerAssertionProvider(),
        scheduler: DeadlineScheduling = RunLoopDeadlineScheduler(),
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.scheduler = scheduler
        self.now = now
    }

    public var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    public var endsAt: Date? {
        if case .active(let endsAt) = state { return endsAt }
        return nil
    }

    /// The options whose assertions are currently held.
    public var activeOptions: Set<KeepAwakeOption> { Set(tokens.map(\.option)) }

    /// Seconds left in a timed session, rounded up, or nil if idle or indefinite.
    public func remainingSeconds(at date: Date? = nil) -> Int? {
        guard let endsAt else { return nil }
        let remaining = endsAt.timeIntervalSince(date ?? now())
        return max(0, Int(remaining.rounded(.up)))
    }

    /// Starts a session. `minutes` nil means run until stopped.
    /// Either every requested assertion is taken, or none is (all-or-nothing).
    public func start(options: Set<KeepAwakeOption>, minutes: Int?) throws {
        guard !isActive else { throw KeepAwakeStartError.alreadyActive }
        guard !options.isEmpty else { throw KeepAwakeStartError.noOptionsSelected }
        if let minutes, !(DurationInput.minimumMinutes...DurationInput.maximumMinutes).contains(minutes) {
            throw KeepAwakeStartError.invalidDuration
        }

        var acquired: [PowerAssertionToken] = []
        // Stable order so behaviour and tests are deterministic.
        for option in KeepAwakeOption.allCases where options.contains(option) {
            do {
                acquired.append(try provider.acquire(option, reason: Self.assertionReason))
            } catch {
                // Roll back so a partial failure never leaves assertions held.
                acquired.forEach(provider.release)
                if let assertionError = error as? PowerAssertionError {
                    throw KeepAwakeStartError.assertionFailed(assertionError)
                }
                throw error
            }
        }
        tokens = acquired

        let endsAt = minutes.map { now().addingTimeInterval(TimeInterval($0) * 60) }
        state = .active(endsAt: endsAt)

        if let endsAt {
            pendingDeadline = scheduler.schedule(at: endsAt) { [weak self] in
                self?.checkDeadline()
            }
        }
    }

    /// Ends the session and releases every assertion. Safe to call when idle.
    public func stop() {
        pendingDeadline?.cancel()
        pendingDeadline = nil
        let held = tokens
        tokens = []
        held.forEach(provider.release)
        state = .idle
    }

    /// Ends a timed session whose deadline has passed. Called by the scheduled
    /// timer, after the Mac wakes, and whenever the UI refreshes.
    public func checkDeadline() {
        guard let endsAt, now() >= endsAt else { return }
        stop()
    }

    /// Called when the app terminates.
    public func shutdown() {
        stop()
    }
}
