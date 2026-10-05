import XCTest
import AppKit
import MacAppCore
import MacAppDiagnosticsSentry
import MacAppOnboarding
@testable import wewi

final class IntegrationTests: XCTestCase {
    @MainActor func testExistingWidgetsSurviveUIAndAppearanceReset() throws {
        let domain = "wewi.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let widget = WidgetConfig(name: "Dashboard", urlString: "https://example.com", frame: .init(x: 12, y: 34, width: 480, height: 320), scrollY: 125)
        let data = try JSONEncoder().encode([widget])
        defaults.set(data, forKey: "wewi.widgets.v1")
        defaults.set(Data("receipt".utf8), forKey: "wewi.terms.acceptance")
        defaults.set(1, forKey: "wewi.onboarding.completedVersion")
        defaults.set(true, forKey: CrashReportingPreference.defaultKey)
        let store = WidgetStore(userDefaults: defaults)
        XCTAssertEqual(store.widgets, [widget])
        _ = NSApplication.shared
        let preferences = AppPreferences(defaults: defaults)
        preferences.restoreAppearance()
        XCTAssertEqual(defaults.data(forKey: "wewi.widgets.v1"), data)
        XCTAssertEqual(defaults.data(forKey: "wewi.terms.acceptance"), Data("receipt".utf8))
        XCTAssertTrue(defaults.bool(forKey: CrashReportingPreference.defaultKey))
        XCTAssertEqual(defaults.integer(forKey: "wewi.onboarding.completedVersion"), 1)
    }
    @MainActor func testTermsGateAndReviewDoNotConflateConsentWithCompletion() throws {
        var receipt: TermsAcceptance?
        var completed = 0
        let terms = TermsAgreementModel(document: try TermsDocument(version: LegalDocuments.version, language: "en", changes: "Initial terms", fullText: LegalDocuments.text("terms", language: "en")), store: .init(read: { receipt }, write: { receipt = $0 }))
        let reporting = CrashReportingPreference(activeEnabled: false, save: { _ in XCTFail("Unrequested crash consent") })
        let model = try OnboardingModel(steps: [.welcome(message: "Welcome"), .terms(terms), .diagnostics(reporting)], store: .init(readCompletedVersion: { completed }, writeCompletedVersion: { completed = $0 }))
        XCTAssertFalse(terms.allowsAppUse)
        model.advance()
        XCTAssertFalse(model.canAdvance)
        terms.isAcknowledged = true
        model.advance()
        XCTAssertTrue(terms.allowsAppUse)
        XCTAssertEqual(completed, 0)
        model.advance()
        XCTAssertEqual(completed, 1)
        let savedReceipt = receipt
        let review = try model.makeReviewModel()
        for _ in 0..<review.steps.count { review.advance() }
        XCTAssertEqual(receipt, savedReceipt)
        XCTAssertEqual(completed, 1)
        XCTAssertFalse(reporting.selection)
        let changed = TermsAgreementModel(document: try TermsDocument(version: "future", language: "en", changes: "Changed", fullText: "New terms"), store: .init(read: { receipt }, write: { receipt = $0 }))
        XCTAssertFalse(changed.allowsAppUse)
    }
    func testLegalResourcesAreCompleteInBothLanguages() throws {
        for language in ["en", "ko"] {
            for document in ["terms", "privacy"] {
                let text = try LegalDocuments.text(document, language: language)
                XCTAssertTrue(text.contains("elixirevo@gmail.com"))
                XCTAssertTrue(text.contains(LegalDocuments.version))
                XCTAssertFalse(text.contains("{{"))
                XCTAssertGreaterThan(text.count, 2000)
            }
        }
    }
    @MainActor func testCrashReportingRequiresNextLaunchAndDoesNotInitializeWhenOff() throws {
        var saved = false
        let preference = CrashReportingPreference(activeEnabled: false, save: { saved = $0 })
        let service = SentryDiagnostics(configuration: try .init(dsn: "https://public@example.invalid/1", appIdentifier: "com.elixirevo.wewi", version: "test", build: "0"))
        preference.select(true)
        XCTAssertTrue(saved)
        XCTAssertTrue(preference.requiresRestart)
        try service.startIfConsented(preference)
        XCTAssertFalse(service.isRunning)
        let url = try XCTUnwrap(Bundle.module.url(forResource: "SentryConfiguration", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(config["appIdentifier"] as? String, "com.elixirevo.wewi")
        XCTAssertTrue((config["dsn"] as? String)?.contains(".ingest.us.sentry.io/") == true)
    }
    func testSavingEditsPreservesConcurrentDesktopChanges() {
        let original = WidgetConfig(name: "Original", urlString: "https://example.com", frame: .init(x: 80, y: 80, width: 480, height: 320))
        var edited = original
        edited.name = "Renamed"
        edited.frame.width = 640
        var current = original
        current.frame.x = 240
        current.frame.height = 400
        current.scrollY = 180
        current.isEnabled = false
        let merged = WidgetEdits.merging(original: original, edited: edited, current: current)
        XCTAssertEqual(merged.name, "Renamed")
        XCTAssertEqual(merged.frame.width, 640)
        XCTAssertEqual(merged.frame.x, 240)
        XCTAssertEqual(merged.frame.height, 400)
        XCTAssertEqual(merged.scrollY, 180)
        XCTAssertFalse(merged.isEnabled)
        edited.urlString = "https://example.com/new"
        let changedURL = WidgetEdits.merging(original: original, edited: edited, current: current)
        XCTAssertEqual(changedURL.scrollY, 0)
        XCTAssertEqual(changedURL.urlString, edited.urlString)
    }
    func testWidgetURLValidation() {
        XCTAssertTrue(WidgetInput.validURL("https://example.com/dashboard"))
        XCTAssertTrue(WidgetInput.validURL(" http://localhost:8080 "))
        XCTAssertFalse(WidgetInput.validURL("javascript:alert(1)"))
        XCTAssertFalse(WidgetInput.validURL("file:///etc/passwd"))
        XCTAssertFalse(WidgetInput.validURL("https://"))
    }
}
