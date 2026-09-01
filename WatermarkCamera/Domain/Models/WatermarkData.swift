import Foundation
import CoreLocation

/// 水印所需的语义数据（渲染前的中间结果）
struct WatermarkData: Equatable, Sendable {
    var timestamp: Date
    var coordinate: CLLocationCoordinate2D?
    var placeName: String?
    var weather: WeatherSnapshot?

    init(timestamp: Date = Date(),
         coordinate: CLLocationCoordinate2D? = nil,
         placeName: String? = nil,
         weather: WeatherSnapshot? = nil) {
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.placeName = placeName
        self.weather = weather
    }

    static func == (lhs: WatermarkData, rhs: WatermarkData) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude &&
        lhs.placeName == rhs.placeName &&
        lhs.weather == rhs.weather
    }

    /// 返回仅替换时间戳的副本（用于实时预览逐秒刷新）
    func with(timestamp: Date) -> WatermarkData {
        var copy = self
        copy.timestamp = timestamp
        return copy
    }

    /// 本地化星期，如“星期二”
    func weekdayString(locale: Locale = .current) -> String {
        DateFormatterCache.shared.string(from: timestamp, format: "EEEE", locale: locale)
    }

    /// 按模板日期格式格式化时间
    func timeString(format: String, locale: Locale = .current) -> String {
        DateFormatterCache.shared.string(from: timestamp, format: format, locale: locale)
    }
}

/// 线程安全的 DateFormatter 复用缓存。
/// DateFormatter 创建成本较高，视频逐秒导出会大量调用，此处复用并在锁内完成格式化以保证线程安全。
final class DateFormatterCache: @unchecked Sendable {
    static let shared = DateFormatterCache()

    private var formatters: [String: DateFormatter] = [:]
    private let lock = NSLock()

    func string(from date: Date, format: String, locale: Locale) -> String {
        let key = locale.identifier + "|" + format
        lock.lock()
        defer { lock.unlock() }
        let formatter: DateFormatter
        if let cached = formatters[key] {
            formatter = cached
        } else {
            let created = DateFormatter()
            created.locale = locale
            created.dateFormat = format
            formatters[key] = created
            formatter = created
        }
        return formatter.string(from: date)
    }
}
