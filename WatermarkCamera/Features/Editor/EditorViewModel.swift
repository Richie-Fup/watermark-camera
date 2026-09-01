import Foundation
import SwiftUI
import CoreLocation
import AVFoundation

@MainActor
@Observable
final class EditorViewModel {
    let item: MediaItem
    private let deps: AppDependencies

    private(set) var data = WatermarkData()
    private(set) var sourceImage: UIImage?     // 照片原图（供保存合成）
    private(set) var previewImage: UIImage?     // 预览图：照片=原图，视频=封面帧
    private(set) var isLoading = true
    private(set) var isSaving = false
    var toast: String?
    var didSaveSuccessfully = false
    var overrideCoordinate: CLLocationCoordinate2D?

    init(item: MediaItem, deps: AppDependencies) {
        self.item = item
        self.deps = deps
    }

    var isVideo: Bool { item.type == .video }

    /// 是否缺少定位（无法反查地点/天气），需提示用户手动选点
    var needsManualLocation: Bool {
        data.coordinate == nil
    }

    func load() async {
        isLoading = true
        switch item.type {
        case .photo:
            if sourceImage == nil, let url = item.sourceURL {
                sourceImage = UIImage(contentsOfFile: url.path)
            }
            previewImage = sourceImage
        case .video:
            if previewImage == nil, let url = item.sourceURL {
                previewImage = await Self.posterFrame(for: url)
            }
        }
        data = await deps.processing.resolveDataForExisting(item, overrideCoordinate: overrideCoordinate)
        isLoading = false
    }

    /// 抽取视频首帧作为预览封面（保留拍摄方向）
    private static func posterFrame(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1080, height: 1080)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cgImage = try? await generator.image(at: time).image else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// 用户在地图上手动选点后调用
    func applyManualLocation(_ coordinate: CLLocationCoordinate2D) async {
        overrideCoordinate = coordinate
        await load()
    }

    /// 保存到相册
    func save(template: WatermarkTemplateSnapshot) async {
        isSaving = true
        defer { isSaving = false }
        do {
            switch item.type {
            case .photo:
                guard let image = sourceImage else { throw ExportError.saveFailed }
                try await deps.processing.processAndSavePhoto(
                    image: image, data: data, template: template, sourceURL: item.sourceURL)
            case .video:
                guard let url = item.sourceURL else { throw ExportError.saveFailed }
                try await deps.processing.processAndSaveVideo(
                    videoURL: url, data: data, template: template)
            }
            didSaveSuccessfully = true
            toast = String(localized: "Saved to Photos")
        } catch {
            didSaveSuccessfully = false
            toast = String(format: String(localized: "Save failed: %@"), error.localizedDescription)
        }
    }
}
