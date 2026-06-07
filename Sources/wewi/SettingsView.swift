import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var store: WidgetStore
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    @State private var draftName = ""
    @State private var draftURL = "https://example.com"
    @State private var draftWidth = "480"
    @State private var draftHeight = "320"
    @State private var selectedPresetID: String = WidgetSizePreset.presets[2].id
    @State private var previousWidgetIDs: [UUID] = []

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#071223"), Color(hex: "#0A1B31"), Color(hex: "#061325")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                headlineRow

                HStack(alignment: .top, spacing: 14) {
                    createPanel
                        .frame(width: 290)

                    widgetListPanel
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
                .offset(y: -12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 980, idealWidth: 980, maxWidth: 980, minHeight: 682, idealHeight: 682, maxHeight: 682)
    }

    private var headlineRow: some View {
        HStack(alignment: .center) {
            BrandLogo()
                .frame(maxHeight: .infinity, alignment: .center)

            Spacer()

            HStack(spacing: 10) {
                StatCard(title: "TOTAL WIDGETS", value: "\(store.widgets.count)")
                StatCard(title: "ACTIVE NOW", value: "\(store.widgets.filter { $0.isEnabled }.count)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 1)
    }

    private var createPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Create New Widget", systemImage: "plus.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { launchAtLoginManager.setEnabled($0) }
                )
            )
            .toggleStyle(.switch)
            .foregroundStyle(.white)

            if let error = launchAtLoginManager.lastErrorMessage, !error.isEmpty {
                Text(error)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red.opacity(0.9))
            }

            panelLabel("Name")
            TextField("Enter widget name...", text: $draftName)
                .wewiFieldStyle()

            panelLabel("URL")
            TextField("https://example.com", text: $draftURL)
                .wewiFieldStyle()

            panelLabel("Size Presets")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(WidgetSizePreset.presets) { preset in
                    Button {
                        selectedPresetID = preset.id
                        draftWidth = String(Int(preset.width))
                        draftHeight = String(Int(preset.height))
                    } label: {
                        SizePresetMini(preset: preset, selected: selectedPresetID == preset.id)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    panelLabel("WIDTH")
                    TextField("480", text: $draftWidth)
                        .wewiFieldStyle()
                }

                VStack(alignment: .leading, spacing: 4) {
                    panelLabel("HEIGHT")
                    TextField("320", text: $draftHeight)
                        .wewiFieldStyle()
                }
            }

            Button {
                addWidget()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Widget")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#1D7BFF"), Color(hex: "#175DFF")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(14)
        .glassContainer(cornerRadius: 18)
    }

    private var widgetListPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Widget List", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            if store.widgets.isEmpty {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.45))
                            Text("Drag and drop to reorder your widgets.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.widgets) { widget in
                                WidgetRow(widget: widget, onSave: { updated in
                                    store.update(updated)
                                }, onDelete: {
                                    store.remove(id: widget.id)
                                })
                                .id(widget.id)
                            }
                        }
                        .padding(.trailing, 10)
                    }
                    .onAppear {
                        previousWidgetIDs = store.widgets.map(\.id)
                    }
                    .onChange(of: store.widgets.map(\.id)) { ids in
                        let oldSet = Set(previousWidgetIDs)
                        let added = ids.filter { !oldSet.contains($0) }
                        if let newestAdded = added.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(newestAdded, anchor: .bottom)
                            }
                        }
                        previousWidgetIDs = ids
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .glassContainer(cornerRadius: 18)
    }

    private func panelLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.58))
    }

    private func addWidget() {
        guard let width = Double(draftWidth),
              let height = Double(draftHeight),
              !draftURL.isEmpty else {
            return
        }

        let name = draftName.isEmpty ? "Widget \(store.widgets.count + 1)" : draftName
        let widget = WidgetConfig(
            name: name,
            urlString: draftURL,
            frame: WidgetFrame(x: 80, y: 80, width: max(180, width), height: max(120, height)),
            opacity: 1.0,
            isEnabled: true,
            allowsInteraction: true,
            refreshIntervalValue: 0,
            refreshIntervalUnit: .seconds
        )
        store.add(widget)
        draftName = ""
    }
}
