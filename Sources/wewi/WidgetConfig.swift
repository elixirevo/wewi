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

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        frame: WidgetFrame,
        opacity: Double = 1.0,
        isEnabled: Bool = true,
        allowsInteraction: Bool = true
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.frame = frame
        self.opacity = opacity
        self.isEnabled = isEnabled
        self.allowsInteraction = allowsInteraction
    }

    var url: URL? {
        URL(string: urlString)
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
