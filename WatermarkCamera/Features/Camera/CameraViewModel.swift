import Foundation
import SwiftUI
import AVFoundation

@MainActor
@Observable
final class CameraViewModel {
    enum Status: Equatable {
        case idle, configuring, ready, denied, processing, recording
    }

    private(set) var status: Status = .idle
    private(set) var liveData: WatermarkData = WatermarkData()
    private(set) var recordingStartDate: Date?   // 录制开始时间，供计时提示
    var toast: String?

    private let deps: AppDependencies
    private var didConfigure = false

    init(deps: AppDependencies) {
        self.deps = deps
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        deps.cameraService.previewLayer
    }

    var isRecording: Bool { status == .recording }

    // MARK: - 生命周期

    func onAppear() async {
        deps.locationService.requestAuthorization()
        guard !didConfigure else {
            await deps.cameraService.startSession()
            await refreshLiveData()
            await ensureLiveDataReady()
            return
        }
        status = .configuring
        do {
            try await deps.cameraService.configure()
            didConfigure = true
            await deps.cameraService.startSession()
            status = .ready
            await refreshLiveData()
            // 首次启动时定位可能尚未授权，延迟重试直到天气/地点就绪
            await ensureLiveDataReady()
        } catch {
            status = .denied
        }
    }

    /// 若天气数据缺失（通常因为定位未就绪），延迟重试直到数据到位
    private func ensureLiveDataReady() async {
        guard liveData.weather == nil else { return }
        // 指数退避: 1s → 2s → 3s → 5s → 8s，最多尝试 5 次
        let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(3), .seconds(5), .seconds(8)]
        for delay in delays {
            try? await Task.sleep(for: delay)
            guard liveData.weather == nil else { return }
            await refreshLiveData()
        }
    }

    func onDisappear() async {
        await deps.cameraService.stopSession()
    }

    /// 刷新实时水印数据（地点/天气），供预览显示
    func refreshLiveData() async {
        liveData = await deps.processing.resolveDataForCapture()
    }

    // MARK: - 操作

    func capturePhoto(template: WatermarkTemplateSnapshot) async {
        guard status == .ready else { return }
        status = .processing
        defer { status = .ready }
        do {
            let photo = try await deps.cameraService.capturePhoto()
            let data = await deps.processing.resolveDataForCapture()
            liveData = data
            try await deps.processing.processAndSavePhoto(
                image: photo.image, data: data, template: template)
            toast = String(localized: "Saved to Photos")
        } catch {
            toast = String(format: String(localized: "Capture failed: %@"), error.localizedDescription)
        }
    }

    func toggleRecording(template: WatermarkTemplateSnapshot) async {
        if isRecording {
            await stopRecording(template: template)
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        guard status == .ready else { return }
        do {
            try await deps.cameraService.startRecording()
            recordingStartDate = Date()
            status = .recording
        } catch {
            toast = String(format: String(localized: "Recording failed: %@"), error.localizedDescription)
        }
    }

    private func stopRecording(template: WatermarkTemplateSnapshot) async {
        recordingStartDate = nil
        do {
            let url = try await deps.cameraService.stopRecording()
            status = .processing
            let data = await deps.processing.resolveDataForCapture()
            try await deps.processing.processAndSaveVideo(
                videoURL: url, data: data, template: template)
            toast = String(localized: "Video saved to Photos")
        } catch {
            toast = String(format: String(localized: "Video processing failed: %@"), error.localizedDescription)
        }
        status = .ready
    }

    func switchCamera() async {
        await deps.cameraService.switchCamera()
    }
}
