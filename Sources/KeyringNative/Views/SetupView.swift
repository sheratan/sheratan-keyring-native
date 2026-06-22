import AppKit
import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var password = ""
    @State private var confirmation = ""
    @State private var groupAnswers: [Int: String] = [:]
    private let confirmationIndices = [1, 7, 13]

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            if store.phase == .setup {
                createForm
            } else {
                recoveryConfirmation
            }
        }
        .frame(maxWidth: 520)
        .padding(44)
    }

    private var createForm: some View {
        VStack(spacing: 18) {
            Text("Create your encrypted vault")
                .font(.largeTitle.bold())
            Text("Your master password never leaves this Mac. If you lose both it and your recovery key, the vault cannot be recovered.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            SecureField("Master password (12+ characters)", text: $password)
                .textFieldStyle(.roundedBorder)
            SecureField("Confirm master password", text: $confirmation)
                .textFieldStyle(.roundedBorder)

            Button("Create Vault") {
                guard password == confirmation else {
                    store.lastError = "The passwords do not match."
                    return
                }
                do { try store.createVault(masterPassword: password) }
                catch { store.lastError = error.localizedDescription }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(password.count < 12 || confirmation.isEmpty)
        }
    }

    private var recoveryConfirmation: some View {
        VStack(spacing: 18) {
            Text("Save your recovery key")
                .font(.largeTitle.bold())
            Text("Print or write this key down and store it away from your Mac. It is shown only during setup.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text(store.pendingRecoveryKey ?? "")
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button("Copy Recovery Key") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.pendingRecoveryKey ?? "", forType: .string)
                }
                Button("Print") { printRecoveryKey() }
            }

            Text("Confirm these groups to continue")
                .font(.headline)
            HStack {
                ForEach(confirmationIndices, id: \.self) { index in
                    TextField("Group \(index + 1)", text: Binding(
                        get: { groupAnswers[index] ?? "" },
                        set: { groupAnswers[index] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            Button("I Saved My Recovery Key") {
                if !store.confirmRecovery(groups: groupAnswers) {
                    store.lastError = "One or more recovery-key groups are incorrect."
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(groupAnswers.count != confirmationIndices.count)
        }
    }

    private func printRecoveryKey() {
        let text = NSAttributedString(
            string: "KEYRING RECOVERY KEY\n\n\(store.pendingRecoveryKey ?? "")\n\nKeep this key private and offline.",
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)]
        )
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 700))
        view.textStorage?.setAttributedString(text)
        view.printView(nil)
    }
}
