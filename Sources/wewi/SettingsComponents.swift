import SwiftUI

struct WidgetSummaryRow: View {
    let widget: WidgetConfig
    let edit: () -> Void
    let toggle: () -> Void
    let reload: () -> Void
    let clearCookies: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "globe")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(widget.isEnabled ? Color.accentColor : .secondary)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(widget.isEnabled ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(widget.name.isEmpty ? (widget.url?.host ?? appText("Untitled Widget")) : widget.name)
                        .font(.headline).foregroundStyle(.primary).lineLimit(1)
                    Text(widget.url?.host ?? widget.urlString).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 8) {
                        Text("\(Int(widget.frame.width)) × \(Int(widget.frame.height))")
                        Text(appText(widget.browsingMode.title))
                        if !widget.allowsInteraction { Image(systemName: "lock.fill").help(appText("Screen Lock")) }
                        if widget.normalizedRefreshIntervalValue > 0 {
                            Label("\(Int(widget.normalizedRefreshIntervalValue)) \(appText(widget.refreshIntervalUnit.rawValue))", systemImage: "arrow.clockwise")
                        }
                    }.font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help(appText("Edit Widget"))
            Toggle(appText("Visible"), isOn: Binding(get: { widget.isEnabled }, set: { _ in toggle() }))
                .labelsHidden().toggleStyle(.switch).help(appText(widget.isEnabled ? "Hide widget" : "Show widget"))
                .accessibilityLabel(appText("Visible") + ": " + widget.name)
            Menu {
                Button(appText("Edit Widget"), action: edit)
                Button(appText("Reload"), action: reload).disabled(!widget.isEnabled)
                Button(appText("Clear Website Cookies…"), action: clearCookies).disabled(!WidgetInput.validURL(widget.urlString))
                Divider()
                Button(appText("Delete Widget"), role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis").frame(width: 20, height: 24)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel(appText("Widget actions"))
        }.padding(.vertical, 10)
    }
}

