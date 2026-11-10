import Foundation
import MeetCueCore
import Observation

/// The connection to a Google account: signing in, access tokens for the Calendar API, and
/// disconnecting. Only the refresh token is stored, in `tokens`.
@MainActor
@Observable
final class GoogleAccount {
    enum State: Equatable {
        /// The build has no OAuth client ID, so Google can't be connected.
        case unavailable
        case disconnected
        case connecting
        case connected
        /// Google rejected the stored sign-in, for example after the user removed MeetCue's access.
        case needsReconnect
    }

    enum Failure: Error, Equatable {
        case notConnected
        case needsReconnect
        /// Google answered with this HTTP status.
        case status(Int)
        /// The sign-in succeeded without a refresh token, so it would stop working within the hour.
        case noRefreshToken
    }

    private(set) var state: State
    /// The account's email address, learned from the first calendar fetch. Kept in memory only.
    var email: String?
    /// Why the last sign-in or fetch failed, in words for Settings. Nil once one succeeds.
    var problem: String?
    /// Called when the account connects or disconnects, or needs to reconnect.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let config: GoogleOAuthConfig?
    @ObservationIgnored private let tokens: TokenStore
    @ObservationIgnored private let http: HTTPClient
    @ObservationIgnored private let authenticator: WebAuthenticator
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var accessToken: (value: String, expires: Date)?
    @ObservationIgnored private var refreshing: Task<String, Error>?

    init(clientID: String?, tokens: TokenStore, http: HTTPClient, authenticator: WebAuthenticator, now: @escaping () -> Date = Date.init) {
        let clientID = clientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        config = clientID.isEmpty ? nil : GoogleOAuthConfig(clientID: clientID)
        self.tokens = tokens
        self.http = http
        self.authenticator = authenticator
        self.now = now
        state = config == nil ? .unavailable : (tokens.read() == nil ? .disconnected : .connected)
    }

    /// The client ID from the build's Info.plist, or nil when the build was made without one.
    static var bundledClientID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    func connect() async {
        guard let config, state != .connecting else { return }
        let fallback: State = state == .needsReconnect ? .needsReconnect : .disconnected
        state = .connecting
        problem = nil
        do {
            let pkce = PKCE.random()
            let stateToken = UUID().uuidString
            let callback = try await authenticator.authenticate(
                url: config.authorizationURL(pkce: pkce, state: stateToken),
                callbackScheme: config.redirectScheme
            )
            let code = try config.code(fromCallback: callback, state: stateToken)
            let response = try await tokenResponse(config.tokenRequest(code: code, verifier: pkce.verifier))
            guard let refreshToken = response.refreshToken else { throw Failure.noRefreshToken }
            tokens.write(refreshToken)
            keep(response)
            state = .connected
            onChange?()
        } catch is CancellationError {
            state = fallback
        } catch GoogleOAuthError.denied("access_denied") {
            state = fallback
        } catch {
            state = fallback
            problem = "Couldn't connect to Google. \(Self.describe(error))"
        }
    }

    func disconnect() async {
        let refreshToken = tokens.read()
        tokens.write(nil)
        accessToken = nil
        email = nil
        problem = nil
        state = config == nil ? .unavailable : .disconnected
        onChange?()
        if let refreshToken {
            _ = try? await http.send(GoogleOAuthConfig.revokeRequest(token: refreshToken))
        }
    }

    /// A current access token, refreshed when it's about to expire or when `forceRefresh` is set
    /// (after the API rejected the last one).
    func accessToken(forceRefresh: Bool = false) async throws -> String {
        guard state == .connected else { throw state == .needsReconnect ? Failure.needsReconnect : Failure.notConnected }
        if !forceRefresh, let accessToken, accessToken.expires > now() {
            return accessToken.value
        }
        if let refreshing { return try await refreshing.value }
        let task = Task { try await refresh() }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    private func refresh() async throws -> String {
        guard let config, let refreshToken = tokens.read() else { throw Failure.notConnected }
        do {
            let response = try await tokenResponse(config.refreshRequest(refreshToken: refreshToken))
            keep(response)
            return response.accessToken
        } catch let error as GoogleErrorResponse where error.error == "invalid_grant" {
            tokens.write(nil)
            accessToken = nil
            state = .needsReconnect
            problem = nil
            onChange?()
            throw Failure.needsReconnect
        }
    }

    private func keep(_ response: GoogleTokenResponse) {
        // A minute's margin, so a token doesn't expire between this check and Google receiving it.
        accessToken = (response.accessToken, now().addingTimeInterval(TimeInterval(response.expiresIn - 60)))
    }

    private func tokenResponse(_ request: URLRequest) async throws -> GoogleTokenResponse {
        let (data, status) = try await http.send(request)
        guard status == 200 else {
            throw (try? JSONDecoder().decode(GoogleErrorResponse.self, from: data)) ?? Failure.status(status)
        }
        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case let error as GoogleErrorResponse: "Google said \"\(error.error)\"."
        case Failure.status(403): "Google refused the request. Check that the Calendar API is turned on for this app."
        case Failure.status(let status): "Google answered with error \(status)."
        case Failure.noRefreshToken: "Google didn't allow MeetCue to stay signed in."
        case let error as URLError: error.localizedDescription
        default: error.localizedDescription
        }
    }
}
