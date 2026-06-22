import CryptoKit
import Foundation

struct BackupService {
    let crypto: CryptoService

    func create(
        payload: VaultPayload,
        sourceVaultID: UUID,
        password: String,
        iterations: UInt32 = CryptoService.minimumIterations
    ) throws -> BackupEnvelope {
        let configuration = KDFConfiguration(
            iterations: iterations,
            salt: try crypto.randomData(count: 32)
        )
        let passwordKey = try crypto.derivePasswordKey(password: password, configuration: configuration)
        let backupKeyData = try crypto.randomData(count: 32)
        let backupKey = SymmetricKey(data: backupKeyData)
        return BackupEnvelope(
            backupID: UUID(),
            sourceVaultID: sourceVaultID,
            createdAt: .now,
            kdf: configuration,
            passwordWrappedKey: try crypto.seal(
                backupKeyData, with: passwordKey, context: "Keyring Backup Wrapped Key v1"
            ),
            encryptedPayload: try crypto.seal(
                JSONEncoder.keyring.encode(payload),
                with: backupKey,
                context: "Keyring Backup Payload v1"
            )
        )
    }

    func restore(_ envelope: BackupEnvelope, password: String) throws -> VaultPayload {
        guard envelope.formatVersion == 1 else { throw VaultError.unsupportedVersion }
        do {
            let passwordKey = try crypto.derivePasswordKey(password: password, configuration: envelope.kdf)
            let keyData = try crypto.open(
                envelope.passwordWrappedKey,
                with: passwordKey,
                context: "Keyring Backup Wrapped Key v1"
            )
            let plaintext = try crypto.open(
                envelope.encryptedPayload,
                with: SymmetricKey(data: keyData),
                context: "Keyring Backup Payload v1"
            )
            return try JSONDecoder.keyring.decode(VaultPayload.self, from: plaintext)
        } catch {
            throw VaultError.invalidPassword
        }
    }

    func save(_ envelope: BackupEnvelope, to url: URL) throws {
        try JSONEncoder.keyring.encode(envelope).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func load(from url: URL) throws -> BackupEnvelope {
        let envelope = try JSONDecoder.keyring.decode(BackupEnvelope.self, from: Data(contentsOf: url))
        guard envelope.formatVersion == 1 else { throw VaultError.unsupportedVersion }
        return envelope
    }

    func prune(directory: URL) {
        let manager = FileManager.default
        guard let urls = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "keyringbackup" }) else { return }

        let sorted = urls.sorted {
            ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
        }
        let calendar = Calendar(identifier: .gregorian)
        var keptDays = Set<DateComponents>()
        var keptMonths = Set<DateComponents>()
        var keep = Set<URL>()
        for url in sorted {
            let date = url.modificationDate ?? .distantPast
            let day = calendar.dateComponents([.year, .month, .day], from: date)
            if keptDays.count < 30, keptDays.insert(day).inserted {
                keep.insert(url)
                continue
            }
            let month = calendar.dateComponents([.year, .month], from: date)
            if keptMonths.count < 12, keptMonths.insert(month).inserted {
                keep.insert(url)
            }
        }
        for url in sorted where !keep.contains(url) {
            try? manager.removeItem(at: url)
        }
    }
}

private extension URL {
    var modificationDate: Date? {
        try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
