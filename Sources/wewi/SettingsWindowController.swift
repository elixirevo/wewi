import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let store: WidgetStore
    private let launchAtLoginManager: LaunchAtLoginManager
    private var window: NSWindow?

    init(store: WidgetStore, launchAtLoginManager: LaunchAtLoginManager) {
        self.store = store
        self.launchAtLoginManager = launchAtLoginManager
    }

    func show() {
        if window == nil {
            let view = SettingsView(store: store, launchAtLoginManager: launchAtLoginManager)
            let hosting = NSHostingView(rootView: view)

            let newWindow = NSWindow(
                contentRect: NSRect(x: 80, y: 80, width: 980, height: 682),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "wewi Settings"
            newWindow.contentView = hosting
            newWindow.setContentSize(NSSize(width: 980, height: 682))
            newWindow.minSize = NSSize(width: 980, height: 682)
            newWindow.maxSize = NSSize(width: 980, height: 682)
            newWindow.center()
            window = newWindow
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
