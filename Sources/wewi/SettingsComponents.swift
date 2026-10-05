import SwiftUI
import MacAppSettings

@MainActor
struct WidgetSettingsRow: View {
    let widget: WidgetConfig
    let onSave: (WidgetConfig) -> Void
    let onDelete: () -> Void
    let reload: () -> Void
    @State private var editedURL = ""
    @State private var invalidURL = false
    @State private var confirmDelete = false

    var body: some View {
        SettingsSection(widget.name.isEmpty ? appText("Untitled Widget") : widget.name) {
            TextField(appText("Name"), text: binding(\.name))
            TextField(appText("URL"), text: $editedURL)
                .onSubmit { saveURL() }
            if editedURL != widget.urlString {
                Button(appText("Apply URL")) { saveURL() }
            }
            if invalidURL { Text(appText("Enter a valid HTTP or HTTPS URL.")).foregroundStyle(.red) }
            SettingsToggle(appText("Enabled"), isOn: binding(\.isEnabled))
            SettingsToggle(appText("Screen Lock"), detail: appText("Prevents clicks inside the web page. This is not a privacy lock."),
                           isOn: Binding(get: { !widget.allowsInteraction }, set: { value in
                var copy = widget; copy.allowsInteraction = !value; onSave(copy)
            }))
            HStack {
                metric("X", path: \.x); metric("Y", path: \.y)
            }
            HStack {
                metric(appText("Width"), path: \.width); metric(appText("Height"), path: \.height)
            }
            SettingsRow(appText("Opacity")) {
                Slider(value: binding(\.opacity), in: 0.1...1).frame(maxWidth: 220)
                Text("\(Int(widget.opacity * 100))%")
            }
            TextField(appText("Refresh interval (0 = off)"), value: Binding(get: { widget.refreshIntervalValue }, set: { value in
                guard value.isFinite else { return }
                var copy = widget; copy.refreshIntervalValue = max(0, value.rounded()); onSave(copy)
            }), format: .number)
            SettingsPicker(appText("Refresh unit"), selection: binding(\.refreshIntervalUnit)) {
                ForEach(WidgetRefreshIntervalUnit.allCases) { Text(appText($0.rawValue)).tag($0) }
            }
            HStack {
                Button(appText("Reload"), action: reload).disabled(!widget.isEnabled)
                Spacer()
                Button(appText("Delete Widget"), role: .destructive) { confirmDelete = true }
            }
        }
        .onAppear { editedURL = widget.urlString }
        .onChange(of: widget.urlString) { editedURL = $0 }
        .alert(appText("Delete this widget?"), isPresented: $confirmDelete) {
            Button(appText("Cancel"), role: .cancel) {}
            Button(appText("Delete Widget"), role: .destructive, action: onDelete)
        } message: { Text(appText("The widget settings will be removed. Website cookies are kept.")) }
    }

    private func binding<T>(_ path: WritableKeyPath<WidgetConfig, T>) -> Binding<T> {
        Binding(get: { widget[keyPath: path] }, set: { value in
            var copy = widget; copy[keyPath: path] = value; onSave(copy)
        })
    }
    private func metric(_ title: String, path: WritableKeyPath<WidgetFrame, Double>) -> some View {
        TextField(title, value: Binding(get: { widget.frame[keyPath: path] }, set: { value in
            guard value.isFinite else { return }
            var copy = widget
            copy.frame[keyPath: path] = path == \.width ? max(180, value) : path == \.height ? max(120, value) : value
            onSave(copy)
        }), format: .number)
    }
    private func saveURL() {
        guard WidgetInput.validURL(editedURL) else { invalidURL = true; return }
        var copy = widget
        copy.urlString = editedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.scrollX = 0; copy.scrollY = 0
        onSave(copy); invalidURL = false
    }
}
