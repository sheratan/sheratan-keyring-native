import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor
final class VaultStore: ObservableObject {
    enum Phase: Equatable {
        case setup
        case confirmRecovery
        case locked
        case unlocked
    }

    @Published private(set) var phase: Phase
    @Published private(set) var items: [VaultItem] = []
    @Published var selectedItemID: UUID?
    @Published var lastError: String?
    @Published private(set) var pendingRecoveryKey: String?
    @Published private(set) var touchIDAvailable = false
    @Published var autoBackupEnabled: Bool {
        didSet { UserDefaults.standard.set(autoBackupEnabled, forKey: "autoBackupEnabled") }
    }
    @Published var backupFolderPath: String {
        didSet { UserDefaults.standard.set(backupFolderPath, forKey: "backupFolderPath") }
    }
    @Published var autoLockMinutes: Int {
        didSet { UserDefaults.standard.set(autoLockMinutes, forKey: "autoLockMinutes") }
    }

    private let crypto = CryptoService()
    private let files = VaultFileService()
    private let keychain = KeychainService()
    private lazy var backups = BackupService(crypto: crypto)
    private let migration = MigrationService()
    private var envelope: VaultEnvelope?
    private var vaultKey: SymmetricKey?
    private var backupPassword: String?
    private var backupTask: Task<Void, Never>?
    private var activityMonitor: Any?
    private var inactivityTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastActivity = Date()

    init() {
        autoBackupEnabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        backupFolderPath = UserDefaults.standard.string(forKey: "backupFolderPath") ?? ""
        let storedTimeout = UserDefaults.standard.integer(forKey: "autoLockMinutes")
        autoLockMinutes = storedTimeout == 0 ? 10 : storedTimeout
        phase = files.exists() ? .locked : .setup
        if let loaded = try? files.load() {
            envelope = loaded
            touchIDAvailable = keychain.hasBiometricKey(vaultID: loaded.vaultID)
        }
    }

    func createVault(masterPassword: String) throws {
        guard masterPassword.count >= 12 else {
            throw VaultError.invalidMigration("master password must contain at least 12 characters")
        }
        let vaultID = UUID()
        let configuration = KDFConfiguration(
            iterations: try crypto.calibratedIterations(password: masterPassword),
            salt: try crypto.randomData(count: 32)
        )
        let masterKey = try crypto.derivePasswordKey(password: masterPassword, configuration: configuration)
        let dataKey = SymmetricKey(data: try crypto.randomData(count: 32))
        let recoveryText = try crypto.generateRecoveryKey()
        let recoveryKey = try crypto.recoveryKey(from: recoveryText)
        let payload = VaultPayload(items: [])
        let now = Date()
        let newEnvelope = VaultEnvelope(
            vaultID: vaultID,
            kdf: configuration,
            masterWrappedKey: try crypto.seal(
                crypto.keyData(dataKey), with: masterKey, context: "Keyring Master Wrapped Key v1"
            ),
            recoveryWrappedKey: try crypto.seal(
                crypto.keyData(dataKey), with: recoveryKey, context: "Keyring Recovery Wrapped Key v1"
            ),
            encryptedVault: try crypto.seal(
                JSONEncoder.keyring.encode(payload), with: dataKey, context: "Keyring Vault Payload v1"
            ),
            saveSequence: 1,
            createdAt: now,
            updatedAt: now
        )
        try files.save(newEnvelope)
        envelope = newEnvelope
        vaultKey = dataKey
        items = []
        pendingRecoveryKey = recoveryText
        phase = .confirmRecovery
    }

    func confirmRecovery(groups: [Int: String]) -> Bool {
        guard let pendingRecoveryKey else { return false }
        let expected = pendingRecoveryKey.split(separator: "-").map(String.init)
        for (index, value) in groups {
            guard expected.indices.contains(index),
                  expected[index].caseInsensitiveCompare(value.trimmingCharacters(in: .whitespaces)) == .orderedSame
            else { return false }
        }
        self.pendingRecoveryKey = nil
        phase = .unlocked
        recordActivity()
        startSecurityMonitoring()
        return true
    }

    func unlock(password: String) throws {
        let loaded = try files.load()
        do {
            let masterKey = try crypto.derivePasswordKey(password: password, configuration: loaded.kdf)
            let keyData = try crypto.open(
                loaded.masterWrappedKey, with: masterKey, context: "Keyring Master Wrapped Key v1"
            )
            try completeUnlock(envelope: loaded, key: SymmetricKey(data: keyData))
        } catch {
            throw VaultError.invalidPassword
        }
    }

