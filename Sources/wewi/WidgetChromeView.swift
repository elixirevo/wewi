import AppKit
import WebKit

@MainActor
final class WidgetChromeView: NSView {
    private let webView: WKWebView
    private let webBackground = NSVisualEffectView()
    private let titleField = NSTextField(labelWithString: "")
    private let dragArea = DragAreaView()
    private let resizeHandle = ResizeHandleView()
    private let interactionBlocker = InteractionBlockerView()
    private let saveScrollButton = NSButton()
    private let reloadButton = NSButton()
    private let interactionButton = NSButton()
    private let disableButton = NSButton()

    private var minSize = NSSize(width: 180, height: 120)
    private var onFrameChange: ((NSRect) -> Void)?
    private var onSaveScrollPosition: (() -> Void)?
    private var onReload: (() -> Void)?
    private var onToggleInteraction: ((Bool) -> Void)?
    private var onDisableWidget: (() -> Void)?
    private var dragStartFrame: NSRect?
    private var resizeStartFrame: NSRect?
    private var allowsInteraction = true
    private var hoverTrackingArea: NSTrackingArea?
    private var hideResizeHandleWorkItem: DispatchWorkItem?
    private var isPointerInsideChrome = false
    private var isResizing = false
    private let resizeHandleHideDelay: TimeInterval = 2.0

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        name: String,
        allowsInteraction: Bool,
        onResize: @escaping (NSRect) -> Void,
        onSaveScrollPosition: @escaping () -> Void,
        onReload: @escaping () -> Void,
        onToggleInteraction: @escaping (Bool) -> Void,
        onDisableWidget: @escaping () -> Void
    ) {
        titleField.stringValue = name
        self.allowsInteraction = allowsInteraction
        interactionBlocker.isHidden = allowsInteraction
        self.onFrameChange = onResize
        self.onSaveScrollPosition = onSaveScrollPosition
        self.onReload = onReload
        self.onToggleInteraction = onToggleInteraction
        self.onDisableWidget = onDisableWidget
        refreshInteractionButtonTitle()
        applyInteractionState()
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        webView.translatesAutoresizingMaskIntoConstraints = false
        webBackground.translatesAutoresizingMaskIntoConstraints = false
        dragArea.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        titleField.translatesAutoresizingMaskIntoConstraints = false
        interactionBlocker.translatesAutoresizingMaskIntoConstraints = false
        saveScrollButton.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        interactionButton.translatesAutoresizingMaskIntoConstraints = false
        disableButton.translatesAutoresizingMaskIntoConstraints = false

        interactionBlocker.wantsLayer = true
        interactionBlocker.layer?.backgroundColor = NSColor.clear.cgColor

        saveScrollButton.bezelStyle = .texturedRounded
        saveScrollButton.title = "Save"
        saveScrollButton.font = .systemFont(ofSize: 10, weight: .semibold)
        saveScrollButton.toolTip = "Save scroll position"
        saveScrollButton.target = self
        saveScrollButton.action = #selector(saveScrollTapped)

        reloadButton.bezelStyle = .texturedRounded
        reloadButton.title = "↻"
        reloadButton.font = .systemFont(ofSize: 12, weight: .semibold)
        reloadButton.toolTip = "Reload"
        reloadButton.target = self
        reloadButton.action = #selector(reloadTapped)

        interactionButton.bezelStyle = .texturedRounded
        interactionButton.font = .systemFont(ofSize: 11, weight: .semibold)
        interactionButton.target = self
        interactionButton.action = #selector(interactionTapped)

        disableButton.bezelStyle = .texturedRounded
        disableButton.title = "✕"
        disableButton.font = .systemFont(ofSize: 11, weight: .bold)
        disableButton.contentTintColor = .systemRed
        disableButton.toolTip = "Disable widget"
        disableButton.target = self
        disableButton.action = #selector(disableTapped)

        addSubview(webView)
        addSubview(webBackground, positioned: .below, relativeTo: webView)
        addSubview(dragArea)
        addSubview(titleField)
        addSubview(saveScrollButton)
        addSubview(reloadButton)
        addSubview(interactionButton)
        addSubview(disableButton)
        addSubview(interactionBlocker)
        addSubview(resizeHandle)

        titleField.textColor = .white
        titleField.font = .systemFont(ofSize: 11, weight: .semibold)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1

        dragArea.material = .hudWindow
        dragArea.blendingMode = .behindWindow
        dragArea.state = .active
        dragArea.alphaValue = 0.75

        webBackground.material = .hudWindow
        webBackground.blendingMode = .behindWindow
        webBackground.state = .active
        webBackground.alphaValue = 0.75

        dragArea.onDragStart = { [weak self] in
            guard let self, let window = self.window else { return }
            self.dragStartFrame = window.frame
        }
        dragArea.onDrag = { [weak self] totalDeltaX, totalDeltaY in
            guard let self, let window = self.window, let start = self.dragStartFrame else { return }
            var frame = start
            frame.origin.x = start.origin.x + totalDeltaX
            frame.origin.y = start.origin.y + totalDeltaY
            window.setFrame(frame, display: true)
        }
        dragArea.onDragEnd = { [weak self] in
            guard let self, let window = self.window else { return }
            self.dragStartFrame = nil
            self.onFrameChange?(window.frame)
        }

        resizeHandle.onDragStart = { [weak self] in
            guard let self, let window = self.window else { return }
            self.isResizing = true
            self.cancelResizeHandleHide()
            self.setResizeHandleVisible(true, animated: true)
            self.resizeStartFrame = window.frame
        }
        resizeHandle.onDrag = { [weak self] totalDeltaX, totalDeltaY in
            guard let self, let window = self.window, let start = self.resizeStartFrame else { return }
            var frame = start
            let topY = start.origin.y + start.size.height
            frame.size.width = max(self.minSize.width, start.size.width + totalDeltaX)
            frame.size.height = max(self.minSize.height, start.size.height - totalDeltaY)
            frame.origin.y = topY - frame.size.height
            window.setFrame(frame, display: true)
        }
        resizeHandle.onDragEnd = { [weak self] in
            guard let self, let window = self.window else { return }
            self.isResizing = false
            self.resizeStartFrame = nil
            self.onFrameChange?(window.frame)
            if !self.isPointerInsideChrome {
                self.scheduleResizeHandleHide()
            }
        }

        NSLayoutConstraint.activate([
            dragArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            dragArea.trailingAnchor.constraint(equalTo: trailingAnchor),
            dragArea.topAnchor.constraint(equalTo: topAnchor),
            dragArea.heightAnchor.constraint(equalToConstant: 22),

            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleField.trailingAnchor.constraint(equalTo: interactionButton.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: dragArea.centerYAnchor, constant: 1),

            disableButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            disableButton.centerYAnchor.constraint(equalTo: dragArea.centerYAnchor),
            disableButton.widthAnchor.constraint(equalToConstant: 24),
            disableButton.heightAnchor.constraint(equalToConstant: 18),

            reloadButton.trailingAnchor.constraint(equalTo: disableButton.leadingAnchor, constant: -6),
            reloadButton.centerYAnchor.constraint(equalTo: dragArea.centerYAnchor),
            reloadButton.widthAnchor.constraint(equalToConstant: 28),
            reloadButton.heightAnchor.constraint(equalToConstant: 18),

            saveScrollButton.trailingAnchor.constraint(equalTo: reloadButton.leadingAnchor, constant: -6),
            saveScrollButton.centerYAnchor.constraint(equalTo: dragArea.centerYAnchor),
            saveScrollButton.widthAnchor.constraint(equalToConstant: 42),
            saveScrollButton.heightAnchor.constraint(equalToConstant: 18),

            interactionButton.trailingAnchor.constraint(equalTo: saveScrollButton.leadingAnchor, constant: -6),
            interactionButton.centerYAnchor.constraint(equalTo: dragArea.centerYAnchor),
            interactionButton.widthAnchor.constraint(equalToConstant: 46),
            interactionButton.heightAnchor.constraint(equalToConstant: 18),

            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: dragArea.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),

            webBackground.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            webBackground.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            webBackground.topAnchor.constraint(equalTo: webView.topAnchor),
            webBackground.bottomAnchor.constraint(equalTo: webView.bottomAnchor),

            interactionBlocker.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            interactionBlocker.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            interactionBlocker.topAnchor.constraint(equalTo: webView.topAnchor),
            interactionBlocker.bottomAnchor.constraint(equalTo: webView.bottomAnchor),

            resizeHandle.widthAnchor.constraint(equalToConstant: 22),
            resizeHandle.heightAnchor.constraint(equalToConstant: 22),
            resizeHandle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            resizeHandle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])

        setResizeHandleVisible(false, animated: false)
    }

    override func layout() {
        super.layout()
        updateCornerRadius()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .inVisibleRect, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isPointerInsideChrome = true
        cancelResizeHandleHide()
        setResizeHandleVisible(true, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        isPointerInsideChrome = false
        guard !isResizing else { return }
        scheduleResizeHandleHide()
    }

    @objc
    private func saveScrollTapped() {
        onSaveScrollPosition?()
    }

    @objc
    private func reloadTapped() {
        onReload?()
    }

    @objc
    private func interactionTapped() {
        // ON: interaction blocked, OFF: interaction allowed
        let isBlockingOn = interactionButton.title == "ON"
        let nextBlockingOn = !isBlockingOn
        interactionButton.title = nextBlockingOn ? "ON" : "OFF"
        allowsInteraction = !nextBlockingOn
        applyInteractionState()
        refreshInteractionButtonTitle()
        onToggleInteraction?(allowsInteraction)
    }

    @objc
    private func disableTapped() {
        onDisableWidget?()
    }

    private func refreshInteractionButtonTitle() {
        let blockingOn = !allowsInteraction
        interactionButton.title = blockingOn ? "ON" : "OFF"
        interactionButton.toolTip = blockingOn ? "Web interaction blocked" : "Web interaction allowed"
    }

    private func applyInteractionState() {
        interactionBlocker.isHidden = allowsInteraction
        resizeHandle.isUserInteractionEnabled = allowsInteraction
        if resizeHandle.isHidden {
            resizeHandle.alphaValue = 0.0
        } else {
            resizeHandle.alphaValue = allowsInteraction ? 1.0 : 0.35
        }

        guard let window else { return }
        if allowsInteraction {
            if window.firstResponder === interactionBlocker {
                window.makeFirstResponder(webView)
            }
        } else {
            window.makeFirstResponder(interactionBlocker)
        }
    }

    private func updateCornerRadius() {
        // WidgetKit guidance favors size-adaptive, concentric-looking corners.
        // We approximate that behavior for arbitrary web widget sizes.
        let minSide = min(bounds.width, bounds.height)
        let adaptive = max(12, min(24, round(minSide * 0.11)))
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = adaptive
    }

    private func scheduleResizeHandleHide() {
        cancelResizeHandleHide()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPointerInsideChrome, !self.isResizing else { return }
            self.setResizeHandleVisible(false, animated: true)
        }
        hideResizeHandleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + resizeHandleHideDelay, execute: workItem)
    }

    private func cancelResizeHandleHide() {
        hideResizeHandleWorkItem?.cancel()
        hideResizeHandleWorkItem = nil
    }

    private func setResizeHandleVisible(_ isVisible: Bool, animated: Bool) {
        if isVisible {
            resizeHandle.isHidden = false
            let alpha = allowsInteraction ? 1.0 : 0.35
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    resizeHandle.animator().alphaValue = alpha
                }
            } else {
                resizeHandle.alphaValue = alpha
            }
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                resizeHandle.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.resizeHandle.isHidden = true
                }
            })
        } else {
            resizeHandle.alphaValue = 0.0
            resizeHandle.isHidden = true
        }
    }
}

