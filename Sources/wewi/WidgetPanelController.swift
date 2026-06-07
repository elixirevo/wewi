import AppKit
import WebKit

@MainActor
final class WidgetPanelController: NSObject, NSWindowDelegate, WKNavigationDelegate {
    let id: UUID
    private(set) var config: WidgetConfig

    private let panel: NSPanel
    private let webView: WKWebView
    private let chromeView: WidgetChromeView
    private var onFrameChanged: ((UUID, WidgetFrame) -> Void)?
    private var onInteractionChanged: ((UUID, Bool) -> Void)?
    private var onScrollPositionChanged: ((UUID, Double, Double) -> Void)?
    private var onDisableRequested: ((UUID) -> Void)?
    private var lastRequestedURLString: String?
    private var loadRetryWorkItem: DispatchWorkItem?
    private var loadRetryCount = 0
    private let maxLoadRetryCount = 4
    private var autoRefreshTimer: Timer?
    private var activeAutoRefreshIntervalSeconds: Double = 0
    private var isHiddenForUnavailableScreen = false
    private var isObservingAppearanceChanges = false

    init(
        config: WidgetConfig,
        onFrameChanged: ((UUID, WidgetFrame) -> Void)? = nil,
        onInteractionChanged: ((UUID, Bool) -> Void)? = nil,
        onScrollPositionChanged: ((UUID, Double, Double) -> Void)? = nil,
        onDisableRequested: ((UUID) -> Void)? = nil
    ) {
        self.id = config.id
        self.config = config
        self.onFrameChanged = onFrameChanged
        self.onInteractionChanged = onInteractionChanged
        self.onScrollPositionChanged = onScrollPositionChanged
        self.onDisableRequested = onDisableRequested

        let panel = WidgetPanel(
            contentRect: config.frame.cgRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.panel = panel

        let webConfig = WKWebViewConfiguration()
        webConfig.limitsNavigationsToAppBoundDomains = false
        self.webView = ActivatingWebView(frame: .zero, configuration: webConfig)
        self.chromeView = WidgetChromeView(webView: webView)

        super.init()
        configurePanel()
        configureWebView()
        configureScreenObservation()
        configureAppearanceObservation()
        apply(config: config)
    }

    private func configurePanel() {
        panel.title = config.name
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.level = .init(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.delegate = self
        panel.contentView = chromeView
    }

    private func configureWebView() {
        webView.setValue(false, forKey: "drawsBackground")
        webView.customUserAgent = Self.supportedDesktopSafariUserAgent()
        webView.navigationDelegate = self
    }

    private static func supportedDesktopSafariUserAgent() -> String {
        // Some providers reject embedded WKWebView UAs. Use a Safari-like desktop UA.
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let macOS = "10_15_7"
        let safariVersion: String
        switch version.majorVersion {
        case 15:
            safariVersion = "18.0"
        case 14:
            safariVersion = "17.0"
        case 13:
            safariVersion = "16.0"
        default:
            safariVersion = "17.0"
        }
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X \(macOS)) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(safariVersion) Safari/605.1.15"
    }

    func apply(config: WidgetConfig) {
        self.config = config
        panel.title = config.name
        webView.alphaValue = CGFloat(max(0.05, min(1.0, config.opacity)))
        applyWebInteractionMode(allowsInteraction: config.allowsInteraction)
        chromeView.apply(
            name: config.name,
            allowsInteraction: config.allowsInteraction,
            onResize: { [weak self] frame in
                guard let self else { return }
                self.onFrameChanged?(self.id, WidgetFrame.from(frame))
            },
            onSaveScrollPosition: { [weak self] in
                self?.saveCurrentScrollPosition()
            },
            onReload: { [weak self] in
                self?.reload()
            },
            onToggleInteraction: { [weak self] allows in
                guard let self else { return }
                self.applyWebInteractionMode(allowsInteraction: allows)
                self.onInteractionChanged?(self.id, allows)
            },
            onDisableWidget: { [weak self] in
                guard let self else { return }
                self.onDisableRequested?(self.id)
            }
        )

        let targetFrame = config.frame.cgRect
        if !panel.frame.isApproximatelyEqual(to: targetFrame, tolerance: 0.5) {
            panel.setFrame(targetFrame, display: true)
        }
        updateVisibilityForCurrentScreens()
        applyAutoRefreshInterval(config.normalizedRefreshIntervalSeconds)

        if let url = config.url, lastRequestedURLString != config.urlString {
            loadRetryCount = 0
            loadRetryWorkItem?.cancel()
            let request = URLRequest(url: url)
            webView.load(request)
            lastRequestedURLString = config.urlString
        }
    }

    func show() {
        guard !isHiddenForUnavailableScreen else { return }
        panel.orderFrontRegardless()
    }

    func hide() {
        isHiddenForUnavailableScreen = false
        panel.orderOut(nil)
    }

    func close() {
        loadRetryWorkItem?.cancel()
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        activeAutoRefreshIntervalSeconds = 0
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if isObservingAppearanceChanges {
            DistributedNotificationCenter.default().removeObserver(
                self,
                name: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil
            )
            isObservingAppearanceChanges = false
        }
        panel.close()
    }

    func reload() {
        loadRetryCount = 0
        loadRetryWorkItem?.cancel()
        webView.reload()
    }

    private func applyAutoRefreshInterval(_ intervalSeconds: Double) {
        let normalized = intervalSeconds > 0 ? max(1, intervalSeconds) : 0
        if normalized == activeAutoRefreshIntervalSeconds,
           (normalized == 0 || autoRefreshTimer != nil) {
            return
        }

        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        activeAutoRefreshIntervalSeconds = normalized

        guard normalized > 0 else { return }

        let timer = Timer(timeInterval: normalized, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoRefreshTimer = timer
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        onFrameChanged?(id, WidgetFrame.from(panel.frame))
    }

    private func configureScreenObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func configureAppearanceObservation() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSystemAppearanceChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        isObservingAppearanceChanges = true
        applyWebColorScheme()
    }

    @objc
    private func handleScreenParametersChanged() {
        updateVisibilityForCurrentScreens()
    }

    @objc
    private func handleSystemAppearanceChanged() {
        applyWebColorScheme()
    }

    private func updateVisibilityForCurrentScreens() {
        let targetFrame = config.frame.cgRect
        let hasVisibleScreen = availableScreenRects().contains { $0.intersects(targetFrame) }

        if hasVisibleScreen {
            if !panel.frame.isApproximatelyEqual(to: targetFrame, tolerance: 0.5) {
                panel.setFrame(targetFrame, display: true)
            }
            if isHiddenForUnavailableScreen {
                isHiddenForUnavailableScreen = false
                panel.orderFrontRegardless()
            }
            return
        }

        isHiddenForUnavailableScreen = true
        panel.orderOut(nil)
    }

    private func availableScreenRects() -> [CGRect] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return [] }

