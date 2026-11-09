import SwiftUI
import AppKit
import CaffeineCore

struct ContentView: View {
    @EnvironmentObject private var session: KeepAwakeSession
    @EnvironmentObject private var loginItems: LoginItemController
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var privacyWindow: PrivacyWindowController

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Caffeine").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(KeepAwakeOption.allCases) { option in
                    Toggle(isOn: Binding(
                        get: { settings.isSelected(option) },
                        set: { settings.setSelected(option, $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(option.title)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(session.isActive)
                }
            }

            Divider()

            Toggle("Run until I stop it", isOn: $settings.isIndefinite)
                .toggleStyle(.checkbox)
                .disabled(session.isActive)

            if !settings.isIndefinite {
                HStack(spacing: 6) {
                    Text("Minutes:")
                    TextField("30", text: $settings.minutesText)
                        .frame(width: 56)
                        .onSubmit(start)
                        .disabled(session.isActive)
                        .accessibilityLabel("Duration in minutes")
                    Text(verbatim: "1–\(DurationInput.maximumMinutes)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(statusText(at: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack {
                if session.isActive {
                    Button("Stop", role: .destructive) { session.stop() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Start", action: start)
                        .keyboardShortcut(.defaultAction)
                        .disabled(settings.selectedOptions.isEmpty)
                }
                Spacer()
            }

            Divider()

            loginItemSection

            Divider()

            HStack {
                Button("Privacy") { privacyWindow.show() }
                    .buttonStyle(.link)
                Spacer()
                Button("Quit Caffeine") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            // The user may have changed Login Items in System Settings since last time.
            loginItems.refresh()
            session.checkDeadline()
            // Accessory apps need this for the Minutes field to get keyboard focus.
            NSApp.bringToFront()
        }
    }

    @ViewBuilder
    private var loginItemSection: some View {
        Toggle("Launch at Login", isOn: Binding(
            get: { loginItems.state == .on || loginItems.state == .needsApproval },
            set: { loginItems.setEnabled($0) }
        ))
        .toggleStyle(.checkbox)

        switch loginItems.state {
        case .needsApproval:
            VStack(alignment: .leading, spacing: 4) {
                Text("Allow Caffeine in System Settings › General › Login Items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open System Settings") { loginItems.openSystemSettings() }
                    .controlSize(.small)
            }
        case .on, .off:
            EmptyView()
        }

        if let message = loginItems.errorMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func start() {
        guard !session.isActive else { return }
        errorMessage = nil
        var minutes: Int?
        if !settings.isIndefinite {
            guard let parsed = DurationInput.minutes(from: settings.minutesText) else {
                errorMessage = DurationInput.rangeDescription
                return
            }
            minutes = parsed
        }
        do {
            try session.start(options: settings.selectedOptions, minutes: minutes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func statusText(at date: Date) -> String {
        guard let remaining = session.remainingSeconds(at: date) else {
            return "Running until you stop it"
        }
        return "Running — \(RemainingTimeFormatter.string(seconds: remaining)) remaining"
    }
}