@MainActor
private final class DragAreaView: NSVisualEffectView {
    var onDragStart: (() -> Void)?
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?

    private var startPoint: NSPoint = .zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startPoint = NSEvent.mouseLocation
        onDragStart?()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        let totalDeltaX = point.x - startPoint.x
        let totalDeltaY = point.y - startPoint.y
        onDrag?(totalDeltaX, totalDeltaY)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?()
    }
}

@MainActor
private final class ResizeHandleView: NSView {
    var isUserInteractionEnabled = true
    var onDragStart: (() -> Void)?
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?

    private var startPoint: NSPoint = .zero

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        discardCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let drawingRect = bounds.insetBy(dx: 3, dy: 3)
        let outerDiameter = min(drawingRect.width, drawingRect.height)
        let outerRect = NSRect(
            x: drawingRect.midX - outerDiameter / 2,
            y: drawingRect.midY - outerDiameter / 2,
            width: outerDiameter,
            height: outerDiameter
        )

        let outerCircle = NSBezierPath(ovalIn: outerRect)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 2.0
        shadow.shadowOffset = .zero
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.set()
        NSColor.black.withAlphaComponent(0.92).setFill()
        outerCircle.fill()
        NSGraphicsContext.restoreGraphicsState()

        let innerDiameter = outerDiameter * 0.44
        let innerRect = NSRect(
            x: outerRect.midX - innerDiameter / 2,
            y: outerRect.midY - innerDiameter / 2,
            width: innerDiameter,
            height: innerDiameter
        )
        let innerCircle = NSBezierPath(ovalIn: innerRect)
        NSColor.white.setFill()
        innerCircle.fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard isUserInteractionEnabled else { return }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startPoint = NSEvent.mouseLocation
        onDragStart?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isUserInteractionEnabled else { return }
        let point = NSEvent.mouseLocation
        let totalDeltaX = point.x - startPoint.x
        let totalDeltaY = point.y - startPoint.y
        onDrag?(totalDeltaX, totalDeltaY)
    }

    override func mouseUp(with event: NSEvent) {
        guard isUserInteractionEnabled else { return }
        onDragEnd?()
    }
}

@MainActor
private final class InteractionBlockerView: NSView {
    private var blockerTrackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool { true }
    override func resignFirstResponder() -> Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let blockerTrackingArea {
            removeTrackingArea(blockerTrackingArea)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        blockerTrackingArea = area
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.0, bounds.contains(point) else { return nil }
        return self
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseMoved(with event: NSEvent) {}
    override func mouseEntered(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseExited(with event: NSEvent) {}
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
}
