import Foundation

enum CredentialType: String, Codable, CaseIterable, Identifiable {
    case password = "Password"
    case apiKey = "API key"
    case token = "Token"
    case secureNote = "Secure note"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .password: "lock"
        case .apiKey: "key"
        case .token: "curlybraces"
        case .secureNote: "note.text"
        }
    }
}

struct VaultItem: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: CredentialType
    var value: String
    var username: String
    var website: String
    var notes: String
    var tags: [String]
    var favorite: Bool
    var updatedAt: Date

    static let empty = VaultItem(
        id: UUID(), name: "", type: .password, value: "", username: "",
        website: "", notes: "", tags: [], favorite: false, updatedAt: .now
    )
}

struct VaultPayload: Codable, Equatable {
    var schemaVersion = 1
    var items: [VaultItem]
}

struct KDFConfiguration: Codable, Equatable {
    var algorithm = "PBKDF2-HMAC-SHA256"
    var iterations: UInt32
    var salt: Data
}

struct SealedPayload: Codable, Equatable {
    var combined: Data
}

struct VaultEnvelope: Codable, Equatable {
    var formatVersion = 1
    var vaultID: UUID
    var kdf: KDFConfiguration
    var masterWrappedKey: SealedPayload
    var recoveryWrappedKey: SealedPayload
    var encryptedVault: SealedPayload
    var saveSequence: UInt64
    var createdAt: Date
    var updatedAt: Date
}

struct BackupEnvelope: Codable, Equatable {
    var formatVersion = 1
    var backupID: UUID
    var sourceVaultID: UUID
    var createdAt: Date
    var kdf: KDFConfiguration
    var passwordWrappedKey: SealedPayload
    var encryptedPayload: SealedPayload
}

struct MigrationDocument: Codable {
    var format: String
    var version: Int
    var exportedAt: String?
    var items: [MigrationItem]
}

struct MigrationItem: Codable {
    var id: String?
    var name: String
    var type: String
    var value: String
    var username: String?
    var website: String?
    var notes: String?
    var tags: [String]?
    var favorite: Bool?
    var updatedAt: String?
}

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all = "All items"
    case favorites = "Favorites"
    case passwords = "Passwords"
    case apiKeys = "API keys"
    case tokens = "Tokens"
    case secureNotes = "Secure notes"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .all: "list.bullet"
        case .favorites: "star"
        case .passwords: "lock"
        case .apiKeys: "key"
        case .tokens: "curlybraces"
        case .secureNotes: "note.text"
        }
    }
}

enum VaultSort: String, CaseIterable, Identifiable {
    case updated = "Recently updated"
    case name = "Name"
    case type = "Type"
    var id: String { rawValue }
}

enum VaultError: LocalizedError, Equatable {
    case noVault
    case invalidPassword
    case corruptedData
    case unsupportedVersion
    case invalidRecoveryKey
    case invalidMigration(String)
    case backupPasswordRequired
    case biometricUnavailable

    var errorDescription: String? {
        switch self {
        case .noVault: "No vault has been created."
        case .invalidPassword: "The password is incorrect or the vault was modified."
        case .corruptedData: "The encrypted data is corrupted or incomplete."
        case .unsupportedVersion: "This file was created by an unsupported Keyring version."
        case .invalidRecoveryKey: "The recovery key is invalid."
        case .invalidMigration(let reason): "The migration file is invalid: \(reason)"
        case .backupPasswordRequired: "Enter the backup password for this session."
        case .biometricUnavailable: "Touch ID is unavailable or no longer authorized."
        }
    }
}
