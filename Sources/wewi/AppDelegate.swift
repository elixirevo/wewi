import AppKit
import MacAppLifecycle
import MacAppMainMenu
import MacAppMenuBar
import MacAppSettings

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var mainMenu: MainMenuController?
    private var menuBar: MacAppMenuBar.MenuBarController?
    private var previewDomain: String?
    lazy var lifecycle = AppLifecycleController(mode: .accessory, reopen: .custom { [weak self] _ in
        self?.coordinator?.reopen()
    })

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let preview = CommandLine.arguments.contains("--preview")
            let defaults: UserDefaults
            if preview {
                let domain = "com.elixirevo.wewi.preview." + UUID().uuidString
                previewDomain = domain
                defaults = UserDefaults(suiteName: domain)!
            } else { defaults = .standard }
            let app = try AppCoordinator(defaults: defaults, preview: preview)
            coordinator = app
            app.onStart = { [weak self] in self?.installStatusMenu() }
            mainMenu = try MainMenuController(configuration: .init(appName: "wewi",
                settings: { [weak app] in app?.show() },
                about: { [weak app] in app?.show(page: .builtIn(.about)) },
                help: { [weak app] in app?.show(page: .support) },
                sidebar: .sidebar(isVisible: { [weak app] in app?.navigation.isSidebarVisible == true },
                    isEnabled: { [weak app] in
                        guard let app, app.preview || app.agreement.allowsAppUse,
                              let window = app.settingsWindow.window else { return false }
                        return NSApp.keyWindow === window && window.attachedSheet == nil
                    }, toggle: { [weak app] in app?.navigation.toggleSidebar() })))
            mainMenu?.install()
            if preview, let index = CommandLine.arguments.firstIndex(of: "--page"), CommandLine.arguments.indices.contains(index + 1) {
                let page = CommandLine.arguments[index + 1]
                app.show(page: page == "features" ? .custom("features") : page == "support" ? .support : .builtIn(SettingsCategory(rawValue: page) ?? .general))
            } else { app.begin() }
            if preview && CommandLine.arguments.contains("--placement-demo") { app.showPlacementPreview() }
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
        }
    }

    private func installStatusMenu() {
        guard menuBar == nil, let app = coordinator, app.agreement.allowsAppUse else { return }
        do {
            var items: [MenuBarItem] = [
                .command(.settings(action: { [weak app] in app?.show() })),
                .command(.init(id: "widgets", title: appText("Manage Widgets…"), action: { [weak app] in app?.show(page: .custom("features")) })),
                .separator
            ]
            items += MenuBarCommand.updateItems(distribution: .direct, manualState: { [weak app] in
                .init(isEnabled: app?.updates.settings.canCheckForUpdates == true)
            }, check: { [weak app] in Task { await app?.updates.settings.checkForUpdates() } }, automaticState: { [weak app] in
                .init(isEnabled: app?.updates.settings.canChangeAutomaticChecks == true,
                      checkState: app?.updates.settings.automaticChecksEnabled == true ? .on : .off)
            }, toggleAutomatic: { [weak app] in app?.updates.settings.toggleAutomaticChecks() })
            items += [.separator, .command(.quit(appName: "wewi") { NSApp.terminate(nil) })]
            let icon: MenuBarIcon
            if let url = Bundle.main.url(forResource: "menubar-icon", withExtension: "png"), let image = NSImage(contentsOf: url) {
                icon = .templateImage(image)
            } else { icon = .systemSymbol("globe") }
            menuBar = try MacAppMenuBar.MenuBarController(configuration: .init(id: "com.elixirevo.wewi.status",
                accessibilityLabel: "wewi", icon: icon, items: items))
            menuBar?.install()
        } catch { NSAlert(error: error).runModal() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        lifecycle.handleReopen(hasVisibleWindows: flag)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        lifecycle.shouldTerminateAfterLastWindowClosed
    }
    func applicationWillTerminate(_ notification: Notification) {
        menuBar?.remove()
        mainMenu?.uninstall()
        if let previewDomain { UserDefaults.standard.removePersistentDomain(forName: previewDomain) }
    }
}
