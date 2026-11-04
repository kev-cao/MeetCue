import AppKit
import Foundation
import MeetCueCore
import Observation

/// What the calendar window shows: the view and the days in it, their meetings, the sidebar's
/// calendars, and the selected meeting with its notes.
@MainActor
@Observable
final class CalendarWindowModel {
    enum EditorMode: String, CaseIterable, Identifiable {
        case preview, markdown

        var id: Self { self }

        var title: String {
            switch self {
            case .preview: "Preview"
            case .markdown: "Markdown"
            }
        }
    }

    struct CalendarGroup: Equatable, Identifiable {
        let account: String
        let calendars: [CalendarInfo]

        var id: String { account }
    }

    let store: MeetingStore
    let notes: NoteStore
    var mode: CalendarMode = .week {
        didSet { reload() }
    }
    var editorMode: EditorMode = .preview
    /// The start of the day the view is built around.
    private(set) var anchor: Date
    /// Meetings overlapping the days shown, all-day events included.
    private(set) var meetings: [Meeting] = []
    private(set) var selected: Meeting?

    @ObservationIgnored private let visibility: CalendarVisibility
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let openURL: @MainActor (URL) -> Void

    init(
        store: MeetingStore,
        notes: NoteStore,
        visibility: CalendarVisibility,
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        openURL: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.store = store
        self.notes = notes
        self.visibility = visibility
        self.clock = clock
        self.calendar = calendar
        self.locale = locale
        self.openURL = openURL
        anchor = calendar.startOfDay(for: clock())
    }

    func currentTime() -> Date { clock() }

