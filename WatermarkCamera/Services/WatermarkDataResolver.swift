import Foundation
import CoreLocation
import os

/// 将时间、地点、天气组装为 `WatermarkData`。
/// 任一环节失败都会优雅降级（对应字段留空），绝不阻断主流程。
final class WatermarkDataResolver: Sendable {
    private let location: LocationServicing
    private let weather: WeatherProviding
    private let metadata: MetadataServicing
    private let log = Logger(subsystem: "com.yeex.watermarkcamera", category: "WatermarkData")

    init(location: LocationServicing, weather: WeatherProviding, metadata: MetadataServicing) {
        self.location = location
        self.weather = weather
        self.metadata = metadata
    }

    /// 实时拍摄：使用当前时间与当前定位
    func resolveForCapture() async -> WatermarkData {
        let now = Date()
        let coordinate = await location.currentCoordinate()
        return await assemble(timestamp: now, coordinate: coordinate)
    }

    /// 历史媒体：使用其元数据；overrideCoordinate 用于用户手动选点
    func resolveForExisting(_ item: MediaItem,
                            overrideCoordinate: CLLocationCoordinate2D? = nil) async -> WatermarkData {
        let meta = await metadata.resolveMetadata(of: item)
        let timestamp = meta.date ?? item.creationDate ?? Date()
        let coordinate = overrideCoordinate ?? meta.coordinate ?? item.coordinate
        return await assemble(timestamp: timestamp, coordinate: coordinate)
    }

    // MARK: - 组装

    private func assemble(timestamp: Date, coordinate: CLLocationCoordinate2D?) async -> WatermarkData {
        var data = WatermarkData(timestamp: timestamp, coordinate: coordinate)
        guard let coordinate else { return data }

        // 地点与天气并行获取
        async let placeTask = location.placeName(for: coordinate)
        async let weatherTask: WeatherSnapshot? = fetchWeather(at: coordinate, time: timestamp)

        data.placeName = await placeTask
        data.weather = await weatherTask
        return data
    }

    /// 获取天气，失败时记录真实原因并降级为 nil（不阻断主流程）
    private func fetchWeather(at coordinate: CLLocationCoordinate2D, time: Date) async -> WeatherSnapshot? {
        do {
            return try await weather.weather(at: coordinate, time: time)
        } catch {
            log.error("WeatherKit 获取失败：\(error.localizedDescription, privacy: .public) — \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
