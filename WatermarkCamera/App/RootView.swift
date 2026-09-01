import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            CameraView()
                .tabItem { Label("Capture", systemImage: "camera.fill") }

            LibraryView()
                .tabItem { Label("Album Watermark", systemImage: "photo.on.rectangle") }

            TemplatesView()
                .tabItem { Label("Templates", systemImage: "square.stack.3d.up") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// 应用内共享的“当前选中模板”偏好（存 UUID 字符串）
extension String {
    static let selectedTemplateKey = "selectedTemplateID"
}

/// 便捷：在一组模板中找到当前选中的，找不到则回退第一个
func resolveSelectedTemplate(from templates: [WatermarkTemplate]) -> WatermarkTemplate? {
    let idString = UserDefaults.standard.string(forKey: .selectedTemplateKey)
    if let idString, let id = UUID(uuidString: idString),
       let match = templates.first(where: { $0.id == id }) {
        return match
    }
    return templates.first
}
