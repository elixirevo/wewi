import Foundation

enum WidgetBrowsingMode: String, Codable, CaseIterable, Identifiable {
    case automatic, mobile, tablet, desktop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .mobile: "Mobile"
        case .tablet: "Tablet"
        case .desktop: "Desktop"
        }
    }

    func device(for width: Double) -> WidgetBrowserDevice {
        switch self {
        case .mobile: .mobile
        case .tablet: .tablet
        case .desktop: .desktop
        case .automatic: width < 600 ? .mobile : width < 1024 ? .tablet : .desktop
        }
    }
}

enum WidgetBrowserDevice: Equatable {
    case mobile, tablet, desktop

    var userAgent: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let safari = os >= 26 ? os : os >= 15 ? 18 : os >= 14 ? 17 : 16
        let engine = "AppleWebKit/605.1.15 (KHTML, like Gecko)"
        switch self {
        case .desktop:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \(engine) Version/\(safari).0 Safari/605.1.15"
        case .mobile:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(safari)_0 like Mac OS X) \(engine) Version/\(safari).0 Mobile/15E148 Safari/604.1"
        case .tablet:
            return "Mozilla/5.0 (iPad; CPU OS \(safari)_0 like Mac OS X) \(engine) Version/\(safari).0 Mobile/15E148 Safari/604.1"
        }
    }
}

/// Manual mode changes apply on Save. Automatic resizing may wait for the next reload.
enum WidgetBrowsingPolicy {
    static func shouldReload(loaded: WidgetBrowserDevice?, previous: WidgetConfig, next: WidgetConfig) -> Bool {
        guard let loaded, loaded != next.browsingMode.device(for: next.frame.width) else { return false }
        return previous.browsingMode != next.browsingMode ||
            (next.browsingMode == .automatic && next.reloadOnDeviceChange)
    }
}
