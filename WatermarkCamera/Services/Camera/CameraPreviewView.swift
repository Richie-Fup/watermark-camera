import SwiftUI
import AVFoundation

/// 将 AVCaptureVideoPreviewLayer 桥接到 SwiftUI
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // 预览层尺寸由 layoutSubviews 在 bounds 变化时自动同步，无需在每次刷新时强制重排
    }

    final class PreviewUIView: UIView {
        weak var previewLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
