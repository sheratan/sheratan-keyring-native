import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: VaultStore

    var body: some View {
        Group {
            switch store.phase {
            case .setup, .confirmRecovery:
                SetupView()
            case .locked:
                UnlockView()
            case .unlocked:
                VaultView()
            }
        }
        .alert(
            "Keyring",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            )
        ) {
            Button("OK") { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}
