import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = WidgetStore()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private lazy var manager = WidgetManager(store: store)
    private lazy var settingsWindow = SettingsWindowController(
        store: store,
        launchAtLoginManager: launchAtLoginManager
    )
    private var menuBar: MenuBarController?

    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()

        menuBar = MenuBarController(store: store, manager: manager, onOpenSettings: { [weak self] in
            self?.settingsWindow.show()
        })

        store.$widgets
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.menuBar?.refresh()
            }
            .store(in: &cancellables)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(
                title: "Quit wewi",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            NSMenuItem(
                title: "Cut",
                action: #selector(NSText.cut(_:)),
                keyEquivalent: "x"
            )
        )
        editMenu.addItem(
            NSMenuItem(
                title: "Copy",
                action: #selector(NSText.copy(_:)),
                keyEquivalent: "c"
            )
        )
        editMenu.addItem(
            NSMenuItem(
                title: "Paste",
                action: #selector(NSText.paste(_:)),
                keyEquivalent: "v"
            )
        )
        editMenu.addItem(.separator())
        editMenu.addItem(
            NSMenuItem(
                title: "Select All",
                action: #selector(NSText.selectAll(_:)),
                keyEquivalent: "a"
            )
        )
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}
