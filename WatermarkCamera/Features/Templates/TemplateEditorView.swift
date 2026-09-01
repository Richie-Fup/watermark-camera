import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Bindable var template: WatermarkTemplate
    @Environment(\.modelContext) private var context

    private var sampleData: WatermarkData {
        WatermarkData(
            timestamp: Date(),
            placeName: String(localized: "Shanghai · Pudong"),
            weather: WeatherSnapshot(condition: String(localized: "Cloudy"),
                                     symbolName: "cloud.fill",
                                     temperature: Measurement(value: 26, unit: .celsius))
        )
    }

    var body: some View {
        Form {
            Section("Preview") {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray3))
                    WatermarkOverlayView(data: sampleData, template: template.snapshot(), scale: 0.12)
                }
                .frame(height: 160)
                .listRowInsets(EdgeInsets())
            }

            Section("Name") {
                if template.isBuiltIn {
                    Text(template.localizedName)
                } else {
                    TextField("Template Name", text: $template.name)
                }
            }

            Section("Visible Fields") {
                fieldToggle(String(localized: "Time"), .time)
                fieldToggle(String(localized: "Weekday"), .weekday)
                fieldToggle(String(localized: "Place"), .place)
                fieldToggle(String(localized: "Weather"), .weather)
                fieldToggle(String(localized: "Temperature"), .temperature)
            }

            Section("Position") {
                Picker("Watermark Position", selection: positionBinding) {
                    ForEach(WatermarkPosition.allCases, id: \.self) { pos in
                        Text(pos.displayName).tag(pos)
                    }
                }
            }

            Section("Style") {
                ColorPicker("Text Color", selection: colorBinding, supportsOpacity: false)

                VStack(alignment: .leading) {
                    Text(String(format: String(localized: "Font size: %lld"), Int(template.fontSize)))
                    Slider(value: $template.fontSize, in: 20...80, step: 1)
                }

                VStack(alignment: .leading) {
                    Text(String(format: String(localized: "Opacity: %lld%%"), Int(template.opacity * 100)))
                    Slider(value: $template.opacity, in: 0.2...1.0)
                }

                Picker("Background Style", selection: backgroundBinding) {
                    ForEach(BackgroundStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            }

            Section("Date Format") {
                Picker("Format", selection: $template.dateFormat) {
                    Text("2026.07.21 14:30").tag("yyyy.MM.dd HH:mm")
                    Text("Jul 21, 2026 14:30").tag("MMM d, yyyy HH:mm")
                    Text("2026年7月21日 14:30").tag("yyyy年M月d日 HH:mm")
                    Text("07/21 14:30").tag("MM/dd HH:mm")
                    Text("14:30").tag("HH:mm")
                }
            }
        }
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }

    // MARK: - Bindings

    private func fieldToggle(_ label: String, _ field: WatermarkFieldSet) -> some View {
        Toggle(label, isOn: Binding(
            get: { template.enabledFields.contains(field) },
            set: { isOn in
                var fields = template.enabledFields
                if isOn { fields.insert(field) } else { fields.remove(field) }
                template.enabledFields = fields
            }
        ))
    }

    private var positionBinding: Binding<WatermarkPosition> {
        Binding(get: { template.position }, set: { template.position = $0 })
    }

    private var backgroundBinding: Binding<BackgroundStyle> {
        Binding(get: { template.backgroundStyle }, set: { template.backgroundStyle = $0 })
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: template.textColorHex) },
            set: { template.textColorHex = UIColor($0).hexString }
        )
    }
}
