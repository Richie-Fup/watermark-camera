import Foundation
import UIKit
import CoreLocation
import ImageIO

/// 高层用例：把“采集/导入 → 解析水印数据 → 合成 → 导出”串起来。
/// 视图层只需调用这里的方法，无需关心底层服务编排。
final class WatermarkProcessingService {
    let resolver: WatermarkDataResolver
    private let imageProcessor: ImageProcessing
    private let videoProcessor: VideoProcessing
    private let export: ExportServicing

    init(resolver: WatermarkDataResolver,
         imageProcessor: ImageProcessing,
         videoProcessor: VideoProcessing,
         export: ExportServicing) {
        self.resolver = resolver
        self.imageProcessor = imageProcessor
        self.videoProcessor = videoProcessor
        self.export = export
    }

    // MARK: - 数据解析

    func resolveDataForCapture() async -> WatermarkData {
        await resolver.resolveForCapture()
    }

    func resolveDataForExisting(_ item: MediaItem,
                                overrideCoordinate: CLLocationCoordinate2D? = nil) async -> WatermarkData {
        await resolver.resolveForExisting(item, overrideCoordinate: overrideCoordinate)
    }

    // MARK: - 照片

    /// 合成照片（返回 JPEG 数据，供预览或保存）
    func composePhoto(image: UIImage,
                      data: WatermarkData,
                      template: WatermarkTemplateSnapshot,
                      sourceURL: URL? = nil) -> Data? {
        let metadata = sourceURL.flatMap(Self.readMetadata(from:))
        return imageProcessor.compose(image: image, data: data, template: template,
                                      originalMetadata: metadata)
    }

    /// 合成并保存照片到相册
    func processAndSavePhoto(image: UIImage,
                             data: WatermarkData,
                             template: WatermarkTemplateSnapshot,
                             sourceURL: URL? = nil) async throws {
        guard let jpeg = composePhoto(image: image, data: data, template: template, sourceURL: sourceURL) else {
            throw ExportError.saveFailed
        }
        try await export.saveImage(jpeg)
    }

    // MARK: - 视频

    /// 合成视频并保存到相册
    func processAndSaveVideo(videoURL: URL,
                             data: WatermarkData,
                             template: WatermarkTemplateSnapshot) async throws {
        let outputURL = try await videoProcessor.compose(videoURL: videoURL, data: data, template: template)
        try await export.saveVideo(at: outputURL)
    }

    // MARK: - 工具

    private static func readMetadata(from url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return props
    }
}
