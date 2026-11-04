import Foundation

public struct MenuBarSettings: Sendable, Equatable {
    // The app saves these raw values in its settings, so they must stay the same.
    public enum Content: String, Sendable, CaseIterable { case timeAndTitle, timeOnly, iconOnly }
    public enum Scroll: String, Sendable, CaseIterable { case always, nearMeetings, never }

    public var content: Content
    /// Characters of the title shown at once, counted as Swift `Character`s (grapheme clusters), not display width; longer titles may scroll.
    public var titleLength: Int
    public var scroll: Scroll
    /// Mirrors the macOS 24-hour time setting. The app reads it from the system and passes it in.
    public var uses24HourClock: Bool

    public init(
        content: Content = .timeAndTitle,
        titleLength: Int = 10,
        scroll: Scroll = .nearMeetings,
        uses24HourClock: Bool = false
    ) {
        self.content = content
        self.titleLength = titleLength
        self.scroll = scroll
        self.uses24HourClock = uses24HourClock
    }
}

public struct MenuBarDisplay: Equatable, Sendable {
    public enum Icon: Sendable { case calendar, live, quiet, doneForToday }

    public let icon: Icon
    public let time: String?
    public let title: String?
    public let scrollsTitle: Bool

    public init(icon: Icon, time: String?, title: String?, scrollsTitle: Bool) {
        self.icon = icon
        self.time = time
        self.title = title
        self.scrollsTitle = scrollsTitle
    }
}

public enum MenuBarText {
    private static let hour: TimeInterval = 3600

    /// The meeting the menu bar is about: the dropdown, Join, and Add a topic act on it too.
    /// When several meetings are live, the one that started most recently wins, then the one ending sooner, then the title.
    /// Otherwise the earliest meeting that starts later today or within the next hour, then by title.
    /// All-day events are skipped.
    public static func featured(in meetings: [Meeting], now: Date, calendar: Calendar) -> Meeting? {
        let timed = meetings.filter { !$0.isAllDay }
        let current = timed
            .filter { $0.start <= now && now < $0.end }
            .min { ($1.start, $0.end, $0.title) < ($0.start, $1.end, $1.title) }
        if current != nil { return current }
        return timed
            .filter {
                $0.start > now
                    && (calendar.isDate($0.start, inSameDayAs: now) || $0.start.timeIntervalSince(now) <= hour)
            }
            .min { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// What the menu bar item shows at `now`. `meetings` comes from `MeetingFilter.relevant`.
    /// Quiet mode shows the moon except during a live meeting.
    public static func display(
        meetings: [Meeting],
        now: Date,
        quiet: Bool,
        settings: MenuBarSettings,
        calendar: Calendar
    ) -> MenuBarDisplay {
        guard let meeting = featured(in: meetings, now: now, calendar: calendar) else {
            return MenuBarDisplay(icon: quiet ? .quiet : .doneForToday, time: nil, title: nil, scrollsTitle: false)
        }

        let isLive = meeting.start <= now
        let untilStart = meeting.start.timeIntervalSince(now)
        let withinHour = !isLive && untilStart <= hour

        let time: String
        if isLive {
            time = "\(shortDuration(minutes: minutesRoundedUp(meeting.end.timeIntervalSince(now)))) left"
        } else if withinHour {
            time = "in \(minutesRoundedUp(untilStart))m"
        } else {
            time = clockTime(meeting.start, calendar: calendar, uses24Hour: settings.uses24HourClock)
        }
        let icon: MenuBarDisplay.Icon = isLive ? .live : (quiet ? .quiet : .calendar)

        switch settings.content {
        case .iconOnly:
            return MenuBarDisplay(icon: icon, time: nil, title: nil, scrollsTitle: false)
        case .timeOnly:
            return MenuBarDisplay(icon: icon, time: time, title: nil, scrollsTitle: false)
        case .timeAndTitle:
            let tooLong = meeting.title.count > settings.titleLength
            let scrolls = tooLong && (settings.scroll == .always
                || (settings.scroll == .nearMeetings && (isLive || withinHour)))
            return MenuBarDisplay(icon: icon, time: time, title: meeting.title, scrollsTitle: scrolls)
        }
    }

    static func minutesRoundedUp(_ interval: TimeInterval) -> Int {
        max(1, Int((interval / 60).rounded(.up)))
    }

    /// "45m", "2h" or "1h 20m".
    static func shortDuration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    /// "45 min", "2 hr" or "1 hr 20 min".
    static func longDuration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(minutes % 60) min"
    }

    /// The dropdown's time line: "2:30 – 3:00 PM", plus "in 24 min" within the hour or "12 min left" during the meeting.
    /// `meeting` is a timed meeting; `featured` never returns all-day events.
    public static func detail(for meeting: Meeting, now: Date, calendar: Calendar, uses24Hour: Bool) -> String {
        let range = timeRange(meeting.start, meeting.end, calendar: calendar, uses24Hour: uses24Hour)
        if meeting.start <= now && now < meeting.end {
            return "\(range) · \(longDuration(minutes: minutesRoundedUp(meeting.end.timeIntervalSince(now)))) left"
        }
        let untilStart = meeting.start.timeIntervalSince(now)
        if untilStart > 0 && untilStart <= hour {
            return "\(range) · in \(minutesRoundedUp(untilStart)) min"
        }
        return range
    }

    /// "2:30 – 3:00 PM", "11:30 AM – 12:30 PM", or "14:30 – 15:00".
    public static func timeRange(_ start: Date, _ end: Date, calendar: Calendar, uses24Hour: Bool) -> String {
        let from = clockTime(start, calendar: calendar, uses24Hour: uses24Hour)
        let to = clockTime(end, calendar: calendar, uses24Hour: uses24Hour)
        if !uses24Hour && from.suffix(2) == to.suffix(2) {
            return "\(from.dropLast(3)) – \(to)"
        }
        return "\(from) – \(to)"
    }

    /// "2:30 PM" or "14:30". The 12-hour form uses English AM/PM regardless of locale.
    public static func clockTime(_ date: Date, calendar: Calendar, uses24Hour: Bool) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        if uses24Hour {
            return String(format: "%02d:%02d", hour, minute)
        }
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", hour12, minute, hour < 12 ? "AM" : "PM")
    }
}
