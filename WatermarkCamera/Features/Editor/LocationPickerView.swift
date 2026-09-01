import SwiftUI
import MapKit
import CoreLocation

/// 地图选点：用于无 GPS 信息的历史媒体手动补全地点。
/// 进入后自动定位到设备当前位置；定位不可用时回退到默认区域，并由地图持续跟随用户定位。
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let locationService: LocationServicing
    var onPick: (CLLocationCoordinate2D) -> Void

    /// 定位不可用时的回退中心（北京）
    private let fallbackCenter = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)

    @State private var position: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    )
    @State private var centerCoordinate = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
    @State private var didCenterToDevice = false

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onMapCameraChange { context in
                    centerCoordinate = context.region.center
                }
                .ignoresSafeArea(edges: .bottom)

                // 中心固定指针
                Image(systemName: "mappin")
                    .font(.title)
                    .foregroundStyle(.red)
                    .offset(y: -12)
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onPick(centerCoordinate)
                        dismiss()
                    }
                }
            }
            .task {
                await centerToDeviceLocation()
            }
        }
    }

    /// 进入时定位到设备当前位置；拿不到定位则保持跟随模式（等 MapKit 拿到定位后自动居中）
    private func centerToDeviceLocation() async {
        guard !didCenterToDevice else { return }
        locationService.requestAuthorization()
        guard let coordinate = await locationService.currentCoordinate() else { return }
        didCenterToDevice = true
        centerCoordinate = coordinate
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
}