        return screens.map(\.frame)
    }

    private func applyWebInteractionMode(allowsInteraction: Bool) {
        if allowsInteraction {
            let js = """
            (function() {
              const blocker = document.getElementById('__wewi_interaction_blocker__');
              if (blocker && blocker.parentNode) {
                blocker.parentNode.removeChild(blocker);
              }
              if (document.activeElement && typeof document.activeElement.blur === 'function') {
                document.activeElement.blur();
              }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            let js = """
            (function() {
              if (!document.body) return;
              let blocker = document.getElementById('__wewi_interaction_blocker__');
              if (!blocker) {
                blocker = document.createElement('div');
                blocker.id = '__wewi_interaction_blocker__';
                blocker.style.position = 'fixed';
                blocker.style.left = '0';
                blocker.style.top = '0';
                blocker.style.width = '100vw';
                blocker.style.height = '100vh';
                blocker.style.pointerEvents = 'auto';
                blocker.style.cursor = 'default';
                blocker.style.background = 'transparent';
                blocker.style.zIndex = '2147483647';
                blocker.setAttribute('aria-hidden', 'true');
                blocker.addEventListener('wheel', function(e){ e.preventDefault(); }, { passive: false });
                blocker.addEventListener('touchmove', function(e){ e.preventDefault(); }, { passive: false });
                document.body.appendChild(blocker);
              } else if (blocker.parentNode !== document.body) {
                document.body.appendChild(blocker);
              }
              if (document.activeElement && typeof document.activeElement.blur === 'function') {
                document.activeElement.blur();
              }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func applyWebColorScheme() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let appearanceName: NSAppearance.Name = isDark ? .darkAqua : .aqua
        webView.appearance = NSAppearance(named: appearanceName)

        let js = """
        (function() {
          var dark = \(isDark ? "true" : "false");
          var scheme = dark ? 'dark' : 'light';
          var root = document.documentElement;
          if (!root) return;
          root.setAttribute('data-wewi-color-scheme', scheme);
          window.__wewiPrefersDarkMode = dark;
          window.dispatchEvent(new CustomEvent('__wewi_color_scheme_changed__', {
            detail: { dark: dark, scheme: scheme }
          }));
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        applyWebColorScheme()
        applyWebInteractionMode(allowsInteraction: config.allowsInteraction)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        applyWebColorScheme()
        applyWebInteractionMode(allowsInteraction: config.allowsInteraction)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadRetryCount = 0
        loadRetryWorkItem?.cancel()
        applyWebColorScheme()
        applyWebInteractionMode(allowsInteraction: config.allowsInteraction)
        restoreScrollPosition()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        scheduleLoadRetry(for: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        scheduleLoadRetry(for: error)
    }

    private func scheduleLoadRetry(for error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        guard let url = config.url else { return }
        guard loadRetryCount < maxLoadRetryCount else { return }

        loadRetryCount += 1
        let delay = min(pow(2.0, Double(loadRetryCount - 1)), 8.0)

        loadRetryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let request = URLRequest(url: url)
            self.webView.load(request)
        }
        loadRetryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func restoreScrollPosition() {
        let x = max(0, config.scrollX.rounded())
        let y = max(0, config.scrollY.rounded())
        guard x > 0 || y > 0 else { return }

        let js = "window.scrollTo(\(Int(x)), \(Int(y)));"
        webView.evaluateJavaScript(js, completionHandler: nil)

        for delay in [0.5, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    private func saveCurrentScrollPosition() {
        let js = """
        ({
          x: Math.max(0, Math.round(window.scrollX || window.pageXOffset || 0)),
          y: Math.max(0, Math.round(window.scrollY || window.pageYOffset || 0))
        });
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            Task { @MainActor in
                guard let self,
                      let body = result as? [String: Any],
                      let x = Self.doubleValue(from: body["x"]),
                      let y = Self.doubleValue(from: body["y"]) else {
                    return
                }

                let roundedX = max(0, x.rounded())
                let roundedY = max(0, y.rounded())
                self.config.scrollX = roundedX
                self.config.scrollY = roundedY
                self.onScrollPositionChanged?(self.id, roundedX, roundedY)
            }
        }
    }

    private static func doubleValue(from value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
}

private extension CGRect {
    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat) -> Bool {
        abs(origin.x - other.origin.x) <= tolerance &&
            abs(origin.y - other.origin.y) <= tolerance &&
            abs(size.width - other.size.width) <= tolerance &&
            abs(size.height - other.size.height) <= tolerance
    }
}

@MainActor
private final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class ActivatingWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        activateForKeyboardInput()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        activateForKeyboardInput()
        super.rightMouseDown(with: event)
    }

    private func activateForKeyboardInput() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
