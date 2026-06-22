import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct KeyringNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = VaultStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1220, height: 780)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Lock Vault") { store.lock() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    .disabled(store.phase != .unlocked)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
