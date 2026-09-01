import Foundation

/// 媒体类型
enum MediaType: String, Codable, Sendable {
    case photo
    case video
}

/// 水印锚点位置（九宫格）
enum WatermarkPosition: String, Codable, CaseIterable, Sendable {
    case topLeading, topCenter, topTrailing
    case centerLeading, center, centerTrailing
    case bottomLeading, bottomCenter, bottomTrailing

    var displayName: String {
        switch self {
        case .topLeading: return String(localized: "Top Left")
        case .topCenter: return String(localized: "Top Center")
        case .topTrailing: return String(localized: "Top Right")
        case .centerLeading: return String(localized: "Middle Left")
        case .center: return String(localized: "Center")
        case .centerTrailing: return String(localized: "Middle Right")
        case .bottomLeading: return String(localized: "Bottom Left")
        case .bottomCenter: return String(localized: "Bottom Center")
        case .bottomTrailing: return String(localized: "Bottom Right")
        }
    }

    /// 归一化锚点 (0,0)=左上, (1,1)=右下
    var unitPoint: (x: CGFloat, y: CGFloat) {
        let x: CGFloat
        switch self {
        case .topLeading, .centerLeading, .bottomLeading: x = 0
        case .topCenter, .center, .bottomCenter: x = 0.5
        case .topTrailing, .centerTrailing, .bottomTrailing: x = 1
        }
        let y: CGFloat
        switch self {
        case .topLeading, .topCenter, .topTrailing: y = 0
        case .centerLeading, .center, .centerTrailing: y = 0.5
        case .bottomLeading, .bottomCenter, .bottomTrailing: y = 1
        }
        return (x, y)
    }
}

/// 水印字段开关集合
struct WatermarkFieldSet: OptionSet, Codable, Sendable {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let time        = WatermarkFieldSet(rawValue: 1 << 0)
    static let weekday     = WatermarkFieldSet(rawValue: 1 << 1)
    static let place       = WatermarkFieldSet(rawValue: 1 << 2)
    static let weather     = WatermarkFieldSet(rawValue: 1 << 3)
    static let temperature = WatermarkFieldSet(rawValue: 1 << 4)

    static let all: WatermarkFieldSet = [.time, .weekday, .place, .weather, .temperature]
}

/// 背景样式
enum BackgroundStyle: String, Codable, CaseIterable, Sendable {
    case none        // 无背景（依赖阴影）
    case translucent // 半透明条
    case shadow      // 文字阴影

    var displayName: String {
        switch self {
        case .none: return String(localized: "None")
        case .translucent: return String(localized: "Translucent Bar")
        case .shadow: return String(localized: "Shadow")
        }
    }
}
