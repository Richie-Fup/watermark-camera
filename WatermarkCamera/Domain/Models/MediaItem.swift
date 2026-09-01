import Foundation
import CoreLocation

/// 一次媒体处理项（来自相机拍摄或相册导入）
struct MediaItem: Identifiable, Hashable, Sendable {
    let id: String                 // PHAsset.localIdentifier 或临时文件路径
    let type: MediaType
    let sourceURL: URL?
    var creationDate: Date?
    var coordinate: CLLocationCoordinate2D?

    init(id: String = UUID().uuidString,
         type: MediaType,
         sourceURL: URL? = nil,
         creationDate: Date? = nil,
         coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.type = type
        self.sourceURL = sourceURL
        self.creationDate = creationDate
        self.coordinate = coordinate
    }

    // 基于稳定的 id 做等价与哈希（坐标类型不满足 Hashable）
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
