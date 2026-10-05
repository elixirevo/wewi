import Combine
import Foundation
import WebKit

@MainActor
final class WidgetManager {
    private let store: WidgetStore
    private let preferences: AppPreferences
    private let preview: Bool
    private let websiteDataStore: WKWebsiteDataStore
    private var cancellables: Set<AnyCancellable> = []
    private var controllers: [UUID: WidgetPanelController] = [:]

    init(store: WidgetStore, preferences: AppPreferences, preview: Bool = false, websiteDataStore: WKWebsiteDataStore = .default()) {
        self.store = store
        self.preferences = preferences
        self.preview = preview
        self.websiteDataStore = websiteDataStore
        bind()
        sync(with: store.widgets)
    }

    func reload(id: UUID) {
        controllers[id]?.reload()
    }

    func cookieScope(for widget: WidgetConfig) -> WebsiteCookieScope {
        WebsiteCookieScope(urls: [widget.url, controllers[widget.id]?.currentWebsiteURL].compactMap { $0 })
    }

    private func bind() {
        store.$widgets
            .receive(on: RunLoop.main)
            .sink { [weak self] widgets in
                self?.sync(with: widgets)
            }
            .store(in: &cancellables)
    }

    private func sync(with widgets: [WidgetConfig]) {
        let enabled = widgets.filter { $0.isEnabled }
        let enabledIds = Set(enabled.map(\.id))

        for widget in enabled {
            if let existing = controllers[widget.id] {
                existing.apply(config: widget)
            } else {
                let controller = WidgetPanelController(
                    config: widget, preferences: preferences, preview: preview, websiteDataStore: websiteDataStore,
                    onFrameChanged: { [weak self] id, frame in
                        self?.store.update(id: id) { $0.frame = frame }
                    },
                    onInteractionChanged: { [weak self] id, allowsInteraction in
                        self?.store.update(id: id) { $0.allowsInteraction = allowsInteraction }
                    },
                    onScrollPositionChanged: { [weak self] id, x, y in
                        self?.store.update(id: id) {
                            $0.scrollX = x
                            $0.scrollY = y
                        }
                    },
                    onDisableRequested: { [weak self] id in
                        self?.store.update(id: id) { $0.isEnabled = false }
                    }
                )
                controllers[widget.id] = controller
                controller.show()
            }
        }

        for (id, controller) in controllers where !enabledIds.contains(id) {
            controller.hide()
            controller.close()
            controllers.removeValue(forKey: id)
        }
    }
}
