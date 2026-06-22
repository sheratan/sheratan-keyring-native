import Foundation
import LocalAuthentication
import Security

struct KeychainService {
    private let service = "com.openai.keyringnative.biometric"

    func storeBiometricKey(_ data: Data, vaultID: UUID) throws {
        delete(vaultID: vaultID)
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            &error
        ) else {
            if let error { throw error.takeRetainedValue() }
            throw VaultError.biometricUnavailable
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: vaultID.uuidString,
            kSecAttrAccessControl as String: access,
            kSecValueData as String: data
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw VaultError.biometricUnavailable
        }
    }

    func loadBiometricKey(vaultID: UUID) async throws -> Data {
        let context = LAContext()
        context.localizedReason = "Unlock your Keyring vault"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: vaultID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        return try await Task.detached {
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data else {
                throw VaultError.biometricUnavailable
            }
            return data
        }.value
    }

    func hasBiometricKey(vaultID: UUID) -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: vaultID.uuidString,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    func delete(vaultID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: vaultID.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
