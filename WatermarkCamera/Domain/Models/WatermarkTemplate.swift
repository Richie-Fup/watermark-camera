import Foundation
import SwiftData
import SwiftUI

/// 水印模板（可持久化）
@Model
final class WatermarkTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var enabledFieldsRaw: Int
    var positionRaw: String
    var fontName: String
    var fontSize: Double
    var textColorHex: String
    var backgroundStyleRaw: String
    var opacity: Double
    var dateFormat: String
    var isBuiltIn: Bool
    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         enabledFields: WatermarkFieldSet = .all,
         position: WatermarkPosition = .bottomLeading,
         fontName: String = "HelveticaNeue-Medium",
         fontSize: Double = 34,
         textColorHex: String = "#FFFFFF",
         backgroundStyle: BackgroundStyle = .shadow,
         opacity: Double = 1.0,
         dateFormat: String = "yyyy.MM.dd HH:mm",
         isBuiltIn: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.enabledFieldsRaw = enabledFields.rawValue
        self.positionRaw = position.rawValue
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.backgroundStyleRaw = backgroundStyle.rawValue
        self.opacity = opacity
        self.dateFormat = dateFormat
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }

    // MARK: - 类型安全访问器

    var enabledFields: WatermarkFieldSet {
        get { WatermarkFieldSet(rawValue: enabledFieldsRaw) }
        set { enabledFieldsRaw = newValue.rawValue }
    }

    var position: WatermarkPosition {
        get { WatermarkPosition(rawValue: positionRaw) ?? .bottomLeading }
        set { positionRaw = newValue.rawValue }
    }

    var backgroundStyle: BackgroundStyle {
        get { BackgroundStyle(rawValue: backgroundStyleRaw) ?? .shadow }
        set { backgroundStyleRaw = newValue.rawValue }
    }

    /// 内置模板名以英文为键，按系统语言本地化；自定义模板原样显示。
    var localizedName: String {
        if isBuiltIn {
            String(localized: String.LocalizationValue(name))
        } else {
            name
        }
    }

    /// 生成一个值类型快照，供渲染层在后台线程安全使用
    func snapshot() -> WatermarkTemplateSnapshot {
        WatermarkTemplateSnapshot(
            name: name,
            enabledFields: enabledFields,
            position: position,
            fontName: fontName,
            fontSize: fontSize,
            textColorHex: textColorHex,
            backgroundStyle: backgroundStyle,
            opacity: opacity,
            dateFormat: dateFormat
        )
    }
}

/// 模板的不可变值类型快照（`Sendable`，可跨线程传给渲染管线）
struct WatermarkTemplateSnapshot: Sendable, Equatable {
    var name: String
    var enabledFields: WatermarkFieldSet
    var position: WatermarkPosition
    var fontName: String
    var fontSize: Double
    var textColorHex: String
    var backgroundStyle: BackgroundStyle
    var opacity: Double
    var dateFormat: String
}
