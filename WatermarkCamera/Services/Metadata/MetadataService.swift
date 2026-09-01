import Foundation
import CoreLocation
import ImageIO
import AVFoundation

/// 读取媒体文件的拍摄时间与 GPS 元数据
protocol MetadataServicing: Sendable {
    func creationDate(of item: MediaItem) async -> Date?
    func coordinate(of item: MediaItem) async -> CLLocationCoordinate2D?
    /// 一次性读取时间与坐标
    func resolveMetadata(of item: MediaItem) async -> (date: Date?, coordinate: CLLocationCoordinate2D?)
}

final class MetadataService: MetadataServicing {

    func creationDate(of item: MediaItem) async -> Date? {
        await resolveMetadata(of: item).date
    }

    func coordinate(of item: MediaItem) async -> CLLocationCoordinate2D? {
        await resolveMetadata(of: item).coordinate
    }

    func resolveMetadata(of item: MediaItem) async -> (date: Date?, coordinate: CLLocationCoordinate2D?) {
        // 已在导入时带出的元数据优先
        if item.creationDate != nil || item.coordinate != nil {
            return (item.creationDate, item.coordinate)
        }
        guard let url = item.sourceURL else { return (nil, nil) }
        switch item.type {
        case .photo: return readPhotoMetadata(url: url)
        case .video: return await readVideoMetadata(url: url)
        }
    }

    // MARK: - 照片 EXIF / GPS

    private func readPhotoMetadata(url: URL) -> (Date?, CLLocationCoordinate2D?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (nil, nil)
        }

        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            date = formatter.date(from: dateString)
        }

        var coordinate: CLLocationCoordinate2D?
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"
            coordinate = CLLocationCoordinate2D(
                latitude: latRef == "S" ? -lat : lat,
                longitude: lonRef == "W" ? -lon : lon
            )
        }
        return (date, coordinate)
    }

    // MARK: - 视频元数据

    private func readVideoMetadata(url: URL) async -> (Date?, CLLocationCoordinate2D?) {
        let asset = AVURLAsset(url: url)
        var date: Date?
        var coordinate: CLLocationCoordinate2D?

        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key = item.commonKey else { continue }
                if key == .commonKeyCreationDate {
                    if let dateValue = try? await item.load(.dateValue) {
                        date = dateValue
                    } else if let str = try? await item.load(.stringValue) {
                        date = ISO8601DateFormatter().date(from: str)
                    }
                }
                if key == .commonKeyLocation, let str = try? await item.load(.stringValue) {
                    coordinate = Self.parseISO6709(str)
                }
            }
        }

        if date == nil, let created = try? await asset.load(.creationDate)?.load(.dateValue) {
            date = created
        }
        return (date, coordinate)
    }

    /// 解析 ISO6709 位置字符串，如 "+31.2304+121.4737/"
    static func parseISO6709(_ string: String) -> CLLocationCoordinate2D? {
        let pattern = #"([+-]\d+\.?\d*)([+-]\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let latRange = Range(match.range(at: 1), in: string),
              let lonRange = Range(match.range(at: 2), in: string),
              let lat = Double(string[latRange]),
              let lon = Double(string[lonRange]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
