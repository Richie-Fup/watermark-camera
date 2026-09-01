import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// PHPicker 的 SwiftUI 封装。选取后将资源拷贝到临时目录并回调 MediaItem 数组。
/// 使用 PHPicker 无需申请完整相册权限，隐私友好。
struct PhotoPicker: UIViewControllerRepresentable {
    var selectionLimit: Int = 0   // 0 表示不限
    var onComplete: ([MediaItem]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = selectionLimit
        config.filter = .any(of: [.images, .videos])
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([MediaItem]) -> Void
        init(onComplete: @escaping ([MediaItem]) -> Void) { self.onComplete = onComplete }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { onComplete([]); return }

            Task {
                var items: [MediaItem] = []
                for result in results {
                    if let item = await Self.loadItem(from: result.itemProvider) {
                        items.append(item)
                    }
                }
                await MainActor.run { self.onComplete(items) }
            }
        }

        private static func loadItem(from provider: NSItemProvider) async -> MediaItem? {
            let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            let typeID = isVideo ? UTType.movie.identifier : UTType.image.identifier
            guard provider.hasItemConformingToTypeIdentifier(typeID) else { return nil }

            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, _ in
                    guard let url else { continuation.resume(returning: nil); return }
                    // 拷贝到临时目录（回调返回后原文件会被清理）
                    let dest = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension)
                    try? FileManager.default.copyItem(at: url, to: dest)
                    let item = MediaItem(type: isVideo ? .video : .photo, sourceURL: dest)
                    continuation.resume(returning: item)
                }
            }
        }
    }
}
