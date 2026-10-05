import AppKit
import WebKit
import SwiftUI
import MacAppCore
import MacAppSettings
import MacAppOnboarding
import MacAppUpdatesSparkle
import MacAppDiagnosticsSentry

@MainActor
final class AppCoordinator {
    let store: WidgetStore
    let preferences: AppPreferences
    let cookies: WebsiteCookieService
    let navigation = SettingsNavigation()
    let updates = SparkleUpdates()
    let reporting: CrashReportingPreference
    let agreement: TermsAgreementModel
    let onboardingModel: OnboardingModel
    let diagnostics: SentryDiagnostics?
    let identity = SettingsIdentity(bundle: .main, icon: NSApp.applicationIconImage,
                                    website: URL(string: "https://github.com/elixirevo/wewi"))
    let preview: Bool
    private let terms: String
    private let privacy: String
    private let login: LaunchAtLoginModel
    private let language: AppLanguageSettings
    private(set) var manager: WidgetManager?
    private(set) var started = false
    var onStart: () -> Void = {}

    init(defaults: UserDefaults, preview: Bool) throws {
        self.preview = preview
        cookies = WebsiteCookieService(dataStore: preview ? .nonPersistent() : .default())
        store = WidgetStore(userDefaults: defaults)
        preferences = AppPreferences(defaults: defaults)
        reporting = CrashReportingPreference(defaults: defaults)
        language = AppLanguageSettings(save: { defaults.set($0.rawValue, forKey: AppLocalizer.preferenceKey) })
        login = preview ? LaunchAtLoginModel(read: { .disabled }, write: { _ in }, openSettings: {}) : LaunchAtLoginModel()
        terms = try LegalDocuments.text("terms")
        privacy = try LegalDocuments.text("privacy")
        agreement = TermsAgreementModel(document: try TermsDocument(version: LegalDocuments.version,
            language: AppLocalizer.current.languageCode, changes: appText("Terms covering desktop widgets, free use, and third-party websites."), fullText: terms),
            store: TermsAcceptanceStore(defaults: defaults, key: "wewi.terms.acceptance"))
        if let configuration = try SentryDiagnosticsConfiguration.bundled(in: .module, appBundle: .main) {
            diagnostics = SentryDiagnostics(configuration: configuration)
        } else { diagnostics = nil }
        let legalTerms = terms
        let legalPrivacy = privacy
        var steps: [OnboardingStep] = [
            .welcome(message: appText("Keep your favorite websites on your desktop. wewi lives in your menu bar.")),
            .guide(id: "create", title: appText("Add a website"),
                   message: appText("Open Settings from the menu bar, choose Features, then click Add Widget. Enter a website URL, choose a size, and save. Click a widget in the list to edit it."),
                   illustration: Self.guideImage()),
            .guide(id: "arrange", title: appText("Make room for what matters"),
                   message: appText("Drag the widget header to preview its new position. Enable Snap to grid in Features to align widgets when you drop them, or leave it off for free placement. Press Esc to cancel a move. Drag the corner handle to resize."),
                   illustration: .init(Image(systemName: "rectangle.3.group"), accessibilityLabel: appText("Arrange desktop widgets"))),
            .guide(id: "controls", title: appText("Stay in control"),
                   message: appText("Use the widget header to save your scroll position, reload, lock web interaction, or disable the widget. Set automatic refresh in Features. Screen Lock does not hide private content."),
                   illustration: .init(Image(systemName: "arrow.clockwise.circle"), accessibilityLabel: appText("Widget controls"))),
            .custom(id: "privacy", title: appText("Your data and websites")) {
                VStack(spacing: 18) {
                    Text(appText("Widget settings stay on your Mac. Websites receive normal browser requests and may keep cookies. Update checks contact GitHub. Crash reporting is optional."))
                    LegalSection(terms: legalTerms, privacy: legalPrivacy)
                }.padding()
            },
            .terms(agreement)
        ]
        if diagnostics != nil {
            steps.append(.diagnostics(reporting, explanation: appText("Optional crash reports send technical error, app, OS and device information to Sentry in the United States. No usage analytics or screen recording. Changes apply after restarting. See Privacy Policy in Help & Support.")))
        }
        onboardingModel = try OnboardingModel(steps: steps, version: 1,
            store: OnboardingStore(defaults: defaults, key: "wewi.onboarding.completedVersion"))
        preferences.applyAppearance()
    }

