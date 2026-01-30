import SwiftUI
import SpectasiaCore

/// Table-based list view for images with metadata columns.
struct ImageListView: View {
    let images: [SpectasiaImage]
    @Binding var selectedImage: SpectasiaImage?

    @State private var sortDescriptor: SortDescriptor = .init(column: .name, ascending: true)

    private var sortedImages: [SpectasiaImage] {
        images.sorted { lhs, rhs in
            let compare: ComparisonResult
            switch sortDescriptor.column {
            case .name:
                compare = lhs.url.lastPathComponent.localizedCaseInsensitiveCompare(rhs.url.lastPathComponent)
            case .size:
                compare = lhs.metadata.fileSize == rhs.metadata.fileSize ? .orderedSame : (lhs.metadata.fileSize < rhs.metadata.fileSize ? .orderedAscending : .orderedDescending)
            case .modified:
                compare = lhs.metadata.modificationDate.compare(rhs.metadata.modificationDate)
            case .rating:
                compare = lhs.rating == rhs.rating ? .orderedSame : (lhs.rating < rhs.rating ? .orderedAscending : .orderedDescending)
            case .format:
                compare = lhs.metadata.fileExtension.localizedCaseInsensitiveCompare(rhs.metadata.fileExtension)
            }
            if compare == .orderedSame {
                return lhs.url.path < rhs.url.path
            }
            return sortDescriptor.ascending ? (compare == .orderedAscending) : (compare == .orderedDescending)
        }
    }

    private var selection: Binding<Set<String>> {
        Binding(
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
        VStack(spacing: 8) {
            SortHeader(descriptor: $sortDescriptor)
            Table(sortedImages, selection: selection) {
                TableColumn("Name") { image in
                    Text(image.url.lastPathComponent)
                        .lineLimit(1)
                }
                TableColumn("Format") { image in
                    Text(image.metadata.fileExtension.uppercased())
                        .foregroundColor(.secondary)
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
                TableColumn("Tags") { image in
                    Text(image.tags.isEmpty ? "—" : image.tags.joined(separator: ", "))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SortHeader: View {
    @Binding var descriptor: SortDescriptor

    var body: some View {
        HStack {
            SortButton(label: "Name", column: .name, descriptor: $descriptor)
            SortButton(label: "Size", column: .size, descriptor: $descriptor)
            SortButton(label: "Date", column: .modified, descriptor: $descriptor)
            SortButton(label: "Rating", column: .rating, descriptor: $descriptor)
            Spacer()
        }
        .font(GypsumFont.caption)
        .padding(.horizontal)
    }
}

private struct SortButton: View {
    let label: String
    let column: SortDescriptor.Column
    @Binding var descriptor: SortDescriptor

    var body: some View {
        Button(action: {
            if descriptor.column == column {
                descriptor.ascending.toggle()
            } else {
                descriptor.column = column
                descriptor.ascending = true
            }
        }) {
            HStack(spacing: 4) {
                Text(label)
                Image(systemName: descriptor.column == column ? (descriptor.ascending ? "chevron.up" : "chevron.down") : "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

private struct SortDescriptor {
    enum Column {
        case name, size, modified, rating, format
    }

    var column: Column
    var ascending: Bool
}
