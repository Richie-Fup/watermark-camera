import Foundation
import CoreLocation

/// 定位与反地理编码服务
protocol LocationServicing: AnyObject, Sendable {
    /// 请求“使用期间”定位权限
    func requestAuthorization()
    /// 获取当前坐标（若无权限或失败返回 nil）
    func currentCoordinate() async -> CLLocationCoordinate2D?
    /// 反地理编码为地点文案，如“上海市·浦东新区”
    func placeName(for coordinate: CLLocationCoordinate2D) async -> String?
}

final class LocationService: NSObject, LocationServicing, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    private let lock = NSLock()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func currentCoordinate() async -> CLLocationCoordinate2D? {
        // 仅当缓存定位“新且精确”时直接复用（≤30s、水平精度优于50米）
        if let cached = manager.location,
           cached.horizontalAccuracy >= 0,
           cached.horizontalAccuracy <= 50,
           Date().timeIntervalSince(cached.timestamp) < 30 {
            return cached.coordinate
        }
        return await withCheckedContinuation { continuation in
            lock.lock()
            continuations.append(continuation)
            lock.unlock()
            manager.requestLocation()
        }
    }

    func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }
        // 由粗到细拼接，提升精确度：市/区 · 街道/地标
        let city = placemark.locality ?? placemark.administrativeArea
        let district = placemark.subLocality ?? placemark.subAdministrativeArea
        let street = placemark.thoroughfare ?? placemark.name
        let parts = [city, district, street]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        // 去重（避免“名称”与“街道”重复）
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique.joined(separator: "·")
    }

    // MARK: - CLLocationManagerDelegate

    /// 用户授权状态变更时自动触发定位请求，确保授权一授予就有坐标缓存可用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }

        // 首次授权后主动获取初始定位；若恰好有等待中的 continuation 则一并满足
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(with: locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: nil)
    }

    private func resume(with coordinate: CLLocationCoordinate2D?) {
        lock.lock()
        let pending = continuations
        continuations.removeAll()
        lock.unlock()
        pending.forEach { $0.resume(returning: coordinate) }
    }
}
