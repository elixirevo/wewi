import SwiftUI
import MacAppSettings

@MainActor
struct WidgetSettingsContent: View {
    @ObservedObject var store: WidgetStore
    @ObservedObject var preferences: AppPreferences
    let cookies: WebsiteCookieService
    let cookieScope: (WidgetConfig) -> WebsiteCookieScope
    let reload: (UUID) -> Void
    @State private var query = ""
    @State private var onlyEnabled = false
    @State private var editor: WidgetEditorRequest?
    @State private var deleting: WidgetConfig?
    @State private var clearingCookies: WebsiteCookieScope?

    private var filtered: [WidgetConfig] {
        store.widgets.filter {
            (!onlyEnabled || $0.isEnabled) && (query.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(query) || $0.urlString.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        Group {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appText("Your desktop widgets")).font(.title2.bold())
                        Text(store.widgets.isEmpty ? appText("Keep the websites you use within reach.") :
                            String(format: appText("Widgets: %d · Visible: %d"), store.widgets.count, store.widgets.filter(\.isEnabled).count))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { editor = .init(original: nil) } label: {
                        Label(appText("Add Widget"), systemImage: "plus")
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(.vertical, 8)
            }
            Section {
                Toggle(isOn: $preferences.snapToGrid) {
                    Label(appText("Snap to grid"), systemImage: "square.grid.3x3")
                    Text(appText("Align widgets when you drop them. Turn off for free placement."))
                        .font(.caption).foregroundStyle(.secondary)
                }.toggleStyle(.switch)
                    .accessibilityLabel(appText("Snap to grid"))
                    .accessibilityHint(appText("Align widgets when you drop them. Turn off for free placement."))
            }
            if store.widgets.isEmpty {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: "rectangle.on.rectangle").font(.system(size: 40, weight: .light)).foregroundStyle(Color.accentColor)
                        Text(appText("A home for your favorite websites")).font(.headline)
                        Text(appText("Add a dashboard, a document, or a page you check often. Move and resize it right on your desktop."))
                            .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
                        Button(appText("Create your first widget")) { editor = .init(original: nil) }
                    }.frame(maxWidth: .infinity).padding(.vertical, 36)
                }
            } else {
                Section {
                    HStack(spacing: 14) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField(appText("Find by name or website"), text: $query).textFieldStyle(.plain)
                            if !query.isEmpty {
                                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.plain).help(appText("Clear search"))
                            }
                        }
                        Toggle(appText("Visible only"), isOn: $onlyEnabled).toggleStyle(.checkbox).fixedSize()
                    }.padding(.vertical, 4)
                }
                Section {
                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Text(appText("No matching widgets")).font(.headline)
                            Button(appText("Clear filters")) { query = ""; onlyEnabled = false }
                        }.frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                    ForEach(filtered) { widget in
                        WidgetSummaryRow(widget: widget, edit: { editor = .init(original: widget) },
                            toggle: { store.update(id: widget.id) { $0.isEnabled.toggle() } },
                            reload: { reload(widget.id) }, clearCookies: { clearingCookies = cookieScope(widget) }, delete: { deleting = widget })
                    }
                } footer: {
                    Text(appText("Move and resize widgets on your desktop. Open Edit for size, refresh, and interaction settings."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        // Attach presentation to a stable element even when the list becomes empty.
        .sheet(item: $editor) { request in
            WidgetEditor(original: request.original) { draft in
                if let original = request.original {
                    store.update(id: original.id) { current in
                        current = WidgetEdits.merging(original: original, edited: draft, current: current)
                    }
                } else {
                    store.add(draft)
                    query = ""; onlyEnabled = false
                }
                editor = nil
            }
        }
        .sheet(item: $clearingCookies) { scope in
            WebsiteCookieSheet(scope: scope, service: cookies)
        }
        .alert(appText("Delete this widget?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(appText("Cancel"), role: .cancel) { deleting = nil }
            Button(appText("Delete Widget"), role: .destructive) {
                if let deleting { store.remove(id: deleting.id) }
                deleting = nil
            }
        } message: { Text(appText("The widget settings will be removed. Website cookies are kept.")) }
    }
}

struct WidgetEditorRequest: Identifiable {
    let id = UUID()
    let original: WidgetConfig?
}

enum WidgetInput {
    static func validURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
}

/// Apply only edited fields so a desktop move or scroll save during editing is not lost.
enum WidgetEdits {
    static func merging(original: WidgetConfig, edited: WidgetConfig, current: WidgetConfig) -> WidgetConfig {
        var result = current
        if edited.name != original.name { result.name = edited.name }
        if edited.urlString != original.urlString {
            result.urlString = edited.urlString
            result.scrollX = 0; result.scrollY = 0
        }
        if edited.frame.x != original.frame.x { result.frame.x = edited.frame.x }
        if edited.frame.y != original.frame.y { result.frame.y = edited.frame.y }
        if edited.frame.width != original.frame.width { result.frame.width = edited.frame.width }
        if edited.frame.height != original.frame.height { result.frame.height = edited.frame.height }
        if edited.browsingMode != original.browsingMode { result.browsingMode = edited.browsingMode }
        if edited.reloadOnDeviceChange != original.reloadOnDeviceChange { result.reloadOnDeviceChange = edited.reloadOnDeviceChange }
        if edited.opacity != original.opacity { result.opacity = edited.opacity }
        if edited.isEnabled != original.isEnabled { result.isEnabled = edited.isEnabled }
        if edited.allowsInteraction != original.allowsInteraction { result.allowsInteraction = edited.allowsInteraction }
        if edited.refreshIntervalValue != original.refreshIntervalValue { result.refreshIntervalValue = edited.refreshIntervalValue }
        if edited.refreshIntervalUnit != original.refreshIntervalUnit { result.refreshIntervalUnit = edited.refreshIntervalUnit }
        return result
    }
}
