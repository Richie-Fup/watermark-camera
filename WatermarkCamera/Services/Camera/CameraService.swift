import Foundation
import AVFoundation
import UIKit

/// 拍摄结果
struct CapturedPhoto: Sendable {
    let image: UIImage
    let orientation: UIImage.Orientation
}

enum CameraError: Error {
    case notAuthorized
    case configurationFailed
    case captureFailed
}

/// 相机采集服务
protocol CameraServicing: AnyObject {
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    func configure() async throws
    func startSession() async
    func stopSession() async
    func capturePhoto() async throws -> CapturedPhoto
    func startRecording() async throws
    func stopRecording() async throws -> URL
    func switchCamera() async
}

final class CameraService: NSObject, CameraServicing, @unchecked Sendable {
    let previewLayer: AVCaptureVideoPreviewLayer

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.yeex.watermarkcamera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back

    private var photoContinuation: CheckedContinuation<CapturedPhoto, Error>?
    private var recordingContinuation: CheckedContinuation<URL, Error>?

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }

    // MARK: - 配置

    func configure() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { throw CameraError.notAuthorized }
        default:
            throw CameraError.notAuthorized
        }
        // 请求麦克风（录像用），失败不阻断照片功能
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.configureSession()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = camera(for: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }
        session.addInput(input)
        videoInput = input

        if let mic = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        session.commitConfiguration()
    }

    private func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    // MARK: - 会话生命周期

    func startSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                if let self, !self.session.isRunning { self.session.startRunning() }
                continuation.resume()
            }
        }
    }

    func stopSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                if let self, self.session.isRunning { self.session.stopRunning() }
                continuation.resume()
            }
        }
    }

    func switchCamera() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self, let current = self.videoInput else { continuation.resume(); return }
                self.session.beginConfiguration()
                self.session.removeInput(current)
                self.currentPosition = self.currentPosition == .back ? .front : .back
                if let device = self.camera(for: self.currentPosition),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                } else {
                    self.session.addInput(current)
                }
                self.session.commitConfiguration()
                continuation.resume()
            }
        }
    }

    // MARK: - 拍照

    func capturePhoto() async throws -> CapturedPhoto {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.photoContinuation = continuation
                let settings = AVCapturePhotoSettings()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - 录像

    func startRecording() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        sessionQueue.async { [weak self] in
            self?.movieOutput.startRecording(to: url, recordingDelegate: self!)
        }
    }

    func stopRecording() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.recordingContinuation = continuation
                self.movieOutput.stopRecording()
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        defer { photoContinuation = nil }
        if let error {
            photoContinuation?.resume(throwing: error)
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: CameraError.captureFailed)
            return
        }
        photoContinuation?.resume(returning: CapturedPhoto(image: image, orientation: image.imageOrientation))
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        defer { recordingContinuation = nil }
        if let error {
            recordingContinuation?.resume(throwing: error)
        } else {
            recordingContinuation?.resume(returning: outputFileURL)
        }
    }
}
