import SwiftUI
import SwiftData

@main
struct WatermarkCameraApp: App {
    @State private var dependencies = AppDependencies()
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: WatermarkTemplate.self)
            TemplateSeeder.seedIfNeeded(context: modelContainer.mainContext)
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
        }
        .modelContainer(modelContainer)
    }
}
