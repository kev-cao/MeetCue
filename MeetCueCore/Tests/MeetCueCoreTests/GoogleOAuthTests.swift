import Foundation
import Testing
@testable import MeetCueCore

struct GoogleOAuthTests {
    let config = GoogleOAuthConfig(clientID: "123-abc.apps.googleusercontent.com")

    @Test func challengeMatchesRFC7636Sample() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func randomVerifierIsURLSafeAndLongEnough() {
        let verifier = PKCE.random().verifier
        #expect((43...128).contains(verifier.count))
        #expect(verifier.allSatisfy { $0.isLetter || $0.isNumber || "-._~".contains($0) })
        #expect(PKCE.random().verifier != verifier)
    }

    @Test func redirectUsesTheReversedClientID() {
        #expect(config.redirectScheme == "com.googleusercontent.apps.123-abc")
        #expect(config.redirectURI == "com.googleusercontent.apps.123-abc:/oauth2redirect")
    }

    @Test func authorizationURLAsksForOfflineReadOnlyAccess() throws {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        let url = config.authorizationURL(pkce: pkce, state: "s1")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "accounts.google.com")
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query == [
            "client_id": "123-abc.apps.googleusercontent.com",
            "redirect_uri": "com.googleusercontent.apps.123-abc:/oauth2redirect",
            "response_type": "code",
            "scope": "https://www.googleapis.com/auth/calendar.events.readonly",
            "code_challenge": "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            "code_challenge_method": "S256",
            "state": "s1",
            "access_type": "offline",
            "prompt": "consent",
        ])
    }

    @Test func callbackGivesTheCodeWhenStateMatches() throws {
        let url = URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=s1&code=4/xyz")!
        #expect(try config.code(fromCallback: url, state: "s1") == "4/xyz")
    }

    @Test func callbackRejectsAnotherState() {
        let url = URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=other&code=4/xyz")!
        #expect(throws: GoogleOAuthError.stateMismatch) { try config.code(fromCallback: url, state: "s1") }
    }

    @Test func callbackReportsGooglesError() {
        let url = URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=s1&error=access_denied")!
        #expect(throws: GoogleOAuthError.denied("access_denied")) { try config.code(fromCallback: url, state: "s1") }
    }

    @Test func tokenRequestsAreFormEncoded() throws {
        let exchange = config.tokenRequest(code: "4/x y", verifier: "v")
        #expect(exchange.url == GoogleOAuthConfig.tokenURL)
        #expect(exchange.httpMethod == "POST")
        #expect(exchange.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let body = try #require(exchange.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body == "client_id=123-abc.apps.googleusercontent.com&code=4%2Fx%20y&code_verifier=v&grant_type=authorization_code&redirect_uri=com.googleusercontent.apps.123-abc%3A%2Foauth2redirect")

        let refresh = config.refreshRequest(refreshToken: "r+1")
        let refreshBody = try #require(refresh.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(refreshBody == "client_id=123-abc.apps.googleusercontent.com&grant_type=refresh_token&refresh_token=r%2B1")
    }

    @Test func revokeRequestCarriesTheToken() throws {
        let request = GoogleOAuthConfig.revokeRequest(token: "r1")
        #expect(request.url == GoogleOAuthConfig.revokeURL)
        #expect(request.httpBody.flatMap { String(data: $0, encoding: .utf8) } == "token=r1")
    }

    @Test func decodesTokenResponses() throws {
        let full = try JSONDecoder().decode(GoogleTokenResponse.self, from: Data(#"{"access_token": "a", "expires_in": 3599, "refresh_token": "r", "token_type": "Bearer"}"#.utf8))
        #expect(full.accessToken == "a")
        #expect(full.expiresIn == 3599)
        #expect(full.refreshToken == "r")
        let refreshed = try JSONDecoder().decode(GoogleTokenResponse.self, from: Data(#"{"access_token": "b", "expires_in": 3599}"#.utf8))
        #expect(refreshed.refreshToken == nil)
    }

    @Test func decodesErrorResponses() throws {
        let error = try JSONDecoder().decode(GoogleErrorResponse.self, from: Data(#"{"error": "invalid_grant", "error_description": "Token has been expired or revoked."}"#.utf8))
        #expect(error.error == "invalid_grant")
    }
}
