import Foundation
import MeetCueCore

/// The connected Google account's primary calendar, read through the Calendar API.
///
/// `events(from:to:)` answers from memory. A range that no fetched range covers is fetched in the
/// background, and `onChange` fires when it arrives, so callers read again. Until then, events from
/// overlapping fetched ranges are returned. Nothing is written to disk.
@MainActor
final class GoogleCalendarSource: CalendarSource {
    static let calendarID = "google:primary"
    static let eventsURL = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!

    var onChange: (@MainActor () -> Void)?

    private struct Fetched {
        var range: Range<Date>
        var events: [EventSnapshot]
        /// Set by `invalidate()`; the events are still shown until a refetch replaces them.
        var isStale = false
    }

    private let account: GoogleAccount
    private let http: HTTPClient
    private let calendar: Calendar
    private let maxCachedRanges: Int
    /// Most recently used last.
    private var fetched: [Fetched] = []
    private var inFlight: [Range<Date>: Task<Void, Never>] = [:]
    /// Ranges whose fetch failed since the last `invalidate()`, so a failing request isn't repeated
    /// on every read.
    private var failed: Set<Range<Date>> = []
    private var timer: Timer?

    init(account: GoogleAccount, http: HTTPClient, calendar: Calendar = .autoupdatingCurrent, maxCachedRanges: Int = 8) {
        self.account = account
        self.http = http
        self.calendar = calendar
        self.maxCachedRanges = maxCachedRanges
        account.onChange = { [weak self] in self?.accountChanged() }
    }

    var access: CalendarAccess { account.state == .connected ? .granted : .denied }

    func requestAccess() async -> CalendarAccess { access }

    func events(from start: Date, to end: Date) -> [EventSnapshot] {
        guard access == .granted, start < end else { return [] }
        let range = start..<end
        if let index = fetched.lastIndex(where: { $0.range.contains(range) && !$0.isStale }) {
            fetched.append(fetched.remove(at: index))
            return Self.overlapping(fetched.last!.events, range)
        }
        if inFlight[range] == nil, !failed.contains(range) {
            fetch(range)
        }
        var seen = Set<OccurrenceID>()
        return fetched.reversed().flatMap { Self.overlapping($0.events, range) }.filter { event in
            seen.insert(.make(externalID: event.seriesKey, occurrenceDate: event.occurrenceDate, isRecurring: event.isRecurring)).inserted
        }
    }

    func calendars() -> [CalendarInfo] {
        guard access == .granted else { return [] }
        return [CalendarInfo(id: Self.calendarID, title: "Google Calendar", account: account.email ?? "Google", color: .google)]
    }

    /// Marks everything fetched as out of date, so the next reads fetch again, and lets failed
    /// ranges be tried again.
    func invalidate() {
        for index in fetched.indices {
            fetched[index].isStale = true
        }
        failed = []
        onChange?()
    }

    /// Invalidates every `interval` seconds, so changes made in Google Calendar show up.
    func startRefreshing(every interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Waits for the fetches under way.
    func settle() async {
        while let task = inFlight.values.first {
            await task.value
        }
    }

    private func accountChanged() {
        fetched = []
        failed = []
        for task in inFlight.values { task.cancel() }
        inFlight = [:]
        onChange?()
    }

    private func fetch(_ range: Range<Date>) {
        inFlight[range] = Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight[range] = nil }
            do {
                let (events, name) = try await self.download(range)
                guard !Task.isCancelled else { return }
                self.fetched.removeAll { $0.range == range }
                self.fetched.append(Fetched(range: range, events: events))
                if self.fetched.count > self.maxCachedRanges {
                    self.fetched.removeFirst(self.fetched.count - self.maxCachedRanges)
                }
                if let name { self.account.email = name }
                self.account.problem = nil
                self.onChange?()
            } catch {
                guard !Task.isCancelled else { return }
                self.failed.insert(range)
                if self.account.state == .connected {
                    self.account.problem = "Couldn't read your Google calendar. \(GoogleAccount.describe(error))"
                }
            }
        }
    }

    private func download(_ range: Range<Date>) async throws -> ([EventSnapshot], String?) {
        var items: [GoogleEvent] = []
        var name: String?
        var pageToken: String?
        var token = try await account.accessToken()
        var retried = false
        while true {
            let (data, status) = try await http.send(request(range, pageToken: pageToken, token: token))
            if status == 401, !retried {
                retried = true
                token = try await account.accessToken(forceRefresh: true)
                continue
            }
            guard status == 200 else { throw GoogleAccount.Failure.status(status) }
            let page = try JSONDecoder().decode(GoogleEventList.self, from: data)
            name = page.summary ?? name
            items += page.items ?? []
            pageToken = page.nextPageToken
            if pageToken == nil { break }
        }
        return (GoogleEventMapper.snapshots(from: items, calendarID: Self.calendarID, calendar: calendar), name)
    }

    private func request(_ range: Range<Date>, pageToken: String?, token: String) -> URLRequest {
        var components = URLComponents(url: Self.eventsURL, resolvingAgainstBaseURL: false)!
        let format = Date.ISO8601FormatStyle()
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: format.format(range.lowerBound)),
            URLQueryItem(name: "timeMax", value: format.format(range.upperBound)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "maxResults", value: "2500"),
        ] + (pageToken.map { [URLQueryItem(name: "pageToken", value: $0)] } ?? [])
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func overlapping(_ events: [EventSnapshot], _ range: Range<Date>) -> [EventSnapshot] {
        events.filter { $0.start < range.upperBound && $0.end > range.lowerBound }
    }
}

extension CalendarColor {
    /// Google Calendar's default blue.
    static let google = CalendarColor(red: 0.26, green: 0.52, blue: 0.96)
}