    func unlockWithTouchID() async throws {
        guard let loaded = envelope ?? (try? files.load()) else { throw VaultError.noVault }
        let keyData = try await keychain.loadBiometricKey(vaultID: loaded.vaultID)
        try completeUnlock(envelope: loaded, key: SymmetricKey(data: keyData))
    }

    func enableTouchID() throws {
        guard let envelope, let vaultKey else { throw VaultError.noVault }
        try keychain.storeBiometricKey(crypto.keyData(vaultKey), vaultID: envelope.vaultID)
        touchIDAvailable = true
    }

    func disableTouchID() {
        guard let envelope else { return }
        keychain.delete(vaultID: envelope.vaultID)
        touchIDAvailable = false
    }

    func recover(recoveryKey text: String, newPassword: String) throws -> String {
        var loaded = try files.load()
        do {
            let recoveryKey = try crypto.recoveryKey(from: text)
            let keyData = try crypto.open(
                loaded.recoveryWrappedKey,
                with: recoveryKey,
                context: "Keyring Recovery Wrapped Key v1"
            )
            let dataKey = SymmetricKey(data: keyData)
            let newRecoveryText = try crypto.generateRecoveryKey()
            let newConfiguration = KDFConfiguration(
                iterations: try crypto.calibratedIterations(password: newPassword),
                salt: try crypto.randomData(count: 32)
            )
            let newMasterKey = try crypto.derivePasswordKey(
                password: newPassword, configuration: newConfiguration
            )
            loaded.kdf = newConfiguration
            loaded.masterWrappedKey = try crypto.seal(
                keyData, with: newMasterKey, context: "Keyring Master Wrapped Key v1"
            )
            loaded.recoveryWrappedKey = try crypto.seal(
                keyData,
                with: try crypto.recoveryKey(from: newRecoveryText),
                context: "Keyring Recovery Wrapped Key v1"
            )
            loaded.updatedAt = .now
            loaded.saveSequence += 1
            try files.save(loaded)
            keychain.delete(vaultID: loaded.vaultID)
            touchIDAvailable = false
            try completeUnlock(envelope: loaded, key: dataKey)
            return newRecoveryText
        } catch {
            throw VaultError.invalidRecoveryKey
        }
    }

    func changeMasterPassword(current: String, new: String) throws {
        guard new.count >= 12, var envelope, let vaultKey else {
            throw VaultError.invalidPassword
        }
        let currentKey = try crypto.derivePasswordKey(password: current, configuration: envelope.kdf)
        _ = try crypto.open(
            envelope.masterWrappedKey, with: currentKey, context: "Keyring Master Wrapped Key v1"
        )
        let configuration = KDFConfiguration(
            iterations: try crypto.calibratedIterations(password: new),
            salt: try crypto.randomData(count: 32)
        )
        let newKey = try crypto.derivePasswordKey(password: new, configuration: configuration)
        envelope.kdf = configuration
        envelope.masterWrappedKey = try crypto.seal(
            crypto.keyData(vaultKey), with: newKey, context: "Keyring Master Wrapped Key v1"
        )
        envelope.updatedAt = .now
        envelope.saveSequence += 1
        try files.save(envelope)
        self.envelope = envelope
    }

    func rotateRecoveryKey() throws -> String {
        guard var envelope, let vaultKey else { throw VaultError.noVault }
        let text = try crypto.generateRecoveryKey()
        envelope.recoveryWrappedKey = try crypto.seal(
            crypto.keyData(vaultKey),
            with: try crypto.recoveryKey(from: text),
            context: "Keyring Recovery Wrapped Key v1"
        )
        envelope.updatedAt = .now
        envelope.saveSequence += 1
        try files.save(envelope)
        self.envelope = envelope
        return text
    }

    func lock() {
        backupTask?.cancel()
        backupTask = nil
        items.removeAll(keepingCapacity: false)
        selectedItemID = nil
        vaultKey = nil
        backupPassword = nil
        phase = files.exists() ? .locked : .setup
    }

    func add(_ item: VaultItem) throws {
        var item = item
        item.id = UUID()
        item.updatedAt = .now
        items.insert(item, at: 0)
        try persist()
    }

