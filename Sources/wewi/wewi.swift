import AppKit

@main
struct WewiMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        do { try delegate.lifecycle.start() }
        catch { NSAlert(error: error).runModal(); return }
        withExtendedLifetime(delegate) { app.run() }
    }
}
