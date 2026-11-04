import Foundation

public enum ClockStyle {
    /// Whether `locale` formats times on a 24-hour clock. `Locale.autoupdatingCurrent` carries the
    /// macOS 24-hour time setting, so this is how the app follows it.
    public static func uses24Hour(_ locale: Locale) -> Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
        return format.contains("H") || format.contains("k")
    }
}
