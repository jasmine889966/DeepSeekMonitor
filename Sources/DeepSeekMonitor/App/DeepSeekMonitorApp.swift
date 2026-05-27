import AppKit
import SwiftUI

@main
struct DeepSeekMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = MonitorStore()

    var body: some Scene {
        WindowGroup(store.l10n.appName, id: "dashboard") {
            ContentView(store: store)
                .frame(minWidth: 1080, minHeight: 720)
                .task {
                    await store.start()
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(store.l10n.refresh) {
                    Task { await store.refreshNow() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
                .frame(width: 520)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        configureDockIcon()
    }

    private func configureDockIcon() {
        NSApp.applicationIconImage = AppIconRenderer.image(tone: .normal)
    }
}
