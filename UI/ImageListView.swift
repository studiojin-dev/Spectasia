import SwiftUI
import SpectasiaCore

/// Table-based list view for images with metadata columns.
struct ImageListView: View {
    let images: [SpectasiaImage]
    @Binding var selectedImage: SpectasiaImage?

    private var selection: Binding<Set<String>> {
        Binding<Set<String>>(
            get: {
                if let selectedImage {
                    return [selectedImage.id]
                }
                return []
            },
            set: { newValue in
                if let id = newValue.first, let match = images.first(where: { $0.id == id }) {
                    selectedImage = match
                } else {
                    selectedImage = nil
                }
            }
        )
    }

    var body: some View {
        Table(images, selection: selection) {
            TableColumn("Name") { image in
                Text(image.url.lastPathComponent)
                    .lineLimit(1)
            }
            TableColumn("Size") { image in
                Text(ByteCountFormatter.string(fromByteCount: image.metadata.fileSize, countStyle: .file))
                    .foregroundColor(.secondary)
            }
            TableColumn("Modified") { image in
                Text(image.metadata.modificationDate, style: .date)
                    .foregroundColor(.secondary)
            }
            TableColumn("Rating") { image in
                Text(image.rating == 0 ? "—" : String(repeating: "★", count: image.rating))
                    .foregroundColor(image.rating == 0 ? .secondary : .yellow)
            }
            TableColumn("Format") { image in
                Text(image.metadata.fileExtension.uppercased())
                    .foregroundColor(.secondary)
            }
            TableColumn("Tags") { image in
                Text(image.tags.isEmpty ? "—" : image.tags.joined(separator: ", "))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
