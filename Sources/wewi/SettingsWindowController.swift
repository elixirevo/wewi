import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: WidgetStore
    private let launchAtLoginManager: LaunchAtLoginManager
    private var windowController: NSWindowController?

    init(store: WidgetStore, launchAtLoginManager: LaunchAtLoginManager) {
        self.store = store
        self.launchAtLoginManager = launchAtLoginManager
        super.init()
    }

    func show() {
        let controller = ensureWindowController()

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        guard closingWindow == windowController?.window else { return }
        windowController = nil
    }

    private func ensureWindowController() -> NSWindowController {
        if let windowController {
            return windowController
        }

        let view = SettingsView(store: store, launchAtLoginManager: launchAtLoginManager)
        let hostingController = NSHostingController(rootView: view)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 980, height: 682),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "wewi Settings"
        newWindow.contentViewController = hostingController
        newWindow.setContentSize(NSSize(width: 980, height: 682))
        newWindow.minSize = NSSize(width: 980, height: 682)
        newWindow.maxSize = NSSize(width: 980, height: 682)
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()

        let created = NSWindowController(window: newWindow)
        windowController = created
        return created
    }
}
