import Foundation

/// Validates the "Minutes" field. Whole minutes only, within a sane range,
/// so no input can overflow or produce a zero-length session.
public enum DurationInput {
    public static let minimumMinutes = 1
    /// 24 hours. Longer sessions should use "Run until I stop it".
    public static let maximumMinutes = 24 * 60

    public static var rangeDescription: String {
        "Enter whole minutes from \(minimumMinutes) to \(maximumMinutes)."
    }

    /// Returns the number of minutes, or nil if the text is not a whole number in range.
    public static func minutes(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.allSatisfy({ $0.isASCII && $0.isNumber }),
              trimmed.count <= 4,
              let value = Int(trimmed),
              (minimumMinutes...maximumMinutes).contains(value)
        else { return nil }
        return value
    }
}
