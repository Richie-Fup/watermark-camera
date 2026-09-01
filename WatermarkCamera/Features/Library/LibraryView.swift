import SwiftUI

struct LibraryView: View {
    @State private var showPicker = false
    @State private var items: [MediaItem] = []
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Album Watermark")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: MediaItem.self) { item in
                EditorView(item: item)
            }
        }
        .fullScreenCover(isPresented: $showPicker) {
            PhotoPicker { picked in
                items = picked
            }
            .ignoresSafeArea()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Import Photos or Videos", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Choose existing photos or videos from your library. We’ll read their time and location to add a watermark.")
        } actions: {
            Button("Select Media") { showPicker = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var list: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    HStack(spacing: 12) {
                        thumbnail(for: item)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.type == .video
                                 ? String(localized: "Video")
                                 : String(localized: "Photo"))
                                .font(.headline)
                            Text(item.sourceURL?.lastPathComponent ?? item.id)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for item: MediaItem) -> some View {
        Group {
            if item.type == .photo, let url = item.sourceURL,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: item.type == .video ? "video.fill" : "photo.fill")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
