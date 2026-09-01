import Foundation

/// 天气快照（来自 WeatherKit 或降级为空）
struct WeatherSnapshot: Sendable, Equatable {
    let condition: String          // 本地化天气描述，如“多云”
    let symbolName: String         // SF Symbol 名称，如 "cloud.fill"
    let temperature: Measurement<UnitTemperature>

    /// 按用户偏好格式化气温，如 "26°C"
    func formattedTemperature(unit: UnitTemperature) -> String {
        let converted = temperature.converted(to: unit)
        let value = Int(converted.value.rounded())
        let symbol = unit == .celsius ? "°C" : "°F"
        return "\(value)\(symbol)"
    }
}
