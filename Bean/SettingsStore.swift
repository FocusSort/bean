import Foundation
import BeanCore

/// The user's choices, saved as they change. Stored only in this app's own
/// UserDefaults domain inside its sandbox container (privacy reason CA92.1).
@MainActor
final class SettingsStore: ObservableObject {
    @Published var selectedOptions: Set<KeepAwakeOption> {
        didSet { defaults.set(selectedOptions.map(\.rawValue).sorted(), forKey: Key.options) }
    }
    @Published var isIndefinite: Bool {
        didSet { defaults.set(isIndefinite, forKey: Key.indefinite) }
    }
    @Published var minutesText: String {
        didSet { defaults.set(minutesText, forKey: Key.minutes) }
    }

    private let defaults: UserDefaults

    private enum Key {
        static let options = "bean.options"
        static let indefinite = "bean.isIndefinite"
        static let minutes = "bean.durationMinutes"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let stored = defaults.array(forKey: Key.options) as? [String] {
            selectedOptions = Set(stored.compactMap(KeepAwakeOption.init(rawValue:)))
        } else {
            selectedOptions = KeepAwakeOption.defaultSelection
        }
        isIndefinite = defaults.object(forKey: Key.indefinite) as? Bool ?? true
        minutesText = defaults.string(forKey: Key.minutes) ?? "30"
    }

    func isSelected(_ option: KeepAwakeOption) -> Bool {
        selectedOptions.contains(option)
    }

    func setSelected(_ option: KeepAwakeOption, _ selected: Bool) {
        if selected {
            selectedOptions.insert(option)
        } else {
            selectedOptions.remove(option)
        }
    }
}
