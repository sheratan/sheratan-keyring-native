import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var password = ""
    @State private var showingRecovery = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            Text("Keyring is locked")
                .font(.largeTitle.bold())
            SecureField("Master password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)
                .onSubmit(unlock)

            Button("Unlock", action: unlock)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(password.isEmpty)

            if store.touchIDAvailable {
                Button("Unlock with Touch ID") {
                    Task {
                        do { try await store.unlockWithTouchID() }
                        catch { store.lastError = error.localizedDescription }
                    }
                }
            }

            Button("Use Recovery Key") { showingRecovery = true }
                .buttonStyle(.link)
        }
        .padding(44)
        .sheet(isPresented: $showingRecovery) {
            RecoveryView()
                .environmentObject(store)
        }
    }

    private func unlock() {
        do { try store.unlock(password: password) }
        catch { store.lastError = error.localizedDescription }
        password = ""
    }
}

private struct RecoveryView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryKey = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var replacementKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(replacementKey == nil ? "Recover Vault" : "New Recovery Key")
                .font(.title.bold())
            if let replacementKey {
                Text("Your previous recovery key is now invalid. Save this replacement:")
                Text(replacementKey)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            } else {
                TextField("Recovery key", text: $recoveryKey)
                SecureField("New master password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmation)
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button("Recover") {
                        guard newPassword == confirmation, newPassword.count >= 12 else {
                            store.lastError = "New passwords must match and contain at least 12 characters."
                            return
                        }
                        do {
                            replacementKey = try store.recover(
                                recoveryKey: recoveryKey, newPassword: newPassword
                            )
                        } catch {
                            store.lastError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(28)
        .frame(width: 540)
    }
}
