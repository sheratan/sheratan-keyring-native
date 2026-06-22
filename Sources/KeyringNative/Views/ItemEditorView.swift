import SwiftUI

struct ItemEditorView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    private let original: VaultItem?
    @State private var draft: VaultItem
    @State private var tagsText: String

    init(item: VaultItem?) {
        original = item
        let value = item ?? .empty
        _draft = State(initialValue: value)
        _tagsText = State(initialValue: value.tags.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(original == nil ? "Add Item" : "Edit Item")
                .font(.title.bold())
            Form {
                TextField("Name", text: $draft.name)
                Picker("Type", selection: $draft.type) {
                    ForEach(CredentialType.allCases) { Text($0.rawValue).tag($0) }
                }
                SecureField("Secret value", text: $draft.value)
                TextField("Username", text: $draft.username)
                TextField("Website", text: $draft.website)
                TextField("Tags", text: $tagsText, prompt: Text("work, production"))
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...7)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(original == nil ? "Add to Vault" : "Save Changes") {
                    draft.tags = tagsText.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    do {
                        if original == nil { try store.add(draft) }
                        else { try store.update(draft) }
                        dismiss()
                    } catch {
                        store.lastError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || draft.value.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
