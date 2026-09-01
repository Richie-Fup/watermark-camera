import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatermarkTemplate.createdAt) private var templates: [WatermarkTemplate]
    @AppStorage(.selectedTemplateKey) private var selectedID: String = ""

    @State private var editingTemplate: WatermarkTemplate?

    /// 预览用的示例数据
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
        NavigationStack {
            List {
                ForEach(templates) { template in
                    row(template)
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Watermark Templates")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addTemplate()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $editingTemplate) { template in
                TemplateEditorView(template: template)
            }
        }
    }

    private func row(_ template: WatermarkTemplate) -> some View {
        HStack(spacing: 12) {
            // 缩略预览
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray4))
                WatermarkOverlayView(data: sampleData, template: template.snapshot(), scale: 0.06)
            }
            .frame(width: 96, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(template.localizedName).font(.headline)
                Text(fieldSummary(template)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if template.id.uuidString == selectedID {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedID = template.id.uuidString }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteTemplate(template)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editingTemplate = template
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func fieldSummary(_ template: WatermarkTemplate) -> String {
        var parts: [String] = []
        let f = template.enabledFields
        if f.contains(.time) { parts.append(String(localized: "Time")) }
        if f.contains(.weekday) { parts.append(String(localized: "Weekday")) }
        if f.contains(.place) { parts.append(String(localized: "Place")) }
        if f.contains(.weather) { parts.append(String(localized: "Weather")) }
        if f.contains(.temperature) { parts.append(String(localized: "Temperature")) }
        return parts.joined(separator: " · ")
    }

    private func addTemplate() {
        let new = WatermarkTemplate(name: String(localized: "New Template"), isBuiltIn: false)
        context.insert(new)
        try? context.save()
        editingTemplate = new
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            deleteTemplate(templates[index])
        }
    }

    private func deleteTemplate(_ template: WatermarkTemplate) {
        if template.id.uuidString == selectedID { selectedID = "" }
        context.delete(template)
        try? context.save()
    }
}
