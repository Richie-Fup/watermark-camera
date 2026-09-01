import Foundation
import CoreLocation
import WeatherKit

/// 天气数据提供者。命名为 Provider 以避免与 WeatherKit.WeatherService 冲突。
protocol WeatherProviding: Sendable {
    /// 查询指定坐标、指定时间的天气快照。
    /// - time 接近当前时间时取实时天气；否则尝试历史小时数据；无法获取时抛错。
    func weather(at coordinate: CLLocationCoordinate2D, time: Date) async throws -> WeatherSnapshot
}

enum WeatherError: Error {
    case unavailable          // 超出历史范围或无数据
}

final class WeatherKitProvider: WeatherProviding {
    private let service = WeatherKit.WeatherService.shared
    private let cache = WeatherCache()

    func weather(at coordinate: CLLocationCoordinate2D, time: Date) async throws -> WeatherSnapshot {
        if let cached = await cache.value(for: coordinate, time: time) {
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let snapshot: WeatherSnapshot

        if Date().timeIntervalSince(time) < 3600 {
            // 最近一小时内 → 实时天气
            let current = try await service.weather(for: location, including: .current)
            snapshot = Self.makeSnapshot(condition: current.condition,
                                         symbol: current.symbolName,
                                         temperature: current.temperature)
        } else {
            // 历史时间 → 匹配最近的小时数据
            let start = time.addingTimeInterval(-3600)
            let end = time.addingTimeInterval(3600)
            let hourly = try await service.weather(for: location,
                                                   including: .hourly(startDate: start, endDate: end))
            guard let match = hourly.min(by: {
                abs($0.date.timeIntervalSince(time)) < abs($1.date.timeIntervalSince(time))
            }) else {
                throw WeatherError.unavailable
            }
            snapshot = Self.makeSnapshot(condition: match.condition,
                                         symbol: match.symbolName,
                                         temperature: match.temperature)
        }

        await cache.store(snapshot, for: coordinate, time: time)
        return snapshot
    }

    private static func makeSnapshot(condition: WeatherCondition,
                                     symbol: String,
                                     temperature: Measurement<UnitTemperature>) -> WeatherSnapshot {
        WeatherSnapshot(condition: condition.localizedDisplayName,
                        symbolName: symbol,
                        temperature: temperature)
    }
}

/// 以 (经纬度网格, 小时) 为 key 的内存缓存，降低 WeatherKit 配额消耗
private actor WeatherCache {
    private var storage: [String: WeatherSnapshot] = [:]

    private func key(_ coordinate: CLLocationCoordinate2D, _ time: Date) -> String {
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100
        let hour = Int(time.timeIntervalSince1970 / 3600)
        return "\(lat),\(lon),\(hour)"
    }

    func value(for coordinate: CLLocationCoordinate2D, time: Date) -> WeatherSnapshot? {
        storage[key(coordinate, time)]
    }

    func store(_ snapshot: WeatherSnapshot, for coordinate: CLLocationCoordinate2D, time: Date) {
        storage[key(coordinate, time)] = snapshot
    }
}

private extension WeatherCondition {
    /// 常见天气的本地化文案，未覆盖时回退系统英文描述
    var localizedDisplayName: String {
        switch self {
        case .clear, .mostlyClear: return String(localized: "Clear")
        case .partlyCloudy: return String(localized: "Cloudy")
        case .cloudy, .mostlyCloudy: return String(localized: "Overcast")
        case .foggy: return String(localized: "Fog")
        case .haze: return String(localized: "Haze")
        case .rain, .drizzle: return String(localized: "Rain")
        case .heavyRain: return String(localized: "Heavy Rain")
        case .snow, .flurries: return String(localized: "Snow")
        case .heavySnow: return String(localized: "Heavy Snow")
        case .sleet, .wintryMix: return String(localized: "Sleet")
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms:
            return String(localized: "Thunderstorm")
        case .windy, .breezy: return String(localized: "Windy")
        default: return self.description
        }
    }
}
