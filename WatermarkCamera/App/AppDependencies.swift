import Foundation

/// 依赖注入容器：集中构造并持有所有服务，注入到视图/视图模型。
/// 通过 SwiftUI Environment 向下传递。
@Observable
@MainActor
final class AppDependencies {
    let cameraService: CameraServicing
    let locationService: LocationServicing
    let weatherProvider: WeatherProviding
    let metadataService: MetadataServicing
    let exportService: ExportServicing
    let renderer: WatermarkRendering
    let processing: WatermarkProcessingService

    init() {
        let camera = CameraService()
        let location = LocationService()
        let weather = WeatherKitProvider()
        let metadata = MetadataService()
        let export = ExportService()
        let renderer = WatermarkRenderer()

        let imageProcessor = ImageProcessor(renderer: renderer)
        let videoProcessor = VideoProcessor(renderer: renderer)
        let resolver = WatermarkDataResolver(location: location, weather: weather, metadata: metadata)

        self.cameraService = camera
        self.locationService = location
        self.weatherProvider = weather
        self.metadataService = metadata
        self.exportService = export
        self.renderer = renderer
        self.processing = WatermarkProcessingService(
            resolver: resolver,
            imageProcessor: imageProcessor,
            videoProcessor: videoProcessor,
            export: export
        )
    }
}
