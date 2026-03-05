import AppKit
import SwiftUI

struct BrandLogo: View {
    var body: some View {
        HStack(spacing: 12) {
            logoImage
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("wewi")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                Text("CONTROL CENTER")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.vertical, 2)
    }

    private var logoImage: some View {
        Group {
            if let url = Bundle.main.url(forResource: "icon", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "safari")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

@MainActor
struct WidgetRow: View {
    let widget: WidgetConfig
    let onSave: (WidgetConfig) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var url: String
    @State private var x: String
    @State private var y: String
    @State private var width: String
    @State private var height: String
    @State private var opacity: Double
    @State private var isEnabled: Bool
    @State private var allowsInteraction: Bool

    init(widget: WidgetConfig, onSave: @escaping (WidgetConfig) -> Void, onDelete: @escaping () -> Void) {
        self.widget = widget
        self.onSave = onSave
        self.onDelete = onDelete

        _name = State(initialValue: widget.name)
        _url = State(initialValue: widget.urlString)
        _x = State(initialValue: String(Int(widget.frame.x)))
        _y = State(initialValue: String(Int(widget.frame.y)))
        _width = State(initialValue: String(Int(widget.frame.width)))
        _height = State(initialValue: String(Int(widget.frame.height)))
        _opacity = State(initialValue: widget.opacity)
        _isEnabled = State(initialValue: widget.isEnabled)
        _allowsInteraction = State(initialValue: widget.allowsInteraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#1D7BFF"))
                        .frame(width: 22, height: 22)
                    Text(shortID)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }

                TextField("Name", text: $name)
                    .wewiFieldStyle()
                    .onChange(of: name) { _ in pushNonFrameUpdate() }

                Toggle("Enabled", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: isEnabled) { _ in pushNonFrameUpdate() }

                Toggle(
                    "Screen Lock",
                    isOn: Binding(
                        get: { !allowsInteraction },
                        set: { newValue in
                            allowsInteraction = !newValue
                            pushNonFrameUpdate()
                        }
                    )
                )
                .toggleStyle(.switch)
                .labelsHidden()

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete widget")
            }

            TextField("URL", text: $url)
                .wewiFieldStyle()
                .onChange(of: url) { _ in pushNonFrameUpdate() }

            HStack(spacing: 8) {
                Group {
                    metricField(label: "X", text: $x)
                    metricField(label: "Y", text: $y)
                    metricField(label: "W", text: $width)
                    metricField(label: "H", text: $height)
                }

                Text("Opacity")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Slider(value: $opacity, in: 0.1...1.0)
                    .tint(Color(hex: "#1D7BFF"))
                    .onChange(of: opacity) { _ in pushNonFrameUpdate() }

                Text("\(Int((opacity * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 44)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onChange(of: widget) { syncFromWidget($0) }
    }

    private var shortID: String {
        String(widget.id.uuidString.prefix(1))
    }

    private func metricField(label: String, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            TextField(label, text: text)
                .wewiFieldStyle()
                .frame(width: 60)
                .onChange(of: text.wrappedValue) { _ in pushFrameIfValid() }
        }
    }

    private func syncFromWidget(_ newWidget: WidgetConfig) {
        name = normalizedName(newWidget.name)
        url = newWidget.urlString
        x = String(Int(newWidget.frame.x))
        y = String(Int(newWidget.frame.y))
        width = String(Int(newWidget.frame.width))
        height = String(Int(newWidget.frame.height))
        opacity = newWidget.opacity
        isEnabled = newWidget.isEnabled
        allowsInteraction = newWidget.allowsInteraction
    }

    private func pushNonFrameUpdate() {
        var updated = widget
        updated.name = normalizedName(name)
        updated.urlString = url
        updated.opacity = max(0.1, min(1.0, opacity))
        updated.isEnabled = isEnabled
        updated.allowsInteraction = allowsInteraction
        onSave(updated)
    }

    private func pushFrameIfValid() {
        guard let px = Double(x),
              let py = Double(y),
              let pw = Double(width),
              let ph = Double(height) else { return }

        var updated = widget
        updated.name = normalizedName(name)
        updated.urlString = url
        updated.frame = WidgetFrame(x: px, y: py, width: max(180, pw), height: max(120, ph))
        updated.opacity = max(0.1, min(1.0, opacity))
        updated.isEnabled = isEnabled
        updated.allowsInteraction = allowsInteraction
        onSave(updated)
    }

    private func normalizedName(_ raw: String) -> String {
        raw == "Untitled" ? "" : raw
    }
}

struct WidgetSizePreset: Identifiable {
    let id: String
    let name: String
    let width: Double
    let height: Double

    static let presets: [WidgetSizePreset] = [
        .init(id: "s", name: "S", width: 320, height: 180),
        .init(id: "m", name: "M", width: 480, height: 320),
        .init(id: "l", name: "L", width: 640, height: 360),
        .init(id: "xl", name: "XL", width: 800, height: 450),
        .init(id: "pv-s", name: "PV-S", width: 220, height: 360),
        .init(id: "pv-m", name: "PV-M", width: 300, height: 480),
        .init(id: "pv-l", name: "PV-L", width: 360, height: 640),
        .init(id: "pv-xl", name: "PV-XL", width: 420, height: 740)
    ]
}

struct SizePresetMini: View {
    let preset: WidgetSizePreset
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(preset.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)

            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                GeometryReader { geo in
                    let maxW = geo.size.width - 8
                    let maxH = geo.size.height - 8
                    let scale = min(maxW / preset.width, maxH / preset.height)
                    let w = preset.width * scale
                    let h = preset.height * scale
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: w, height: h)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            .frame(height: 28)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color(hex: "#1D7BFF").opacity(0.35) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? Color(hex: "#1D7BFF") : Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 162, height: 88, alignment: .leading)
        .glassContainer(cornerRadius: 14)
    }
}

extension View {
    func glassContainer(cornerRadius: CGFloat) -> some View {
        self
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    func wewiFieldStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