@MainActor
struct WidgetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusURL: Bool
    private let original: WidgetConfig?
    private let save: (WidgetConfig) -> Void
    @State private var draft: WidgetConfig
    @State private var width: String
    @State private var height: String
    @State private var x: String
    @State private var y: String
    @State private var interval: String
    @State private var showPosition = false
    @State private var error: String?

    init(original: WidgetConfig?, save: @escaping (WidgetConfig) -> Void) {
        self.original = original; self.save = save
        let value = original ?? WidgetConfig(name: "", urlString: "", frame: .init(x: 80, y: 80, width: 480, height: 320))
        _draft = State(initialValue: value)
        _width = State(initialValue: Self.number(value.frame.width))
        _height = State(initialValue: Self.number(value.frame.height))
        _x = State(initialValue: Self.number(value.frame.x))
        _y = State(initialValue: Self.number(value.frame.y))
        _interval = State(initialValue: Self.number(value.refreshIntervalValue))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: original == nil ? "plus.rectangle" : "slider.horizontal.3").font(.title2).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appText(original == nil ? "Add Widget" : "Edit Widget")).font(.title2.bold())
                    Text(appText("A website, sized for your desktop.")).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        field(appText("Website URL"), text: $draft.urlString, prompt: "https://example.com")
                            .focused($focusURL)
                        field(appText("Name (optional)"), text: $draft.name, prompt: appText("e.g. Team dashboard"))
                    }
                    sizeSection
                    browsingSection
                    VStack(alignment: .leading, spacing: 14) {
                        Text(appText("Behavior")).font(.headline)
                        Toggle(appText("Show on desktop"), isOn: $draft.isEnabled)
                        Toggle(appText("Screen Lock"), isOn: Binding(get: { !draft.allowsInteraction }, set: { draft.allowsInteraction = !$0 }))
                        Text(appText("Prevents clicks inside the web page. This is not a privacy lock."))
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(appText("Auto-refresh"))
                            Spacer()
                            TextField("0", text: $interval).frame(width: 64).textFieldStyle(.roundedBorder)
                                .accessibilityLabel(appText("Refresh interval (0 = off)"))
                            Picker(appText("Refresh unit"), selection: $draft.refreshIntervalUnit) {
                                ForEach(WidgetRefreshIntervalUnit.allCases) { Text(appText($0.rawValue)).tag($0) }
                            }.labelsHidden().frame(width: 100)
                        }
                        Text(appText("Use 0 to refresh manually.")).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(appText("Opacity"))
                            Slider(value: $draft.opacity, in: 0.1...1).accessibilityLabel(appText("Opacity"))
                            Text("\(Int(draft.opacity * 100))%").monospacedDigit().frame(width: 40, alignment: .trailing)
                        }
                    }
                    DisclosureGroup(appText("Exact position"), isExpanded: $showPosition) {
                        HStack(spacing: 16) { field("X", text: $x); field("Y", text: $y) }.padding(.top, 10)
                    }
                    Text(appText("You can also drag and resize the widget directly on your desktop."))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let error { Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                HStack {
                    Text(appText("Changes apply when you save.")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(appText("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                    Button(appText(original == nil ? "Add Widget" : "Save Changes")) { submit() }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }.padding(20)
        }.frame(width: 520, height: 570)
            .onAppear { focusURL = original == nil }
    }

    private var browsingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(appText("Website mode"), selection: $draft.browsingMode) {
                ForEach(WidgetBrowsingMode.allCases) { mode in Text(appText(mode.title)).tag(mode) }
            }
            Text(appText("Automatic: mobile below 600 pt, tablet below 1024 pt, desktop at 1024 pt or wider."))
                .font(.caption).foregroundStyle(.secondary)
            if draft.browsingMode == .automatic {
                Toggle(appText("Reload when the device mode changes after resizing"), isOn: $draft.reloadOnDeviceChange)
                Text(appText("Off: the new mode applies on the next reload. On: resizing across a size range reloads the page and may interrupt playback or unsaved input."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(appText("Changing website mode and saving reloads the page when needed. Some websites do not support every mode."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appText("Size")).font(.headline)
                Spacer()
                Menu(appText("Choose a preset")) {
                    ForEach(["320×180", "480×320", "640×360", "800×450", "220×360", "300×480", "360×640", "420×740"], id: \.self) { size in
                        Button(size) {
                            let parts = size.split(separator: "×")
                            width = String(parts[0]); height = String(parts[1])
                        }
                    }
                }.fixedSize()
            }
            HStack(spacing: 16) {
                field(appText("Width"), text: $width)
                Text("×").foregroundStyle(.secondary).padding(.top, 20)
                field(appText("Height"), text: $height)
            }
        }
    }
    private func field(_ title: String, text: Binding<String>, prompt: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.callout.weight(.medium))
            TextField(title, text: text, prompt: Text(prompt)).labelsHidden().textFieldStyle(.roundedBorder)
        }
    }
    private static func number(_ value: Double) -> String { String(value).replacingOccurrences(of: #"\.0$"#, with: "", options: .regularExpression) }
    private func submit() {
        guard WidgetInput.validURL(draft.urlString) else { error = appText("Enter a valid HTTP or HTTPS URL."); focusURL = true; return }
        guard let w = Double(width), let h = Double(height), w.isFinite, h.isFinite, w >= 180, h >= 120 else {
            error = appText("Use a size of at least 180 × 120 pixels."); return
        }
        guard let px = Double(x), let py = Double(y), px.isFinite, py.isFinite,
              let refresh = Double(interval), refresh.isFinite, refresh >= 0 else {
            error = appText("Enter valid position values and a refresh interval of 0 or more."); return
        }
        draft.urlString = draft.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.frame = .init(x: px, y: py, width: w, height: h)
        draft.refreshIntervalValue = refresh > 0 ? max(1, refresh.rounded()) : 0
        save(draft)
    }
}
