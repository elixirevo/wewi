import Combine
import Foundation

@MainActor
final class WidgetManager {
    private let store: WidgetStore
    private var cancellables: Set<AnyCancellable> = []
    private var controllers: [UUID: WidgetPanelController] = [:]

    init(store: WidgetStore) {
        self.store = store
        bind()
        sync(with: store.widgets)
    }

    func reload(id: UUID) {
        controllers[id]?.reload()
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
                    config: widget,
                    onFrameChanged: { [weak self] id, frame in
                        self?.store.update(id: id) { $0.frame = frame }
                    },
                    onInteractionChanged: { [weak self] id, allowsInteraction in
                        self?.store.update(id: id) { $0.allowsInteraction = allowsInteraction }
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
