import XCTest
import WebKit
@testable import wewi

final class WidgetBrowsingTests: XCTestCase {
    private func widget() -> WidgetConfig {
        WidgetConfig(name: "Test", urlString: "https://example.com", frame: .init(x: 10, y: 20, width: 480, height: 320))
    }

    func testLegacyWidgetsKeepDesktopAndNewSettingsRoundTrip() throws {
        var sample = widget()
        XCTAssertEqual(sample.browsingMode, .automatic)
        XCTAssertFalse(sample.reloadOnDeviceChange)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(sample)) as? [String: Any])
        legacy.removeValue(forKey: "browsingMode")
        legacy.removeValue(forKey: "reloadOnDeviceChange")
        let restored = try JSONDecoder().decode(WidgetConfig.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored.browsingMode, .desktop)
        XCTAssertFalse(restored.reloadOnDeviceChange)
        XCTAssertEqual(restored.frame, sample.frame)
        legacy["browsingMode"] = "unknown-future-mode"
        XCTAssertEqual(try JSONDecoder().decode(WidgetConfig.self, from: JSONSerialization.data(withJSONObject: legacy)).browsingMode, .desktop)
        sample.browsingMode = .tablet
        sample.reloadOnDeviceChange = true
        XCTAssertEqual(try JSONDecoder().decode(WidgetConfig.self, from: JSONEncoder().encode(sample)), sample)
    }

    func testWidthBoundariesAndManualOverride() {
        XCTAssertEqual(WidgetBrowsingMode.automatic.device(for: 599.5), .mobile)
        XCTAssertEqual(WidgetBrowsingMode.automatic.device(for: 600), .tablet)
        XCTAssertEqual(WidgetBrowsingMode.automatic.device(for: 1023.5), .tablet)
        XCTAssertEqual(WidgetBrowsingMode.automatic.device(for: 1024), .desktop)
        XCTAssertEqual(WidgetBrowsingMode.desktop.device(for: 180), .desktop)
        XCTAssertEqual(WidgetBrowsingMode.mobile.device(for: 1400), .mobile)
        XCTAssertEqual(WidgetBrowsingMode.tablet.device(for: 180), .tablet)
    }

    func testResizingWaitsForReloadUnlessOptedInAndDoesNotReloadWithinRange() {
        let previous = widget()
        var next = previous
        next.frame.width = 800
        XCTAssertFalse(WidgetBrowsingPolicy.shouldReload(loaded: .mobile, previous: previous, next: next))
        next.reloadOnDeviceChange = true
        XCTAssertTrue(WidgetBrowsingPolicy.shouldReload(loaded: .mobile, previous: previous, next: next))
        XCTAssertFalse(WidgetBrowsingPolicy.shouldReload(loaded: .tablet, previous: previous, next: next))
        next.frame.width = 550
        XCTAssertFalse(WidgetBrowsingPolicy.shouldReload(loaded: .mobile, previous: previous, next: next))
        next.browsingMode = .desktop
        next.reloadOnDeviceChange = false
        XCTAssertTrue(WidgetBrowsingPolicy.shouldReload(loaded: .mobile, previous: previous, next: next))
        XCTAssertFalse(WidgetBrowsingPolicy.shouldReload(loaded: nil, previous: previous, next: next))
    }

    func testEditingBrowserSettingsPreservesConcurrentFrameAndScroll() {
        let original = widget()
        var current = original
        current.frame.x = 300
        current.scrollY = 120
        var edited = original
        edited.browsingMode = .mobile
        edited.reloadOnDeviceChange = true
        let result = WidgetEdits.merging(original: original, edited: edited, current: current)
        XCTAssertEqual(result.frame.x, 300)
        XCTAssertEqual(result.scrollY, 120)
        XCTAssertEqual(result.browsingMode, .mobile)
        XCTAssertTrue(result.reloadOnDeviceChange)
    }

    func testCookieScopeHonorsDomainBoundariesAndIncludesRedirectHost() {
        let scope = WebsiteCookieScope(urls: [URL(string: "https://open.example.test/music")!, URL(string: "https://login.example.test/")!, URL(string: "file:///tmp/demo")!])
        XCTAssertEqual(scope.hosts, ["login.example.test", "open.example.test"])
        XCTAssertTrue(scope.includes(domain: ".example.test"))
        XCTAssertTrue(scope.includes(domain: "open.example.test"))
        XCTAssertTrue(scope.includes(domain: ".OPEN.EXAMPLE.TEST"))
        XCTAssertFalse(scope.includes(domain: "example.test")) // A host-only cookie.
        XCTAssertFalse(scope.includes(domain: "other.example.test"))
        XCTAssertFalse(scope.includes(domain: ".notexample.test"))
        XCTAssertFalse(scope.includes(domain: ".example.test.evil.test"))
        XCTAssertFalse(scope.includes(domain: ""))
        XCTAssertFalse(WebsiteCookieScope(urls: []).includes(domain: ".example.test"))
    }

    @MainActor func testCookieRemovalUsesIsolatedStoreAndKeepsUnrelatedCookies() async throws {
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let store = dataStore.httpCookieStore
        let service = WebsiteCookieService(dataStore: dataStore)
        let domains = [".example.test", "open.example.test", "other.example.test", ".notexample.test"]
        for (index, domain) in domains.enumerated() {
            let cookie = try XCTUnwrap(HTTPCookie(properties: [.name: "fixture\(index)", .value: "test", .domain: domain, .path: "/"]))
            await store.setCookie(cookie)
        }
        let initial = await store.allCookies()
        XCTAssertEqual(initial.count, 4)
        let result = await service.clear(WebsiteCookieScope(urls: [URL(string: "https://open.example.test/")!]))
        XCTAssertEqual(result.deleted, 2)
        XCTAssertEqual(result.remaining, 0)
        let remaining = await store.allCookies()
        XCTAssertEqual(Set(remaining.map(\.name)), ["fixture2", "fixture3"])
    }

    @MainActor func testWebKitReportsSelectedUserAgentForLocalPage() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 320), configuration: config)
        let delegate = LocalPageDelegate()
        view.navigationDelegate = delegate
        for device in [WidgetBrowserDevice.mobile, .tablet, .desktop] {
            view.customUserAgent = device.userAgent
            delegate.finished = expectation(description: "Local page loaded")
            view.loadHTMLString("<html><body>Offline UA check</body></html>", baseURL: nil)
            await fulfillment(of: [try XCTUnwrap(delegate.finished)], timeout: 10)
            let actual = try await view.evaluateJavaScript("navigator.userAgent") as? String
            XCTAssertEqual(actual, device.userAgent)
        }
    }
}

@MainActor
private final class LocalPageDelegate: NSObject, WKNavigationDelegate {
    var finished: XCTestExpectation?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished?.fulfill() }
}
