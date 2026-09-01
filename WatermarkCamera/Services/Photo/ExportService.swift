import Foundation
import Photos
import UIKit

/// 将处理后的媒体保存到相册
protocol ExportServicing: Sendable {
    func saveImage(_ data: Data) async throws
    func saveVideo(at url: URL) async throws
}

enum ExportError: Error {
    case notAuthorized
    case saveFailed
}

final class ExportService: ExportServicing {

    private func ensureAuthorization() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited: return
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else { throw ExportError.notAuthorized }
        default:
            throw ExportError.notAuthorized
        }
    }

    func saveImage(_ data: Data) async throws {
        try await ensureAuthorization()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    func saveVideo(at url: URL) async throws {
        try await ensureAuthorization()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: url, options: nil)
        }
    }
}
