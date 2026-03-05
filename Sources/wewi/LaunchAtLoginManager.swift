import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var lastErrorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
            lastErrorMessage = nil
        } catch {
            refresh()
            lastErrorMessage = "Failed to update login item: \(error.localizedDescription)"
        }
    }
}
