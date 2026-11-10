import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct GoogleCalendarSourceTests {
    let tokens = InMemoryTokenStore()
    let http = FakeHTTPClient()
    let account: GoogleAccount
    let source: GoogleCalendarSource
    let day = (start: AppFixtures.at(0, 0), end: AppFixtures.at(0, 0, day: 5))

    static let page = #"""
    {"summary": "me@example.com", "items": [
      {"id": "e1", "iCalUID": "sync@google.com", "summary": "Team Sync",
       "start": {"dateTime": "2026-11-04T14:30:00-05:00"}, "end": {"dateTime": "2026-11-04T15:00:00-05:00"},
       "hangoutLink": "https://meet.google.com/abc-defg-hij"}
    ]}
    """#

    init() {
        tokens.token = "r1"
        account = GoogleAccount(clientID: "123-abc.apps.googleusercontent.com", tokens: tokens, http: http, authenticator: FakeWebAuthenticator())
        source = GoogleCalendarSource(account: account, http: http, calendar: AppFixtures.calendar)
        http.events = [.init(status: 200, json: Self.page)]
    }

    private func query(_ request: URLRequest) -> [String: String] {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func fetchesAnUncoveredRangeInTheBackground() async throws {
        var changes = 0
        source.onChange = { changes += 1 }
        #expect(source.events(from: day.start, to: day.end).isEmpty)
        await source.settle()
        #expect(changes == 1)
        let request = try #require(http.eventRequests.first)
        #expect(request.url?.path == "/calendar/v3/calendars/primary/events")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer a1")
        #expect(query(request) == [
            "timeMin": "2026-11-04T05:00:00Z",
            "timeMax": "2026-11-05T05:00:00Z",
            "singleEvents": "true",
            "maxResults": "2500",
        ])
        let events = source.events(from: day.start, to: day.end)
        #expect(events.map(\.title) == ["Team Sync"])
        #expect(events.first?.calendarID == GoogleCalendarSource.calendarID)
        #expect(account.email == "me@example.com")
        #expect(http.eventRequests.count == 1)
    }

    @Test func aRangeInsideAFetchedOneIsServedFromMemory() async {
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        let events = source.events(from: AppFixtures.at(14, 0), to: AppFixtures.at(16, 0))
        await source.settle()
        #expect(events.count == 1)
        #expect(source.events(from: AppFixtures.at(16, 0), to: AppFixtures.at(17, 0)).isEmpty)
        await source.settle()
        #expect(http.eventRequests.count == 1)
    }

    @Test func followsPages() async throws {
        http.events = [
            .init(status: 200, json: #"{"summary": "me@example.com", "nextPageToken": "p2", "items": []}"#),
            .init(status: 200, json: Self.page),
        ]
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        #expect(http.eventRequests.count == 2)
        #expect(query(http.eventRequests[1])["pageToken"] == "p2")
        #expect(source.events(from: day.start, to: day.end).count == 1)
    }

    @Test func aFailedFetchWaitsForTheNextInvalidate() async {
        http.events = [.init(status: 500, json: "{}"), .init(status: 200, json: Self.page)]
        var changes = 0
        source.onChange = { changes += 1 }
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        #expect(account.problem != nil)
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        #expect(http.eventRequests.count == 1)
        #expect(changes == 0)
        source.invalidate()
        #expect(changes == 1)
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        #expect(http.eventRequests.count == 2)
        #expect(account.problem == nil)
        #expect(source.events(from: day.start, to: day.end).count == 1)
    }

    @Test func invalidatedEventsStayVisibleWhileRefetching() async {
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        http.events = [.init(status: 200, json: #"{"summary": "me@example.com", "items": []}"#)]
        source.invalidate()
        #expect(source.events(from: day.start, to: day.end).count == 1)
        await source.settle()
        #expect(http.eventRequests.count == 2)
        #expect(source.events(from: day.start, to: day.end).isEmpty)
    }

    @Test func anExpiredTokenIsRefreshedOnce() async {
        var served = 0
        http.eventsHandler = { _ in
            served += 1
            return served == 1 ? .init(status: 401, json: "{}") : .init(status: 200, json: Self.page)
        }
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        #expect(served == 2)
        #expect(http.requests.filter { $0.url == GoogleOAuthConfig.tokenURL }.count == 2)
        #expect(source.events(from: day.start, to: day.end).count == 1)
    }

    @Test func disconnectedMeansNoAccessAndNoRequests() async {
        await account.disconnect()
        #expect(source.access == .denied)
        #expect(source.events(from: day.start, to: day.end).isEmpty)
        await source.settle()
        #expect(http.eventRequests.isEmpty)
        #expect(source.calendars().isEmpty)
    }

    @Test func disconnectingForgetsFetchedEvents() async {
        var changes = 0
        source.onChange = { changes += 1 }
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        await account.disconnect()
        #expect(changes == 2)
        tokens.token = "r2"
        await account.connect()
        #expect(source.events(from: day.start, to: day.end).isEmpty)
    }

    @Test func listsThePrimaryCalendarUnderTheAccount() async {
        #expect(source.access == .granted)
        #expect(source.calendars().map(\.account) == ["Google"])
        _ = source.events(from: day.start, to: day.end)
        await source.settle()
        let calendar = source.calendars()
        #expect(calendar.map(\.id) == [GoogleCalendarSource.calendarID])
        #expect(calendar.map(\.account) == ["me@example.com"])
        #expect(calendar.map(\.title) == ["Google Calendar"])
    }

    @Test func keepsOnlyRecentRanges() async {
        let source = GoogleCalendarSource(account: account, http: http, calendar: AppFixtures.calendar, maxCachedRanges: 2)
        for day in 4...6 {
            _ = source.events(from: AppFixtures.at(0, 0, day: day), to: AppFixtures.at(0, 0, day: day + 1))
            await source.settle()
        }
        _ = source.events(from: AppFixtures.at(0, 0, day: 4), to: AppFixtures.at(0, 0, day: 5))
        await source.settle()
        #expect(http.eventRequests.count == 4)
    }
}
