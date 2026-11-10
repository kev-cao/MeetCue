import Foundation
import MeetCueCore
import Observation

@MainActor
@Observable
final class MeetingStore {
    private(set) var access: CalendarAccess
    /// Today's and tomorrow's meetings from `MeetingFilter.relevant`, so the menu bar can look past midnight.
    private(set) var meetings: [Meeting] = []
    private(set) var calendars: [CalendarInfo] = []
    /// Goes up on every refresh, so views that query other date ranges know to query again.
    private(set) var revision = 0
    var filter = CalendarFilter() {
        didSet { refresh() }
    }

    @ObservationIgnored private let source: CalendarSource
    /// The connected Google account's calendar. Its meetings that are also on the Mac only add
    /// their join link and reply to the Mac's copies; see `GoogleMerge`.
    @ObservationIgnored private let google: CalendarSource?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    init(source: CalendarSource, google: CalendarSource? = nil, now: @escaping () -> Date = Date.init, calendar: Calendar = .autoupdatingCurrent) {
        self.source = source
        self.google = google
        self.now = now
        self.calendar = calendar
        access = source.access
        source.onChange = { [weak self] in self?.refresh() }
        google?.onChange = { [weak self] in self?.refresh() }
    }

    func requestAccess() async {
        access = await source.requestAccess()
        refresh()
    }

    func refresh() {
        defer { revision += 1 }
        access = source.access
        guard access == .granted else {
            meetings = []
            calendars = []
            return
        }
        let start = calendar.startOfDay(for: now())
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return }
        meetings = meetings(from: start, to: end)
        calendars = source.calendars() + (google?.calendars() ?? [])
    }

    /// Relevant meetings overlapping `start..<end`, read from the calendars now. Uses the store's
    /// filter unless given another.
    func meetings(from start: Date, to end: Date, filter: CalendarFilter? = nil) -> [Meeting] {
        guard source.access == .granted else { return [] }
        let local = source.events(from: start, to: end).map(MeetingMapper.meeting(from:))
        let remote = google.map { $0.access == .granted ? $0.events(from: start, to: end).map(MeetingMapper.meeting(from:)) : [] } ?? []
        return MeetingFilter.relevant(GoogleMerge.merge(local: local, google: remote), filter: filter ?? self.filter)
    }
}
