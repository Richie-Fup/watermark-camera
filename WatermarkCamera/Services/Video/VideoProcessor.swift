import Foundation
import AVFoundation
import UIKit

/// 将水印叠加到视频并导出
protocol VideoProcessing: Sendable {
    /// 合成水印并导出到临时文件，返回新视频 URL
    func compose(videoURL: URL,
                 data: WatermarkData,
                 template: WatermarkTemplateSnapshot) async throws -> URL
}

enum VideoProcessingError: Error {
    case noVideoTrack
    case exportFailed(String)
    case cannotCreateExportSession
}

final class VideoProcessor: VideoProcessing {
    private let renderer: WatermarkRendering

    init(renderer: WatermarkRendering) {
        self.renderer = renderer
    }

    func compose(videoURL: URL,
                 data: WatermarkData,
                 template: WatermarkTemplateSnapshot) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }

        let composition = AVMutableComposition()
        let assetDuration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: assetDuration)

        // 视频轨
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoProcessingError.noVideoTrack
        }
        try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

        // 音频轨（可选）
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }

        // 计算朝向与渲染尺寸
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let renderSize = Self.renderSize(naturalSize: naturalSize, transform: preferredTransform)

        // 视频合成指令
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Core Animation 图层：父层 = 视频层 + 水印层（时间行按秒动态刷新）
        let overlayLayer = renderer.makeVideoOverlayLayer(
            data: data, template: template, videoSize: renderSize,
            duration: CMTimeGetSeconds(assetDuration))
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        // 导出
        guard let export = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessingError.cannotCreateExportSession
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        export.outputURL = outputURL
        export.outputFileType = .mov
        export.videoComposition = videoComposition

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { continuation.resume() }
        }

        switch export.status {
        case .completed:
            return outputURL
        default:
            throw VideoProcessingError.exportFailed(
                export.error?.localizedDescription ?? String(localized: "Unknown error"))
        }
    }

    /// 依据 preferredTransform 计算正确的渲染尺寸（处理竖屏/横屏）
    private static func renderSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let transformed = naturalSize.applying(transform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }
}
