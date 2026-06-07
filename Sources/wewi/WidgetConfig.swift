import CoreGraphics
import Foundation

struct WidgetConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var urlString: String
    var frame: WidgetFrame
    var opacity: Double
    var isEnabled: Bool
    var allowsInteraction: Bool
    var refreshIntervalValue: Double
    var refreshIntervalUnit: WidgetRefreshIntervalUnit
    var scrollX: Double
    var scrollY: Double

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        frame: WidgetFrame,
        opacity: Double = 1.0,
        isEnabled: Bool = true,
        allowsInteraction: Bool = true,
        refreshIntervalValue: Double = 0,
        refreshIntervalUnit: WidgetRefreshIntervalUnit = .seconds,
        scrollX: Double = 0,
        scrollY: Double = 0
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.frame = frame
        self.opacity = opacity
        self.isEnabled = isEnabled
        self.allowsInteraction = allowsInteraction
        self.refreshIntervalValue = refreshIntervalValue
        self.refreshIntervalUnit = refreshIntervalUnit
        self.scrollX = scrollX
        self.scrollY = scrollY
    }

    var url: URL? {
        URL(string: urlString)
    }

    var normalizedRefreshIntervalSeconds: Double {
        refreshIntervalUnit.seconds(for: normalizedRefreshIntervalValue)
    }

    var normalizedRefreshIntervalValue: Double {
        refreshIntervalValue > 0 ? max(1, refreshIntervalValue.rounded()) : 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case urlString
        case frame
        case opacity
        case isEnabled
        case allowsInteraction
        case refreshIntervalValue
        case refreshIntervalUnit
        case refreshIntervalSeconds
        case scrollX
        case scrollY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        urlString = try container.decode(String.self, forKey: .urlString)
        frame = try container.decode(WidgetFrame.self, forKey: .frame)
        opacity = try container.decode(Double.self, forKey: .opacity)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        allowsInteraction = try container.decode(Bool.self, forKey: .allowsInteraction)

        if let value = try container.decodeIfPresent(Double.self, forKey: .refreshIntervalValue) {
            refreshIntervalValue = value
            let rawUnit = try container.decodeIfPresent(String.self, forKey: .refreshIntervalUnit)
            refreshIntervalUnit = rawUnit.flatMap(WidgetRefreshIntervalUnit.init(rawValue:)) ?? .seconds
        } else {
            refreshIntervalValue = try container.decodeIfPresent(Double.self, forKey: .refreshIntervalSeconds) ?? 0
            refreshIntervalUnit = .seconds
        }

        scrollX = try container.decodeIfPresent(Double.self, forKey: .scrollX) ?? 0
        scrollY = try container.decodeIfPresent(Double.self, forKey: .scrollY) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(urlString, forKey: .urlString)
        try container.encode(frame, forKey: .frame)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(allowsInteraction, forKey: .allowsInteraction)
        try container.encode(normalizedRefreshIntervalValue, forKey: .refreshIntervalValue)
        try container.encode(refreshIntervalUnit, forKey: .refreshIntervalUnit)
        try container.encode(max(0, scrollX.rounded()), forKey: .scrollX)
        try container.encode(max(0, scrollY.rounded()), forKey: .scrollY)
    }
}

enum WidgetRefreshIntervalUnit: String, Codable, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours

    var id: String { rawValue }

    var label: String {
        switch self {
        case .seconds: "sec"
        case .minutes: "min"
        case .hours: "hr"
        }
    }

    func seconds(for value: Double) -> Double {
        let normalizedValue = value > 0 ? max(1, value.rounded()) : 0
        switch self {
        case .seconds:
            return normalizedValue
        case .minutes:
            return normalizedValue * 60
        case .hours:
            return normalizedValue * 60 * 60
        }
    }
}

struct WidgetFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    static func from(_ rect: CGRect) -> WidgetFrame {
        WidgetFrame(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height
        )
    }
}
