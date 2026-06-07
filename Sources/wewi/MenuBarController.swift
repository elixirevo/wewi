import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let store: WidgetStore
    private let manager: WidgetManager
    private let statusItem: NSStatusItem
    private let onOpenSettings: () -> Void

    init(store: WidgetStore, manager: WidgetManager, onOpenSettings: @escaping () -> Void) {
        self.store = store
        self.manager = manager
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
    }

    func refresh() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        if store.widgets.isEmpty {
            let empty = NSMenuItem(title: "No Widgets", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for widget in store.widgets {
                let title = widget.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No Name" : widget.name
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let sub = NSMenu()

                let toggleTitle = widget.isEnabled ? "Disable" : "Enable"
                let toggle = NSMenuItem(title: toggleTitle, action: #selector(toggleWidget(_:)), keyEquivalent: "")
                toggle.target = self
                toggle.representedObject = widget.id.uuidString
                sub.addItem(toggle)

                let reload = NSMenuItem(title: "Reload", action: #selector(reloadWidget(_:)), keyEquivalent: "")
                reload.target = self
                reload.representedObject = widget.id.uuidString
                reload.isEnabled = widget.isEnabled
                sub.addItem(reload)

                let remove = NSMenuItem(title: "Delete", action: #selector(removeWidget(_:)), keyEquivalent: "")
                remove.target = self
                remove.representedObject = widget.id.uuidString
                sub.addItem(remove)

                item.submenu = sub
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func configure() {
        if let button = statusItem.button {
            if let image = menuBarIconImage() {
                button.image = image
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.title = "wewi"
            }
        }
        refresh()
    }

    private func menuBarIconImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "menubar-icon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }

        for (resourceName, resourceExtension) in [("AppIcon", "icns"), ("AppIcon", "png"), ("icon", "png")] {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
                  let image = NSImage(contentsOf: url) else {
                continue
            }

            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            return image
        }

        return nil
    }

    @objc private func openSettings(_ sender: Any?) {
        // Avoid presenting windows while NSStatusBar menu tracking is still unwinding.
        DispatchQueue.main.async { [onOpenSettings] in
            onOpenSettings()
        }
    }

    @objc private func toggleWidget(_ sender: NSMenuItem) {
        guard let id = uuid(from: sender) else { return }
        store.update(id: id) { widget in
            widget.isEnabled.toggle()
        }
        refresh()
    }

    @objc private func reloadWidget(_ sender: NSMenuItem) {
        guard let id = uuid(from: sender) else { return }
        manager.reload(id: id)
    }

    @objc private func removeWidget(_ sender: NSMenuItem) {
        guard let id = uuid(from: sender) else { return }
        store.remove(id: id)
        refresh()
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func uuid(from item: NSMenuItem) -> UUID? {
        guard let raw = item.representedObject as? String else { return nil }
        return UUID(uuidString: raw)
    }
}
