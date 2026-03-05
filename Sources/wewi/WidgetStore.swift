import Combine
import Foundation

@MainActor
final class WidgetStore: ObservableObject {
    @Published private(set) var widgets: [WidgetConfig] = []

    private let defaultsKey = "wewi.widgets.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func add(_ widget: WidgetConfig) {
        widgets.append(widget)
        save()
    }

    func remove(id: UUID) {
        widgets.removeAll { $0.id == id }
        save()
    }

    func update(_ widget: WidgetConfig) {
        guard let idx = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[idx] = widget
        save()
    }

    func update(id: UUID, _ mutate: (inout WidgetConfig) -> Void) {
        guard let idx = widgets.firstIndex(where: { $0.id == id }) else { return }
        mutate(&widgets[idx])
        save()
    }

    private func load() {
        guard let data = userDefaults.data(forKey: defaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([WidgetConfig].self, from: data)
            let migrated = decoded.map { widget in
                var updated = widget
                if updated.name == "Untitled" {
                    updated.name = ""
                }
                return updated
            }
            widgets = migrated
            if migrated != decoded {
                save()
            }
        } catch {
            widgets = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(widgets)
            userDefaults.set(data, forKey: defaultsKey)
        } catch {
            assertionFailure("Failed to save widgets: \(error)")
        }
    }
}
