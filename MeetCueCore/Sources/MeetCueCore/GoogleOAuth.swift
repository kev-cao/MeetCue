import CryptoKit
import Foundation

/// A proof key for one sign-in (RFC 7636), so an intercepted code can't be exchanged by another app.
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    public static func random() -> PKCE {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return PKCE(verifier: base64URL(Data(bytes)))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public enum GoogleOAuthError: Error, Equatable {
    case stateMismatch
    case missingCode
    /// Google's `error` value, such as "access_denied".
    case denied(String)
}

/// Google's OAuth endpoints for an installed app's iOS-type client, which has no client secret.
public struct GoogleOAuthConfig: Sendable, Equatable {
    public static let scope = "https://www.googleapis.com/auth/calendar.events.readonly"
    public static let authorizationURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    public static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    public static let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!

    public let clientID: String

    public init(clientID: String) {
        self.clientID = clientID
    }

    /// "com.googleusercontent.apps.123-abc" for "123-abc.apps.googleusercontent.com", the scheme
    /// Google redirects an iOS-type client to.
    public var redirectScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    public var redirectURI: String { "\(redirectScheme):/oauth2redirect" }

    /// `access_type=offline` and `prompt=consent` make Google return a refresh token on every sign-in,
    /// including a reconnect after the user removed access.
    public func authorizationURL(pkce: PKCE, state: String) -> URL {
        var components = URLComponents(url: Self.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return components.url!
    }

    public func code(fromCallback url: URL, state: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard value("state") == state else { throw GoogleOAuthError.stateMismatch }
        if let error = value("error") { throw GoogleOAuthError.denied(error) }
        guard let code = value("code"), !code.isEmpty else { throw GoogleOAuthError.missingCode }
        return code
    }

    public func tokenRequest(code: String, verifier: String) -> URLRequest {
        Self.formRequest(Self.tokenURL, [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
    }

    public func refreshRequest(refreshToken: String) -> URLRequest {
        Self.formRequest(Self.tokenURL, [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])
    }

    public static func revokeRequest(token: String) -> URLRequest {
        formRequest(revokeURL, ["token": token])
    }

    private static func formRequest(_ url: URL, _ fields: [String: String]) -> URLRequest {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        return request
    }
}

public struct GoogleTokenResponse: Decodable, Sendable, Equatable {
    public var accessToken: String
    /// Seconds until the access token expires.
    public var expiresIn: Int
    /// Present on the first exchange; refreshes keep the same refresh token.
    public var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

/// The body of a failed token request, such as `{"error": "invalid_grant"}`.
public struct GoogleErrorResponse: Decodable, Sendable, Equatable, Error {
    public var error: String
}