    func update(_ item: VaultItem) throws {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.updatedAt = .now
        items[index] = updated
        try persist()
    }

    func delete(id: UUID) throws {
        items.removeAll { $0.id == id }
        selectedItemID = nil
        try persist()
    }

    func toggleFavorite(id: UUID) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].favorite.toggle()
        items[index].updatedAt = .now
        try persist()
    }

    func copySecret(_ secret: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(secret, forType: .string)
        let changeCount = pasteboard.changeCount
        Task {
            try? await Task.sleep(for: .seconds(30))
            if pasteboard.changeCount == changeCount {
                pasteboard.clearContents()
            }
        }
    }

    func configureBackup(folder: URL, password: String) throws {
        guard password.count >= 12 else { throw VaultError.invalidPassword }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        backupFolderPath = folder.path
        backupPassword = password
        autoBackupEnabled = true
        try createBackup(in: folder, password: password)
    }

    func createManualBackup(to url: URL, password: String) throws {
        guard let envelope else { throw VaultError.noVault }
        let backup = try backups.create(
            payload: VaultPayload(items: items),
            sourceVaultID: envelope.vaultID,
            password: password
        )
        try backups.save(backup, to: url)
    }

    func verifyBackup(at url: URL, password: String) throws -> Int {
        let payload = try backups.restore(backups.load(from: url), password: password)
        return payload.items.count
    }

    func restoreBackup(at url: URL, password: String) throws {
        let payload = try backups.restore(backups.load(from: url), password: password)
        items = payload.items
        try persist()
    }

    func importMigration(from url: URL) throws -> Int {
        let imported = try migration.load(from: url)
        let existing = Set(items.map(\.id))
        items.append(contentsOf: imported.filter { !existing.contains($0.id) })
        try persist()
        return imported.count
    }

    func setBackupSessionPassword(_ password: String) {
        backupPassword = password
    }

    func recordActivity() { lastActivity = .now }

    private func completeUnlock(envelope: VaultEnvelope, key: SymmetricKey) throws {
        let plaintext = try crypto.open(
            envelope.encryptedVault, with: key, context: "Keyring Vault Payload v1"
        )
        let payload = try JSONDecoder.keyring.decode(VaultPayload.self, from: plaintext)
        guard payload.schemaVersion == 1 else { throw VaultError.unsupportedVersion }
        self.envelope = envelope
        self.vaultKey = key
        items = payload.items
        phase = .unlocked
        touchIDAvailable = keychain.hasBiometricKey(vaultID: envelope.vaultID)
        recordActivity()
        startSecurityMonitoring()
    }

    private func persist() throws {
        guard var envelope, let vaultKey else { throw VaultError.noVault }
        envelope.encryptedVault = try crypto.seal(
            JSONEncoder.keyring.encode(VaultPayload(items: items)),
            with: vaultKey,
            context: "Keyring Vault Payload v1"
        )
        envelope.updatedAt = .now
        envelope.saveSequence += 1
        try files.save(envelope)
        self.envelope = envelope
        scheduleAutomaticBackup()
    }

    private func createBackup(in folder: URL, password: String) throws {
        guard let envelope else { throw VaultError.noVault }
        let backup = try backups.create(
            payload: VaultPayload(items: items),
            sourceVaultID: envelope.vaultID,
            password: password
        )
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let url = folder.appending(path: "Keyring-\(formatter.string(from: .now)).keyringbackup")
        try backups.save(backup, to: url)
        backups.prune(directory: folder)
    }

    private func scheduleAutomaticBackup() {
        guard autoBackupEnabled,
              !backupFolderPath.isEmpty,
              let backupPassword else { return }
        backupTask?.cancel()
        backupTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            do {
                try self.createBackup(in: URL(fileURLWithPath: self.backupFolderPath), password: backupPassword)
            } catch {
                self.lastError = "Automatic backup failed: \(error.localizedDescription)"
            }
        }
    }

    private func startSecurityMonitoring() {
        guard activityMonitor == nil else { return }
        activityMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel, .mouseMoved]
        ) { [weak self] event in
            self?.recordActivity()
            return event
        }
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == .unlocked else { return }
                if Date().timeIntervalSince(self.lastActivity) >= Double(self.autoLockMinutes * 60) {
                    self.lock()
                }
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in self?.lock() }
            })
        }
    }
}
