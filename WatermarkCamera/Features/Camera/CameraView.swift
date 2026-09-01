import SwiftUI
import SwiftData

struct CameraView: View {
    @Environment(AppDependencies.self) private var deps
    @Query(sort: \WatermarkTemplate.createdAt) private var templates: [WatermarkTemplate]
    @State private var model: CameraViewModel?
    @State private var captureMode: CaptureMode = .photo
    /// 侦听 UserDefaults 中模板选中变更，驱动 body 重新求值
    @AppStorage(.selectedTemplateKey) private var selectedID: String = ""

    /// 使用 @AppStorage 的 selectedID 查找，确保 SwiftUI 追踪依赖
    private var selectedTemplate: WatermarkTemplate? {
        if let id = UUID(uuidString: selectedID),
           let match = templates.first(where: { $0.id == id }) {
            return match
        }
        return templates.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let model {
                content(model: model)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            if model == nil { model = CameraViewModel(deps: deps) }
            await model?.onAppear()
        }
        .onDisappear {
            Task { await model?.onDisappear() }
        }
    }

    @ViewBuilder
    private func content(model: CameraViewModel) -> some View {
        GeometryReader { geo in
            ZStack {
                CameraPreviewView(previewLayer: model.previewLayer)
                    .ignoresSafeArea()

                if model.status == .denied {
                    permissionDenied
                } else if let template = selectedTemplate {
                    // 仅让水印子视图按秒刷新，相机预览与控件不参与重建，避免卡顿
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        WatermarkOverlayView(
                            data: model.liveData.with(timestamp: context.date),
                            template: template.snapshot(),
                            scale: geo.size.width / 1080 * 1.4
                        )
                    }
                    .id(template.id)  // 模板切换后强制重建 TimelineView
                    .padding(.top, 72)
                    .padding(.bottom, 168)
                    .allowsHitTesting(false)
                }

                controls(model: model)
            }
        }
        .overlay(alignment: .top) { recordingIndicator(model: model) }
        .overlay(alignment: .top) { toast(model: model) }
    }

    /// 录制中顶部提示：闪烁红点 + 走动的计时器
    @ViewBuilder
    private func recordingIndicator(model: CameraViewModel) -> some View {
        if model.isRecording, let start = model.recordingStartDate {
            TimelineView(.periodic(from: start, by: 1)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(start))
                HStack(spacing: 8) {
                    Circle().fill(.red)
                        .frame(width: 10, height: 10)
                        .opacity(Int(elapsed) % 2 == 0 ? 1 : 0.25)
                    Text(Self.recordingTimeString(elapsed))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.top, 12)
            }
        }
    }

    /// 将秒数格式化为 mm:ss（超过一小时显示 h:mm:ss）
    private static func recordingTimeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    @ViewBuilder
    private func controls(model: CameraViewModel) -> some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    Task { await model.switchCamera() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2).foregroundStyle(.white)
                        .padding(12).background(.black.opacity(0.4), in: Circle())
                }
                .padding()
                .disabled(model.isRecording)
            }
            Spacer()

            if model.status == .processing {
                ProgressView("Processing…").tint(.white).foregroundStyle(.white)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 18) {
                Button {
                    guard let t = selectedTemplate?.snapshot() else { return }
                    Task {
                        switch captureMode {
                        case .photo:
                            await model.capturePhoto(template: t)
                        case .video:
                            await model.toggleRecording(template: t)
                        }
                    }
                } label: {
                    if captureMode == .photo {
                        ShutterButtonLabel()
                    } else {
                        RecordButtonLabel(isRecording: model.isRecording)
                    }
                }
                .disabled(shutterDisabled(model: model))
                .opacity(shutterOpacity(model: model))

                CaptureModePicker(selection: $captureMode, isRecording: model.isRecording)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
    }

    private func shutterDisabled(model: CameraViewModel) -> Bool {
        if model.status == .processing { return true }
        if captureMode == .photo { return model.isRecording }
        return false
    }

    private func shutterOpacity(model: CameraViewModel) -> Double {
        if captureMode == .photo, model.isRecording { return 0.35 }
        return 1
    }

    private var permissionDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown").font(.largeTitle)
            Text("Camera Access Required").font(.headline)
            Text("Please enable camera access in Settings, then return.")
                .font(.subheadline).multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding()
    }

    @ViewBuilder
    private func toast(model: CameraViewModel) -> some View {
        if let toast = model.toast {
            Text(toast)
                .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    model.toast = nil
                }
        }
    }
}

// MARK: - 拍摄模式

private enum CaptureMode: String, CaseIterable {
    case video, photo
}

/// 照片 / 视频切换（系统相机风格：深色胶囊 + 选中项浅色滑块）
private struct CaptureModePicker: View {
    @Binding var selection: CaptureMode
    let isRecording: Bool
    @Namespace private var pillNamespace

    private let modes: [CaptureMode] = [.video, .photo]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.self) { mode in
                modeButton(mode)
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(Color.black.opacity(0.45))
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        }
        .disabled(isRecording)
        .opacity(isRecording ? 0.45 : 1)
    }

    private func modeButton(_ mode: CaptureMode) -> some View {
        let isSelected = selection == mode
        let title = mode == .video
            ? String(localized: "Video")
            : String(localized: "Photo")

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selection = mode
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 26)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.24))
                            .matchedGeometryEffect(id: "captureModePill", in: pillNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 系统风格快门 / 录制按钮

/// 拍照快门：白色外环 + 白色内圆（与系统相机一致）
private struct ShutterButtonLabel: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(.white, lineWidth: 4)
                .frame(width: 74, height: 74)
            Circle().fill(.white)
                .frame(width: 60, height: 60)
        }
    }
}

/// 录制按钮：白色外环 + 红点，录制时变为红色圆角方块（与系统相机一致）
private struct RecordButtonLabel: View {
    let isRecording: Bool
    var body: some View {
        ZStack {
            Circle().strokeBorder(.white, lineWidth: 4)
                .frame(width: 74, height: 74)
            RoundedRectangle(cornerRadius: isRecording ? 6 : 27)
                .fill(.red)
                .frame(width: isRecording ? 32 : 54,
                       height: isRecording ? 32 : 54)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
    }
}
