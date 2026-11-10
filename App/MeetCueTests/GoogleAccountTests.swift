import Foundation
import MeetCueCore
import Testing
@testable import MeetCue

@MainActor
struct GoogleAccountTests {
    let tokens = InMemoryTokenStore()
    let http = FakeHTTPClient()
    let web = FakeWebAuthenticator()
    let clock = MutableClock(AppFixtures.at(13, 0))

    func makeAccount(clientID: String? = "123-abc.apps.googleusercontent.com") -> GoogleAccount {
        GoogleAccount(clientID: clientID, tokens: tokens, http: http, authenticator: web, now: { [clock] in clock.now })
    }

    @Test func withoutAClientIDItsUnavailable() {
        tokens.token = "r1"
        #expect(makeAccount(clientID: nil).state == .unavailable)
        #expect(makeAccount(clientID: "").state == .unavailable)
    }

    @Test func aStoredTokenMeansConnected() {
        tokens.token = "r1"
        #expect(makeAccount().state == .connected)
        tokens.token = nil
        #expect(makeAccount().state == .disconnected)
    }

    @Test func connectExchangesTheCodeAndKeepsTheRefreshToken() async throws {
        let account = makeAccount()
        var changes = 0
        account.onChange = { changes += 1 }
        http.token = .init(status: 200, json: #"{"access_token": "a1", "expires_in": 3600, "refresh_token": "r1"}"#)
        await account.connect()
        #expect(account.state == .connected)
        #expect(account.problem == nil)
        #expect(tokens.token == "r1")
        #expect(changes == 1)
        let authURL = try #require(web.requestedURL)
        #expect(authURL.host == "accounts.google.com")
        #expect(web.requestedScheme == "com.googleusercontent.apps.123-abc")
        let body = try #require(http.requests.first?.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("code=4%2Fcode"))
        #expect(try await account.accessToken() == "a1")
        #expect(http.requests.count == 1)
    }

    @Test func cancellingSignInLeavesItDisconnectedQuietly() async {
        let account = makeAccount()
        web.cancel = true
        await account.connect()
        #expect(account.state == .disconnected)
        #expect(account.problem == nil)
        #expect(tokens.token == nil)
    }

    @Test func aFailedExchangeExplainsItself() async {
        let account = makeAccount()
        http.token = .init(status: 400, json: #"{"error": "invalid_request"}"#)
        await account.connect()
        #expect(account.state == .disconnected)
        #expect(account.problem != nil)
    }

    @Test func expiredAccessTokenIsRefreshed() async throws {
        tokens.token = "r1"
        let account = makeAccount()
        http.token = .init(status: 200, json: #"{"access_token": "a1", "expires_in": 3600}"#)
        #expect(try await account.accessToken() == "a1")
        clock.now = clock.now.addingTimeInterval(30 * 60)
        #expect(try await account.accessToken() == "a1")
        #expect(http.requests.count == 1)
        http.token = .init(status: 200, json: #"{"access_token": "a2", "expires_in": 3600}"#)
        clock.now = clock.now.addingTimeInterval(31 * 60)
        #expect(try await account.accessToken() == "a2")
        #expect(try await account.accessToken(forceRefresh: true) == "a2")
        #expect(http.requests.count == 3)
        #expect(tokens.token == "r1")
    }

    @Test func revokedRefreshTokenAsksToReconnect() async {
        tokens.token = "r1"
        let account = makeAccount()
        var changes = 0
        account.onChange = { changes += 1 }
        http.token = .init(status: 400, json: #"{"error": "invalid_grant"}"#)
        await #expect(throws: GoogleAccount.Failure.needsReconnect) { try await account.accessToken() }
        #expect(account.state == .needsReconnect)
        #expect(tokens.token == nil)
        #expect(changes == 1)
    }

    @Test func networkTroubleKeepsTheConnection() async {
        tokens.token = "r1"
        let account = makeAccount()
        http.failure = URLError(.notConnectedToInternet)
        await #expect(throws: URLError.self) { try await account.accessToken() }
        #expect(account.state == .connected)
        #expect(tokens.token == "r1")
    }

    @Test func disconnectRevokesAndForgets() async throws {
        tokens.token = "r1"
        let account = makeAccount()
        account.email = "me@example.com"
        var changes = 0
        account.onChange = { changes += 1 }
        await account.disconnect()
        #expect(account.state == .disconnected)
        #expect(account.email == nil)
        #expect(tokens.token == nil)
        #expect(changes == 1)
        let revoke = try #require(http.requests.last)
        #expect(revoke.url == GoogleOAuthConfig.revokeURL)
        #expect(revoke.httpBody.flatMap { String(data: $0, encoding: .utf8) } == "token=r1")
        await #expect(throws: GoogleAccount.Failure.notConnected) { try await account.accessToken() }
    }

    @Test func reconnectingClearsTheProblem() async {
        tokens.token = "r1"
        let account = makeAccount()
        http.token = .init(status: 400, json: #"{"error": "invalid_grant"}"#)
        _ = try? await account.accessToken()
        http.token = .init(status: 200, json: #"{"access_token": "a1", "expires_in": 3600, "refresh_token": "r2"}"#)
        await account.connect()
        #expect(account.state == .connected)
        #expect(tokens.token == "r2")
    }
}

final class InMemoryTokenStore: TokenStore {
    var token: String?
    func read() -> String? { token }
    func write(_ token: String?) { self.token = token }
}

final class MutableClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@MainActor
final class FakeWebAuthenticator: WebAuthenticator {
    var cancel = false
    var code = "4/code"
    private(set) var requestedURL: URL?
    private(set) var requestedScheme: String?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        requestedURL = url
        requestedScheme = callbackScheme
        if cancel { throw CancellationError() }
        let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value ?? ""
        return URL(string: "\(callbackScheme):/oauth2redirect?state=\(state)&code=\(code)")!
    }
}

/// Answers Google's token, revoke and events endpoints from canned responses.
@MainActor
final class FakeHTTPClient: HTTPClient {
    struct Response {
        var status: Int
        var json: String
    }

    var token = Response(status: 200, json: #"{"access_token": "a1", "expires_in": 3600}"#)
    /// Events pages in order; the last one repeats.
    var events: [Response] = [Response(status: 200, json: #"{"items": []}"#)]
    var eventsHandler: ((URLRequest) -> Response)?
    var failure: Error?
    private(set) var requests: [URLRequest] = []
    private var eventsServed = 0

    var eventRequests: [URLRequest] { requests.filter { $0.url?.host == "www.googleapis.com" } }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if let failure { throw failure }
        let response: Response
        switch request.url {
        case GoogleOAuthConfig.tokenURL?: response = token
        case GoogleOAuthConfig.revokeURL?: response = Response(status: 200, json: "{}")
        default:
            if let eventsHandler {
                response = eventsHandler(request)
            } else {
                response = events[min(eventsServed, events.count - 1)]
                eventsServed += 1
            }
        }
        return (Data(response.json.utf8), response.status)
    }
}
