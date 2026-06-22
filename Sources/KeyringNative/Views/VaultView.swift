import SwiftUI

struct VaultView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.openSettings) private var openSettings
    @State private var filter: SidebarFilter = .all
    @State private var search = ""
    @State private var sort: VaultSort = .updated
    @State private var editingItem: VaultItem?
    @State private var showingEditor = false
    @State private var showingInspector = true

    private var displayedItems: [VaultItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.items.filter { item in
            let category: Bool = switch filter {
            case .all: true
            case .favorites: item.favorite
            case .passwords: item.type == .password
            case .apiKeys: item.type == .apiKey
            case .tokens: item.type == .token
            case .secureNotes: item.type == .secureNote
            }
            let text = [item.name, item.type.rawValue, item.username, item.website, item.notes]
                .joined(separator: " ") + " " + item.tags.joined(separator: " ")
            return category && (query.isEmpty || text.lowercased().contains(query))
        }.sorted {
            switch sort {
            case .updated: $0.updatedAt > $1.updatedAt
            case .name: $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            case .type: $0.type.rawValue < $1.type.rawValue
            }
        }
    }

    private var selectedItem: VaultItem? {
        store.items.first { $0.id == store.selectedItemID }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarFilter.allCases, selection: $filter) { value in
                Label(value.rawValue, systemImage: value.symbol)
                    .tag(value)
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button { openSettings() } label: {
                        Label("Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Button { store.lock() } label: {
                        Label("Lock Vault", systemImage: "lock")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            Table(displayedItems, selection: $store.selectedItemID) {
                TableColumn("") { item in
                    Button {
                        try? store.toggleFavorite(id: item.id)
                    } label: {
                        Image(systemName: item.favorite ? "star.fill" : "star")
                            .foregroundStyle(item.favorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .width(28)
                TableColumn("Name") { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).fontWeight(.semibold)
                        Text(item.username.isEmpty ? item.website : item.username)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("Type") { item in
                    Label(item.type.rawValue, systemImage: item.type.symbol)
                }
                TableColumn("Value") { item in
                    Text("••••••••••••\(item.value.suffix(4))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                TableColumn("Updated") { item in
                    Text(item.updatedAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $search, prompt: "Search vault")
            .navigationTitle(filter.rawValue)
            .toolbar {
                ToolbarItem {
                    Picker("Sort", selection: $sort) {
                        ForEach(VaultSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width: 170)
                }
                ToolbarItem {
                    Button {
                        editingItem = nil
                        showingEditor = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .keyboardShortcut("n")
                }
                ToolbarItem {
                    Button {
                        showingInspector.toggle()
                    } label: {
                        Label("Inspector", systemImage: "sidebar.right")
                    }
                }
            }
            .inspector(isPresented: $showingInspector) {
                if let selectedItem {
                    ItemDetailView(
                        item: selectedItem,
                        onEdit: {
                            editingItem = selectedItem
                            showingEditor = true
                        }
                    )
                    .environmentObject(store)
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
                } else {
                    ContentUnavailableView(
                        "No Item Selected",
                        systemImage: "key",
                        description: Text("Select an item to inspect its details.")
                    )
                }
            }
        }
        .onTapGesture { store.recordActivity() }
        .sheet(isPresented: $showingEditor) {
            ItemEditorView(item: editingItem)
                .environmentObject(store)
        }
    }
}

private struct ItemDetailView: View {
    @EnvironmentObject private var store: VaultStore
    let item: VaultItem
    let onEdit: () -> Void
    @State private var revealed = false
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                Label(item.type.rawValue, systemImage: item.type.symbol)
                LabeledContent("Secret") {
                    HStack {
                        if revealed {
                            Text(item.value)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text("••••••••••••••••")
                                .font(.system(.body, design: .monospaced))
                        }
                        Button { revealed.toggle() } label: {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                        }
                        Button { store.copySecret(item.value) } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    .buttonStyle(.plain)
                }
                LabeledContent("Username", value: item.username.isEmpty ? "—" : item.username)
                LabeledContent("Website", value: item.website.isEmpty ? "—" : item.website)
                LabeledContent("Tags", value: item.tags.joined(separator: ", "))
                LabeledContent("Notes", value: item.notes.isEmpty ? "—" : item.notes)
                LabeledContent("Updated") { Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened)) }
            }
            Section {
                Button("Edit Item", action: onEdit)
                Button("Delete Item", role: .destructive) { confirmingDelete = true }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(item.name)
        .confirmationDialog("Delete \(item.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                do { try store.delete(id: item.id) }
                catch { store.lastError = error.localizedDescription }
            }
        }
    }
}
