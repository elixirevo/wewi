import XCTest
import AppKit
@testable import wewi

final class WidgetPlacementTests: XCTestCase {
    func testFreePlacementPreservesExactFrameOutsideScreen() {
        let frame = CGRect(x: -17.25, y: 761.75, width: 401.5, height: 257.5)
        XCTAssertEqual(WidgetPlacement.destination(for: frame, in: CGRect(x: 0, y: 24, width: 1200, height: 800), snap: false), frame)
    }

    func testSnapsTopLeftUsingUsableAreaAndPreservesSize() {
        let area = CGRect(x: 0, y: 40, width: 1440, height: 860)
        let frame = CGRect(x: 61, y: 513, width: 401, height: 320)
        let target = WidgetPlacement.destination(for: frame, in: area, snap: true)
        XCTAssertEqual(target, CGRect(x: 72, y: 508, width: 401, height: 320))
        XCTAssertEqual(WidgetPlacement.destination(for: target, in: area, snap: true), target)
    }

    func testSecondaryDisplayWithNegativeCoordinatesAndDifferentOrigin() {
        let area = CGRect(x: -1920, y: -180, width: 1920, height: 1056)
        let frame = CGRect(x: -1883, y: 502, width: 480, height: 320)
        XCTAssertEqual(WidgetPlacement.destination(for: frame, in: area, snap: true), CGRect(x: -1872, y: 508, width: 480, height: 320))
        let frames = [CGRect(x: 0, y: 0, width: 1440, height: 900), area]
        XCTAssertEqual(WidgetPlacement.screenIndex(at: CGPoint(x: -1850, y: 800), frames: frames), 1)
        XCTAssertEqual(WidgetPlacement.screenIndex(at: CGPoint(x: 100, y: 100), frames: frames), 0)
        XCTAssertEqual(WidgetPlacement.screenIndex(at: CGPoint(x: 1600, y: 100), frames: frames), 0)
        XCTAssertNil(WidgetPlacement.screenIndex(at: .zero, frames: []))
    }

    func testEdgesAndOversizedWidgetsKeepTitleReachableWithoutResizing() {
        let area = CGRect(x: 10, y: 40, width: 1000, height: 700)
        let outside = CGRect(x: 980, y: -80, width: 401, height: 320)
        XCTAssertEqual(WidgetPlacement.destination(for: outside, in: area, snap: true), CGRect(x: 609, y: 40, width: 401, height: 320))
        let huge = CGRect(x: -500, y: -500, width: 1400, height: 1000)
        XCTAssertEqual(WidgetPlacement.destination(for: huge, in: area, snap: true), CGRect(x: 10, y: -260, width: 1400, height: 1000))
    }

    @MainActor func testSnapPreferenceDefaultsOffAndPersistsWithoutMovingWidgets() throws {
        let domain = "wewi.placement.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let data = Data("existing widget settings".utf8)
        defaults.set(data, forKey: "wewi.widgets.v1")
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertFalse(preferences.snapToGrid)
        preferences.snapToGrid = true
        XCTAssertTrue(AppPreferences(defaults: defaults).snapToGrid)
        preferences.snapToGrid = false
        XCTAssertFalse(AppPreferences(defaults: defaults).snapToGrid)
        XCTAssertEqual(defaults.data(forKey: "wewi.widgets.v1"), data)
    }

    @MainActor func testPlacementSessionClickCancelAndCommit() throws {
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main)
        let start = CGRect(x: screen.visibleFrame.minX + 47, y: screen.visibleFrame.minY + 81, width: 360, height: 260)
        let window = NSPanel(contentRect: start, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let session = WidgetPlacementSession()
        session.begin(window: window)
        XCTAssertEqual(session.finish(), start)
        let moved = start.offsetBy(dx: 79, dy: 59)
        session.begin(window: window)
        session.update(frame: moved, pointer: CGPoint(x: moved.midX, y: moved.maxY - 10), snap: true)
        XCTAssertTrue(session.isActive)
        let overlay = try XCTUnwrap(NSApp.windows.first { $0 !== window && $0.isVisible && $0.ignoresMouseEvents })
        XCTAssertFalse(overlay.canBecomeKey)
        XCTAssertEqual(overlay.frame, screen.visibleFrame)
        if let path = ProcessInfo.processInfo.environment["WEWI_PLACEMENT_CAPTURE"], let guide = overlay.contentView {
            let bitmap = try XCTUnwrap(guide.bitmapImageRepForCachingDisplay(in: guide.bounds))
            guide.cacheDisplay(in: guide.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
        XCTAssertEqual(window.frame, moved) // Follow the pointer until mouse-up.
        session.cancel()
        XCTAssertEqual(window.frame, start)
        XCTAssertFalse(overlay.isVisible)
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.destination)
        session.begin(window: window)
        session.update(frame: moved, pointer: CGPoint(x: moved.midX, y: moved.maxY - 10), snap: true)
        let expected = WidgetPlacement.destination(for: moved, in: screen.visibleFrame, snap: true)
        XCTAssertEqual(session.finish(), expected)
        XCTAssertEqual(window.frame, expected)
        XCTAssertFalse(session.isActive)
        session.begin(window: window)
        session.update(frame: moved, pointer: CGPoint(x: moved.midX, y: moved.maxY - 10), snap: false)
        XCTAssertEqual(session.finish(), moved)
        XCTAssertEqual(window.frame, moved)
    }
}
