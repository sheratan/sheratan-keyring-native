import Foundation

struct MigrationService {
    func load(from url: URL) throws -> [VaultItem] {
        let data = try Data(contentsOf: url)
        guard data.count <= 10_000_000 else {
            throw VaultError.invalidMigration("file exceeds 10 MB")
        }
        let document = try JSONDecoder.keyring.decode(MigrationDocument.self, from: data)
        guard document.format == "keyring-browser-migration", document.version == 1 else {
            throw VaultError.unsupportedVersion
        }
        guard document.items.count <= 10_000 else {
            throw VaultError.invalidMigration("too many records")
        }
        var usedIDs = Set<UUID>()
        return try document.items.map { item in
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.name.count <= 500,
                  item.value.count <= 100_000,
                  (item.website?.count ?? 0) <= 4_000,
                  (item.tags?.count ?? 0) <= 100 else {
                throw VaultError.invalidMigration("one or more fields are invalid")
            }
            let id = item.id.flatMap(UUID.init(uuidString:)) ?? UUID()
            guard usedIDs.insert(id).inserted else {
                throw VaultError.invalidMigration("duplicate record IDs")
            }
            let type = CredentialType(rawValue: item.type) ?? .secureNote
            let updated = item.updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now
            return VaultItem(
                id: id,
                name: item.name,
                type: type,
                value: item.value,
                username: item.username ?? "",
                website: item.website ?? "",
                notes: item.notes ?? "",
                tags: item.tags ?? [],
                favorite: item.favorite ?? false,
                updatedAt: updated
            )
        }
    }
}
