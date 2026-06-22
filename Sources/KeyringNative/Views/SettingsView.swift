import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var backupPassword = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var replacementRecoveryKey: String?
    @State private var status = ""

    var body: some View {
        TabView {
            Form {
                Picker("Auto-lock after", selection: $store.autoLockMinutes) {
                    ForEach([1, 5, 10, 15, 30, 60], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                Toggle("Allow Touch ID unlock", isOn: Binding(
                    get: { store.touchIDAvailable },
                    set: { enabled in
                        do {
                            if enabled { try store.enableTouchID() }
                            else { store.disableTouchID() }
                        } catch { store.lastError = error.localizedDescription }
                    }
                ))
                Button("Lock Now") { store.lock() }
            }
            .formStyle(.grouped)
            .tabItem { Label("Security", systemImage: "lock.shield") }

            Form {
                SecureField("Backup password (12+ characters)", text: $backupPassword)
                LabeledContent("Folder", value: store.backupFolderPath.isEmpty ? "Not configured" : store.backupFolderPath)
                HStack {
                    Button("Configure Automatic Backups") { configureBackups() }
                    Button("Export Backup") { exportBackup() }
                    Button("Verify Backup") { verifyBackup() }
                    Button("Restore Backup") { restoreBackup() }
                }
                Text("Retention: one backup per day for 30 days and one per month for 12 months.")
                    .foregroundStyle(.secondary)
                if !status.isEmpty { Text(status).foregroundStyle(.secondary) }
            }
            .formStyle(.grouped)
            .tabItem { Label("Backups", systemImage: "externaldrive") }

            Form {
                SecureField("Current master password", text: $currentPassword)
                SecureField("New master password", text: $newPassword)
                Button("Change Master Password") {
                    do {
                        try store.changeMasterPassword(current: currentPassword, new: newPassword)
                        currentPassword = ""
                        newPassword = ""
                        status = "Master password changed."
                    } catch { store.lastError = error.localizedDescription }
                }
                Button("Generate New Recovery Key") {
                    do { replacementRecoveryKey = try store.rotateRecoveryKey() }
                    catch { store.lastError = error.localizedDescription }
                }
                if let replacementRecoveryKey {
                    Text("Save this key now. The previous key is invalid:")
                    Text(replacementRecoveryKey)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Credentials", systemImage: "key") }

            Form {
                Text("Import the versioned plaintext migration JSON exported by the browser prototype. It is encrypted immediately after validation.")
                    .foregroundStyle(.secondary)
                Button("Import Browser Migration") { importMigration() }
            }
            .formStyle(.grouped)
            .tabItem { Label("Migration", systemImage: "arrow.right.doc.on.clipboard") }
        }
        .frame(width: 720, height: 390)
        .padding()
    }

    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseFile(types: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types.compactMap { .init(filenameExtension: $0) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func configureBackups() {
        guard let folder = chooseFolder() else { return }
        do {
            try store.configureBackup(folder: folder, password: backupPassword)
            status = "Automatic backups enabled."
        } catch { store.lastError = error.localizedDescription }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Keyring-\(Date.now.formatted(.iso8601.year().month().day())).keyringbackup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.createManualBackup(to: url, password: backupPassword)
            status = "Backup exported and encrypted."
        } catch { store.lastError = error.localizedDescription }
    }

    private func verifyBackup() {
        guard let url = chooseFile(types: ["keyringbackup"]) else { return }
        do {
            let count = try store.verifyBackup(at: url, password: backupPassword)
            status = "Backup verified: \(count) items."
        } catch { store.lastError = error.localizedDescription }
    }

    private func restoreBackup() {
        guard let url = chooseFile(types: ["keyringbackup"]) else { return }
        let alert = NSAlert()
        alert.messageText = "Replace the current vault?"
        alert.informativeText = "The backup will be fully verified before the current encrypted vault is replaced."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try store.restoreBackup(at: url, password: backupPassword)
            status = "Backup restored."
        } catch { store.lastError = error.localizedDescription }
    }

    private func importMigration() {
        guard let url = chooseFile(types: ["json"]) else { return }
        do {
            let count = try store.importMigration(from: url)
            status = "Imported and encrypted \(count) records. Move the plaintext file to Trash."
        } catch { store.lastError = error.localizedDescription }
    }
}