    private static func guideImage() -> OnboardingIllustration {
        let name = "onboarding-features-" + AppLocalizer.current.languageCode
        if let url = Bundle.module.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) {
            return .init(Image(nsImage: image), accessibilityLabel: appText("Features settings with the widget list and Add Widget button"))
        }
        return .init(Image(systemName: "plus.rectangle.on.rectangle"), accessibilityLabel: appText("Add a website"))
    }

    lazy var onboarding = OnboardingWindowController(identity: identity, model: onboardingModel,
        autosaveName: preview ? "wewi.Preview.Onboarding" : "wewi.Onboarding",
        onFinish: { [weak self] in self?.startFeatures(showSettings: true) },
        onDismiss: { [weak self] in self?.startFeatures(showSettings: true) })
    lazy var termsWindow = TermsAgreementWindowController(identity: identity, model: agreement,
        autosaveName: "wewi.Terms", onAccepted: { [weak self] in self?.startFeatures() })
    lazy var pages: SettingsPages = makePages()
    private func makePages() -> SettingsPages {
        // IDs are constants, so invalid configuration is a programming error.
        try! SettingsPages([
            .builtIn(.general),
            .custom(id: "features", title: appText("Features"), symbol: "display", color: Color(red: 0.30, green: 0.68, blue: 0.94)) { [self] in
                WidgetSettingsContent(store: store, preferences: preferences, cookies: cookies,
                    cookieScope: { [weak self] widget in
                        self?.manager?.cookieScope(for: widget) ?? WebsiteCookieScope(urls: [widget.url].compactMap { $0 })
                    }, reload: { [weak self] in self?.manager?.reload(id: $0) })
            },
            .builtIn(.updates), .support, .builtIn(.about)
        ])
    }
    lazy var support = try! SupportSettingsModel(diagnostics: .init(identity: identity), links: [
        try! SupportLink(.help, url: URL(string: "https://github.com/elixirevo/wewi#readme")!),
        try! SupportLink(.contact, url: URL(string: "mailto:elixirevo@gmail.com")!),
        try! SupportLink(.reportIssue, url: URL(string: "https://github.com/elixirevo/wewi/issues")!)
    ], showOnboarding: { [weak self] in
        do { try self?.onboarding.showForReview() } catch { NSAlert(error: error).runModal() }
    })
    lazy var reset = try! SettingsResetModel(actions: [
        .init(id: "appearance", title: appText("Appearance"),
              detail: appText("Restore appearance to System. Widgets, website data, login settings, and consent records are kept.")) { [weak self] in
            self?.preferences.restoreAppearance()
        }
    ])
    lazy var settingsWindow = MacAppSettings.SettingsWindowController(title: "wewi", autosaveName: preview ? "wewi.Preview.Settings" : "wewi.Settings", navigation: navigation) { [self] in
        AppSettingsView(identity: identity, navigation: navigation, shortcuts: ShortcutSettingsModel(),
            permissions: PermissionSettingsModel(), updates: updates.settings, language: language,
            launchAtLogin: login, pages: pages, support: support, reset: reset,
            supportContent: { AnyView(LegalSection(terms: self.terms, privacy: self.privacy)) }) {
                GeneralContent(preferences: self.preferences, reporting: self.diagnostics == nil ? nil : self.reporting)
        }
    }

    // Explicit offline fixture for exercising real window dragging without consent or network activity.
    func showPlacementPreview() {
        guard preview, let area = NSScreen.main?.visibleFrame else { return }
        store.add(WidgetConfig(name: "Placement preview", urlString: "https://example.com",
            frame: .init(x: area.minX + 48, y: area.minY + 96, width: 360, height: 260)))
        manager = WidgetManager(store: store, preferences: preferences, preview: true, websiteDataStore: cookies.dataStore)
    }

    func begin() {
        if onboardingModel.completedVersion < onboardingModel.version {
            onboarding.showIfNeeded()
        } else if !termsWindow.showIfNeeded() { startFeatures() }
    }
    func startFeatures(showSettings: Bool = false) {
        guard agreement.allowsAppUse else { return }
        if !started {
            started = true
            if !preview {
                manager = WidgetManager(store: store, preferences: preferences, websiteDataStore: cookies.dataStore)
                do { try diagnostics?.startIfConsented(reporting) } catch { NSAlert(error: error).runModal() }
                do { try updates.start() } catch { NSAlert(error: error).runModal() }
            }
            onStart()
        }
        if showSettings { show(page: .custom("features")) }
    }
    func show(page: SettingsPageID? = nil) {
        guard preview || agreement.allowsAppUse else { begin(); return }
        navigation.configure(pages)
        if let page { settingsWindow.show(pageID: page) } else { settingsWindow.show() }
    }
    func reopen() {
        if !started { begin() } else { show() }
    }
}

private struct GeneralContent: View {
    @ObservedObject var preferences: AppPreferences
    let reporting: CrashReportingPreference?
    var body: some View {
        SettingsSection(appText("Appearance")) {
            SettingsPicker(appText("Appearance"), selection: $preferences.appearance) {
                Text(appText("System")).tag(AppPreferences.Appearance.system)
                Text(appText("Light")).tag(AppPreferences.Appearance.light)
                Text(appText("Dark")).tag(AppPreferences.Appearance.dark)
            }
        }
        SettingsSection(appText("Menu Bar")) {
            SettingsToggle(appText("Show menu bar icon"), detail: appText("The menu bar keeps wewi accessible while it runs in the background."), isOn: .constant(true)).disabled(true)
        }
        if let reporting { DiagnosticsSettingsSection(preference: reporting) }
    }
}
