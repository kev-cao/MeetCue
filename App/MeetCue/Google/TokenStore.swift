import Foundation
import Security

/// Where the Google refresh token is kept between launches.
@MainActor
protocol TokenStore: AnyObject {
    func read() -> String?
    /// Saves the token, or deletes it when nil.
    func write(_ token: String?)
}

/// A generic password item in the login keychain.
final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account = "refresh-token"

    init(service: String = "io.github.kev-cao.MeetCue.google") {
        self.service = service
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func read() -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ token: String?) {
        SecItemDelete(query as CFDictionary)
        guard let token else { return }
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}
