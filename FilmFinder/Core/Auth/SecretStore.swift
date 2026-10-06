import Foundation
import Security

protocol SecretStore: Sendable {
    func string(for key: String) -> String?
    func set(_ value: String?, for key: String)
}

/// Guarda segredos no Keychain (acessíveis após o primeiro desbloqueio, só neste aparelho).
final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    init(service: String = "com.andre.filmfinder") {
        self.service = service
    }

    func string(for key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String?, for key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
        guard let value else { return }
        var item = baseQuery(key)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
