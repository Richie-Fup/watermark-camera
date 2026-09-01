import Foundation
import SwiftData

/// 首次启动时植入内置水印模板；已有库则把旧中文名迁移为可本地化的英文键名。
enum TemplateSeeder {
    static func seedIfNeeded(context: ModelContext) {
        migrateLegacyBuiltInNames(context: context)

        let descriptor = FetchDescriptor<WatermarkTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        for template in builtInTemplates() {
            context.insert(template)
        }
        try? context.save()
    }

    /// 将已安装用户的中文内置模板名改为英文键，便于跟随系统语言显示。
    private static func migrateLegacyBuiltInNames(context: ModelContext) {
        let descriptor = FetchDescriptor<WatermarkTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        guard let templates = try? context.fetch(descriptor) else { return }

        let mapping: [String: String] = [
            "今日 · 全信息": "Today · Full Info",
            "简约 · 仅时间地点": "Minimal · Time & Place",
            "天气 · 打卡": "Weather · Check-in"
        ]
        var changed = false
        for template in templates {
            if let updated = mapping[template.name] {
                template.name = updated
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    static func builtInTemplates() -> [WatermarkTemplate] {
        let prefersChinese = Locale.current.language.languageCode?.identifier == "zh"
        let fullDateFormat = prefersChinese ? "yyyy年M月d日 HH:mm" : "MMM d, yyyy HH:mm"

        return [
            WatermarkTemplate(
                name: "Today · Full Info",
                enabledFields: .all,
                position: .bottomLeading,
                fontName: "HelveticaNeue-Bold",
                fontSize: 40,
                textColorHex: "#FFFFFF",
                backgroundStyle: .shadow,
                opacity: 1.0,
                dateFormat: "yyyy.MM.dd HH:mm",
                isBuiltIn: true
            ),
            WatermarkTemplate(
                name: "Minimal · Time & Place",
                enabledFields: [.time, .place],
                position: .bottomTrailing,
                fontName: "HelveticaNeue-Medium",
                fontSize: 32,
                textColorHex: "#FFFFFF",
                backgroundStyle: .translucent,
                opacity: 0.95,
                dateFormat: fullDateFormat,
                isBuiltIn: true
            ),
            WatermarkTemplate(
                name: "Weather · Check-in",
                enabledFields: [.time, .weekday, .weather, .temperature],
                position: .topLeading,
                fontName: "HelveticaNeue-Bold",
                fontSize: 36,
                textColorHex: "#FFE44D",
                backgroundStyle: .shadow,
                opacity: 1.0,
                dateFormat: "HH:mm",
                isBuiltIn: true
            )
        ]
    }
}
