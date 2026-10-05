import AppKit

/// Coordinates are screen points, including negative origins on secondary displays.
enum WidgetPlacement {
    static let spacing: CGFloat = 24

    static func screenIndex(at pointer: CGPoint, frames: [CGRect]) -> Int? {
        if let index = frames.firstIndex(where: { $0.contains(pointer) }) { return index }
        return frames.indices.min { distance(pointer, to: frames[$0]) < distance(pointer, to: frames[$1]) }
    }

    private static func distance(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    static func destination(for frame: CGRect, in area: CGRect, snap: Bool) -> CGRect {
        guard snap else { return frame }
        // Align the top-left corner to the display's usable area. Keep the size unchanged.
        let x = ((frame.minX - area.minX) / spacing).rounded() * spacing + area.minX
        let top = area.maxY - ((area.maxY - frame.maxY) / spacing).rounded() * spacing
        return CGRect(x: min(max(x, area.minX), max(area.minX, area.maxX - frame.width)),
                      y: max(min(top - frame.height, area.maxY - frame.height), min(area.minY, area.maxY - frame.height)),
                      width: frame.width, height: frame.height)
    }
}

/// Owns only the temporary drag preview; it never writes widget settings.
@MainActor
final class WidgetPlacementSession {
    private weak var window: NSWindow?
    private var original: CGRect?
    private(set) var destination: CGRect?
    private var overlay: NSPanel?
    private let guide = PlacementGuideView()
    var isActive: Bool { original != nil }

    func begin(window: NSWindow) {
        cancel()
        self.window = window
        original = window.frame
    }

    func update(frame: CGRect, pointer: CGPoint, snap: Bool) {
        guard let window, isActive else { return }
        window.setFrame(frame, display: true)
        let screens = NSScreen.screens
        guard let index = WidgetPlacement.screenIndex(at: pointer, frames: screens.map(\.frame)) else {
            destination = frame
            overlay?.orderOut(nil)
            return
        }
        let area = screens[index].visibleFrame
        let target = WidgetPlacement.destination(for: frame, in: area, snap: snap)
        destination = target
        if overlay == nil {
            let panel = NSPanel(contentRect: area, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .transient, .ignoresCycle]
            panel.contentView = guide
            overlay = panel
        }
        guard let overlay else { return }
        overlay.level = window.level
        overlay.setFrame(area, display: true)
        guide.target = target.offsetBy(dx: -area.minX, dy: -area.minY)
        guide.snap = snap
        guide.needsDisplay = true
        overlay.order(.above, relativeTo: window.windowNumber)
    }

    @discardableResult
    func finish() -> CGRect? {
        // A click without movement must not reposition an existing widget.
        let result = destination ?? original
        if let result { window?.setFrame(result, display: true) }
        clear()
        return result
    }

    func cancel() {
        if let original { window?.setFrame(original, display: true) }
        clear()
    }

    private func clear() {
        overlay?.orderOut(nil)
        overlay?.close()
        overlay = nil
        original = nil
        destination = nil
        window = nil
    }
}

@MainActor
private final class PlacementGuideView: NSView {
    var target = CGRect.zero
    var snap = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if snap {
            NSColor.controlAccentColor.withAlphaComponent(0.3).setFill()
            let dots = NSBezierPath()
            for x in stride(from: CGFloat(0), through: bounds.width, by: WidgetPlacement.spacing) {
                for y in stride(from: bounds.height, through: CGFloat(0), by: -WidgetPlacement.spacing) {
                    dots.appendOval(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                }
            }
            dots.fill()
        }
        // Draw just outside the target so the outline remains visible in free placement too.
        let outline = NSBezierPath(roundedRect: target.insetBy(dx: -3, dy: -3), xRadius: 18, yRadius: 18)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        outline.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
        outline.lineWidth = 2
        outline.stroke()
    }
}