    /// Reloads whenever the store refreshes, which it does when the calendars change.
    func startTracking() {
        withObservationTracking {
            _ = store.revision
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.reload()
                self?.startTracking()
            }
        }
        reload()
    }

    func reload() {
        let interval = CalendarGrid.interval(mode, containing: anchor, calendar: calendar)
        meetings = store.meetings(from: interval.start, to: interval.end)
        guard let current = selected else { return }
        if let fresh = meetings.first(where: { $0.id == current.id }) {
            selected = fresh
        } else if interval.contains(current.start) {
            // Gone from a day on screen: deleted, declined, or on a calendar just hidden.
            selected = nil
        }
    }

    // MARK: Navigation

    var days: [Date] { CalendarGrid.days(mode, containing: anchor, calendar: calendar) }

    func goToToday() {
        anchor = calendar.startOfDay(for: clock())
        reload()
    }

    func step(_ count: Int) {
        anchor = CalendarGrid.step(mode, from: anchor, by: count, calendar: calendar)
        reload()
    }

    func go(to day: Date, mode: CalendarMode? = nil) {
        anchor = calendar.startOfDay(for: day)
        if let mode, mode != self.mode {
            self.mode = mode
        } else {
            reload()
        }
    }

    func select(_ meeting: Meeting?) {
        selected = meeting
    }

    /// Opens the meeting's day in the current view and selects it.
    func show(_ meeting: Meeting) {
        go(to: meeting.start)
        selected = meetings.first { $0.id == meeting.id } ?? meeting
    }

    // MARK: Grid

    func isToday(_ day: Date) -> Bool { calendar.isDate(day, inSameDayAs: clock()) }

    func isInAnchorMonth(_ day: Date) -> Bool { calendar.isDate(day, equalTo: anchor, toGranularity: .month) }

    func timedMeetings(on day: Date) -> [Meeting] {
        meetings.filter { !$0.isAllDay && overlaps($0, day) }
    }

    func allDayMeetings(on day: Date) -> [Meeting] {
        meetings.filter { $0.isAllDay && overlaps($0, day) }
    }

    func placed(on day: Date) -> [PlacedMeeting] { DayLayout.place(timedMeetings(on: day)) }

    func hasNotes(_ meeting: Meeting) -> Bool { notes.hasNotes(meeting.id) }

    /// Hours since the start of `day`, so a grid can place `date` on it.
    func hours(of date: Date, on day: Date) -> Double {
        date.timeIntervalSince(calendar.startOfDay(for: day)) / 3600
    }

    private func overlaps(_ meeting: Meeting, _ day: Date) -> Bool {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return meeting.start < end && (meeting.end > start || meeting.start == start)
    }

    // MARK: Sidebar

    var calendarGroups: [CalendarGroup] {
        Dictionary(grouping: store.calendars, by: \.account)
            .map { CalendarGroup(account: $0.key, calendars: $0.value.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }) }
            .sorted { $0.account.localizedStandardCompare($1.account) == .orderedAscending }
    }

    func isVisible(_ calendarID: String) -> Bool { visibility.isVisible(calendarID) }

    func setVisible(_ visible: Bool, calendarID: String) {
        visibility.setVisible(visible, calendarID: calendarID)
        reload()
    }

    func calendarInfo(for meeting: Meeting) -> CalendarInfo? {
        store.calendars.first { $0.id == meeting.calendarID }
    }

    func color(for meeting: Meeting) -> CalendarColor {
        calendarInfo(for: meeting)?.color ?? .gray
    }

    // MARK: Text

    private var uses24Hour: Bool { ClockStyle.uses24Hour(locale) }

    private func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        var style = style
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        return date.formatted(style)
    }

    /// "November" and "2026", or "Wednesday, November 4" and "2026" in the day view.
    var title: (primary: String, secondary: String) {
        let year = format(anchor, Date.FormatStyle().year())
        switch mode {
        case .day: return (format(anchor, Date.FormatStyle().weekday(.wide).month(.wide).day()), year)
        case .week, .month: return (format(anchor, Date.FormatStyle().month(.wide)), year)
        }
    }

    /// "Wed".
    func weekdayLabel(_ day: Date) -> String { format(day, Date.FormatStyle().weekday(.abbreviated)) }

    /// "W", for the mini month.
    func weekdayInitial(_ day: Date) -> String { format(day, Date.FormatStyle().weekday(.narrow)) }

    /// "November 2026", for the mini month.
    func monthTitle(_ day: Date) -> String { format(day, Date.FormatStyle().month(.wide).year()) }

    func dayNumber(_ day: Date) -> String { "\(calendar.component(.day, from: day))" }

    /// "9 AM", "Noon", or "09:00".
    func hourLabel(_ hour: Int) -> String {
        if uses24Hour { return String(format: "%02d:00", hour) }
        if hour == 12 { return "Noon" }
        return "\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")"
    }

    func timeRange(for meeting: Meeting) -> String {
        MenuBarText.timeRange(meeting.start, meeting.end, calendar: calendar, uses24Hour: uses24Hour)
    }

    /// "2:30 PM" or "14:30".
    func startTime(for meeting: Meeting) -> String {
        MenuBarText.clockTime(meeting.start, calendar: calendar, uses24Hour: uses24Hour)
    }

    /// "Wednesday, Nov 4 · 2:30 – 3:00 PM", or "Wednesday, Nov 4 · All day".
    func dateLine(for meeting: Meeting) -> String {
        let day = format(meeting.start, Date.FormatStyle().weekday(.wide).month(.abbreviated).day())
        return "\(day) · \(meeting.isAllDay ? "All day" : timeRange(for: meeting))"
    }

    /// "6 attendees · you accepted". Nil for an event without attendees.
    func attendeeLine(for meeting: Meeting) -> String? {
        guard meeting.attendeeCount > 0 else { return nil }
        let count = meeting.attendeeCount == 1 ? "1 attendee" : "\(meeting.attendeeCount) attendees"
        let reply: String? = switch meeting.myStatus {
        case .accepted: "you accepted"
        case .tentative: "you said maybe"
        case .declined: "you declined"
        case .pending: "you haven't replied"
        case .unknown: nil
        }
        return [count, reply].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Work · Google".
    func calendarLine(for meeting: Meeting) -> String? {
        calendarInfo(for: meeting).map { "\($0.title) · \($0.account)" }
    }

    // MARK: Actions

    func join(_ meeting: Meeting) {
        if let link = meeting.joinLink { openURL(link.url) }
    }

    func markdown(for meeting: Meeting) -> String { notes.markdown(for: meeting.id) }

    func setMarkdown(_ markdown: String, for meeting: Meeting) { notes.setMarkdown(markdown, for: meeting) }

    func toggleTask(line: Int, for meeting: Meeting) { notes.toggleTask(line: line, for: meeting) }

    func addTopic(_ topic: String, to meeting: Meeting) { notes.appendTopic(topic, to: meeting) }
}
