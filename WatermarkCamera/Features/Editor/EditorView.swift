import SwiftUI
import SwiftData

struct EditorView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WatermarkTemplate.createdAt) private var templates: [WatermarkTemplate]

    let item: MediaItem
    @State private var model: EditorViewModel?
    @State private var selectedTemplateID: UUID?
    @State private var showLocationPicker = false

    private var selectedTemplate: WatermarkTemplate? {
        if let id = selectedTemplateID, let match = templates.first(where: { $0.id == id }) {
            return match
        }
        return resolveSelectedTemplate(from: templates)
    }

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Add Watermark")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = EditorViewModel(item: item, deps: deps) }
            await model?.load()
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(locationService: deps.locationService) { coordinate in
                Task { await model?.applyManualLocation(coordinate) }
            }
        }
    }

    @ViewBuilder
    private func content(model: EditorViewModel) -> some View {
        VStack(spacing: 0) {
            preview(model: model)
            Divider()
            controls(model: model)
        }
        .overlay(alignment: .top) { toastView(model: model) }
    }

    @ViewBuilder
    private func preview(model: EditorViewModel) -> some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image = model.previewImage {
                    let fitted = fittedSize(imageSize: image.size, in: geo.size)
                    // 媒体与水印置于与图片等大的矩形内，保证预览水印位置与最终合成一致
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: fitted.width, height: fitted.height)

                        if let template = selectedTemplate {
                            WatermarkOverlayView(
                                data: model.data,
                                template: template.snapshot(),
                                scale: fitted.width / 1080 * 1.2
                            )
                        }

                        if model.isVideo {
                            // 视频角标
                            Image(systemName: "video.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.black.opacity(0.5), in: Capsule())
                                .padding(10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(width: fitted.width, height: fitted.height)
                } else if model.isVideo {
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill").font(.largeTitle)
                        Text("Watermark will be applied when you save").font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }

                if model.isLoading {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    /// 按图片宽高比在容器内计算等比铺放尺寸
    private func fittedSize(imageSize: CGSize, in container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return container }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    @ViewBuilder
    private func controls(model: EditorViewModel) -> some View {
        VStack(spacing: 16) {
            if model.needsManualLocation {
                Button {
                    showLocationPicker = true
                } label: {
                    Label("No location — tap to pick on map", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }

            // 模板选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(templates) { template in
                        Button {
                            selectedTemplateID = template.id
                        } label: {
                            Text(template.localizedName)
                                .font(.caption).lineLimit(1)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(template.id == selectedTemplate?.id
                                            ? Color.accentColor : Color(.secondarySystemBackground),
                                            in: Capsule())
                                .foregroundStyle(template.id == selectedTemplate?.id ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button {
                guard let t = selectedTemplate?.snapshot() else { return }
                Task {
                    await model.save(template: t)
                }
            } label: {
                if model.isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Save to Photos").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isSaving || model.isLoading)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    @ViewBuilder
    private func toastView(model: EditorViewModel) -> some View {
        if let toast = model.toast {
            Text(toast)
                .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .task {
                    try? await Task.sleep(for: .seconds(1.5))
                    let shouldDismiss = model.didSaveSuccessfully
                    model.toast = nil
                    model.didSaveSuccessfully = false
                    if shouldDismiss { dismiss() }
                }
        }
    }
}
