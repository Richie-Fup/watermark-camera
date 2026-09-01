import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// 将水印叠加层合成到照片，并尽量保留原始元数据
protocol ImageProcessing: Sendable {
    /// 合成并返回带元数据的 JPEG 数据
    func compose(image: UIImage,
                 data: WatermarkData,
                 template: WatermarkTemplateSnapshot,
                 originalMetadata: [CFString: Any]?) -> Data?
}

final class ImageProcessor: ImageProcessing {
    private let renderer: WatermarkRendering

    init(renderer: WatermarkRendering) {
        self.renderer = renderer
    }

    func compose(image: UIImage,
                 data: WatermarkData,
                 template: WatermarkTemplateSnapshot,
                 originalMetadata: [CFString: Any]?) -> Data? {
        // 先按 EXIF 朝向归一化到 .up，保证水印方向正确
        let normalized = image.normalizedOrientation()
        let size = normalized.size

        let overlay = renderer.makeOverlayImage(data: data, template: template, canvasSize: size)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let composited = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: size))
            overlay.draw(in: CGRect(origin: .zero, size: size))
        }

        return encodeJPEG(composited, metadata: originalMetadata)
    }

    /// 编码为 JPEG，并写回原始元数据（EXIF/GPS）
    private func encodeJPEG(_ image: UIImage, metadata: [CFString: Any]?) -> Data? {
        guard let cgImage = image.cgImage else {
            return image.jpegData(compressionQuality: 0.92)
        }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return image.jpegData(compressionQuality: 0.92)
        }

        var props = metadata ?? [:]
        props[kCGImageDestinationLossyCompressionQuality] = 0.92

        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return image.jpegData(compressionQuality: 0.92)
        }
        return mutableData as Data
    }
}

extension UIImage {
    /// 将图片重绘为 .up 朝向
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
