import SwiftUI
import MacAppSettings

@MainActor
struct WidgetSettingsContent: View {
    @ObservedObject var store: WidgetStore
    let reload: (UUID) -> Void
    @State private var name = ""
    @State private var url = ""
    @State private var width = 480.0
    @State private var height = 320.0
    @State private var preset = "480×320"
    @State private var validationError: String?

    var body: some View {
        SettingsSection(appText("Create New Widget")) {
            TextField(appText("Name"), text: $name)
            TextField(appText("URL"), text: $url, prompt: Text("https://example.com"))
            SettingsPicker(appText("Size"), selection: $preset) {
                ForEach(["320×180", "480×320", "640×360", "800×450", "220×360", "300×480", "360×640", "420×740"], id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: preset) { value in
                let parts = value.split(separator: "×").compactMap { Double($0) }
                if parts.count == 2 { width = parts[0]; height = parts[1] }
            }
            HStack {
                TextField(appText("Width"), value: $width, format: .number)
                TextField(appText("Height"), value: $height, format: .number)
            }
            Button(appText("Add Widget")) { add() }
            if let validationError { Text(validationError).foregroundStyle(.red) }
        }
        if store.widgets.isEmpty {
            SettingsSection(appText("Widgets")) {
                Text(appText("Add a website above to keep it on your desktop.")).foregroundStyle(.secondary)
            }
        }
        ForEach(store.widgets) { widget in
            WidgetSettingsRow(widget: widget, onSave: { store.update($0) },
                              onDelete: { store.remove(id: widget.id) }, reload: { reload(widget.id) })
        }
    }

    private func add() {
        guard WidgetInput.validURL(url), width.isFinite, height.isFinite, width >= 180, height >= 120 else {
            validationError = appText("Enter an HTTP or HTTPS URL and a size of at least 180 × 120.")
            return
        }
        store.add(WidgetConfig(name: name, urlString: url.trimmingCharacters(in: .whitespacesAndNewlines),
                              frame: .init(x: 80, y: 80, width: width, height: height)))
        name = ""
        validationError = nil
    }
}

enum WidgetInput {
    static func validURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
}
