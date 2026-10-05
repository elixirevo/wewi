import AppKit
import MacAppCore
import SwiftUI

func appText(_ key: String) -> String {
    AppLocalizer.current.string(key, bundle: .module)
}

@MainActor
final class AppPreferences: ObservableObject {
    enum Appearance: String, CaseIterable { case system, light, dark }
    private let defaults: UserDefaults
    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: "wewi.appearance"); applyAppearance() }
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: "wewi.appearance") ?? "") ?? .system
    }
    func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
    func restoreAppearance() { appearance = .system }
}
