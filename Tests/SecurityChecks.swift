import CryptoKit
import Foundation

@main
struct SecurityChecks {
    static func main() throws {
        let crypto = CryptoService()

        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("secret vault payload".utf8)
        let sealed = try crypto.seal(plaintext, with: key, context: "test-context")
        try require(
            crypto.open(sealed, with: key, context: "test-context") == plaintext,
            "AES-GCM round trip failed"
        )

        var tampered = sealed.combined
        tampered[tampered.startIndex] ^= 0x01
        do {
            _ = try crypto.open(
                SealedPayload(combined: tampered), with: key, context: "test-context"
            )
            throw CheckError.failed("tampered ciphertext was accepted")
        } catch VaultError.corruptedData {
            // Expected.
        }

        let configuration = KDFConfiguration(
            iterations: CryptoService.minimumIterations,
            salt: Data(repeating: 7, count: 32)
        )
        let first = try crypto.derivePasswordKey(
            password: "correct horse battery staple", configuration: configuration
        )
        let second = try crypto.derivePasswordKey(
            password: "correct horse battery staple", configuration: configuration
        )
        try require(crypto.keyData(first) == crypto.keyData(second), "PBKDF2 was not stable")

        let recovery = try crypto.generateRecoveryKey()
        try require(recovery.split(separator: "-").count == 16, "recovery-key format failed")
        try require(
            crypto.keyData(try crypto.recoveryKey(from: recovery)) ==
            crypto.keyData(try crypto.recoveryKey(from: recovery.lowercased())),
            "recovery-key normalization failed"
        )

        let backupService = BackupService(crypto: crypto)
        let item = VaultItem(
            id: UUID(), name: "Example", type: .apiKey, value: "test-secret",
            username: "user", website: "https://example.com", notes: "note",
            tags: ["test"], favorite: true,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let payload = VaultPayload(items: [item])
        let backup = try backupService.create(
            payload: payload,
            sourceVaultID: UUID(),
            password: "backup password with length"
        )
        try require(
            try backupService.restore(backup, password: "backup password with length") == payload,
            "backup round trip failed"
        )
        do {
            _ = try backupService.restore(backup, password: "wrong password here")
            throw CheckError.failed("wrong backup password was accepted")
        } catch VaultError.invalidPassword {
            // Expected.
        }
        try require(
            backup.encryptedPayload.combined.range(of: Data(item.value.utf8)) == nil,
            "backup contains plaintext secret"
        )

        print("All Keyring security checks passed.")
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw CheckError.failed(message) }
    }
}

enum CheckError: Error {
    case failed(String)
}
