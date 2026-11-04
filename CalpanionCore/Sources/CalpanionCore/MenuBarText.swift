import Foundation

public struct MenuBarSettings: Sendable, Equatable {
    public enum Content: Sendable { case timeAndTitle, timeOnly, iconOnly }
    public enum Scroll: Sendable { case always, nearMeetings, never }

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
    /// What the menu bar item shows at `now`. `meetings` should already be
    /// filtered to visible calendars; all-day events are skipped here.
    /// When several meetings are live, the one that started most recently wins, then the one ending sooner, then the title.
    /// The next meeting shows if it starts later today or within the next hour.
    public static func display(
        meetings: [Meeting],
        now: Date,
        quiet: Bool,
        settings: MenuBarSettings,
        calendar: Calendar
    ) -> MenuBarDisplay {
        let timed = meetings.filter { !$0.isAllDay }
        let current = timed
            .filter { $0.start <= now && now < $0.end }
            .min { ($1.start, $0.end, $0.title) < ($0.start, $1.end, $1.title) }
        let next = timed
            .filter {
                $0.start > now
                    && (calendar.isDate($0.start, inSameDayAs: now) || $0.start.timeIntervalSince(now) <= 3600)
            }
            .min { $0.start < $1.start }
        guard let meeting = current ?? next else {
            return MenuBarDisplay(icon: .doneForToday, time: nil, title: nil, scrollsTitle: false)
        }

        let isLive = current != nil
        let untilStart = meeting.start.timeIntervalSince(now)
        let withinHour = !isLive && untilStart <= 3600

        let time: String
        if isLive {
            time = "\(minutesRoundedUp(meeting.end.timeIntervalSince(now)))m left"
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

    /// "2:30 PM" or "14:30". The 12-hour form uses English AM/PM regardless of locale.
    static func clockTime(_ date: Date, calendar: Calendar, uses24Hour: Bool) -> String {
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
