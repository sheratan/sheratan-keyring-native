import Foundation

struct VaultFileService {
    let fileManager = FileManager.default

    var directoryURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "KeyringNative", directoryHint: .isDirectory)
    }

    var vaultURL: URL { directoryURL.appending(path: "vault.keyring") }

    func exists() -> Bool { fileManager.fileExists(atPath: vaultURL.path) }

    func load() throws -> VaultEnvelope {
        let data = try Data(contentsOf: vaultURL)
        let envelope = try JSONDecoder.keyring.decode(VaultEnvelope.self, from: data)
        guard envelope.formatVersion == 1 else { throw VaultError.unsupportedVersion }
        return envelope
    }

    func save(_ envelope: VaultEnvelope) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.keyring.encode(envelope)
        try data.write(to: vaultURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: vaultURL.path)
    }
}

extension JSONEncoder {
    static var keyring: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var keyring: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
