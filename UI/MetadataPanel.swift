import SwiftUI
import SpectasiaCore

/// Right panel showing metadata, tags, and ratings
public struct MetadataPanel: View {
    let image: SpectasiaImage?
    @State private var selectedRating: Int = 0
    @State private var metadataRecord: MetadataStore.Record?
    @State private var editableTags: [String] = []
    @State private var newTagText: String = ""
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject private var repository: ObservableImageRepository
    @EnvironmentObject private var toastCenter: ToastCenter

    public init(image: SpectasiaImage? = nil) {
        self.image = image
        self._selectedRating = State(initialValue: image?.rating ?? 0)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rating section
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating")
                    .font(GypsumFont.headline)
                    .foregroundColor(GypsumColor.text)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .foregroundColor(star <= selectedRating ? .yellow : .gray.opacity(0.3))
                            .onTapGesture {
                                selectedRating = star
                                saveRating(star)
                            }
                    }
                }
            }
            .padding()
            .background(GypsumColor.surface)
            .cornerRadius(8)

            // Tags section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(GypsumFont.headline)
                    .foregroundColor(GypsumColor.text)

                if editableTags.isEmpty {
                    Text("No tags")
                        .font(GypsumFont.caption)
                        .foregroundColor(GypsumColor.textSecondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(editableTags, id: \.self) { tag in
                            TagChip(tag: tag) {
                                removeTag(tag)
                            }
                        }
                    }
                }

                HStack {
                    TextField("Add tag", text: $newTagText)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        addTag()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(GypsumColor.surface)
            .cornerRadius(8)

            // Metadata status
            VStack(alignment: .leading, spacing: 8) {
                Text("Metadata status")
                    .font(GypsumFont.headline)
                    .foregroundColor(GypsumColor.text)
                if let record = metadataRecord {
                    Text("Last updated \(record.updatedAt, style: .relative)")
                        .font(GypsumFont.caption)
                        .foregroundColor(.secondary)
                    if let xmpPath = record.xmpPath {
                        Text("XMP sidecar: \(URL(fileURLWithPath: xmpPath).lastPathComponent)")
                            .font(GypsumFont.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("XMP sidecar not yet created")
                            .font(GypsumFont.caption)
                            .foregroundColor(.secondary)
                    }
                    if record.thumbnails.isEmpty {
                        Text("Thumbnail pending")
                            .font(GypsumFont.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Thumbnails available for \(record.thumbnails.keys.sorted().joined(separator: ", "))")
                            .font(GypsumFont.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Waiting for metadata indexing")
                        .font(GypsumFont.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(GypsumColor.surface)
            .cornerRadius(8)

            // Maintenance section
            if let image = image {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maintenance")
                        .font(GypsumFont.headline)
                        .foregroundColor(GypsumColor.text)
                    Button("Regenerate Thumbnails") {
                        Task {
                            await repository.regenerateThumbnails(for: image.url)
                            toastCenter.show(NSLocalizedString("Thumbnails refreshed", comment: "Thumbnails refreshed"))
                        }
                    }
                }
                .padding()
                .background(GypsumColor.surface)
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
        .background(GypsumColor.background)
        .task(id: image?.url) {
            await refreshMetadataRecord()
            updateEditableTags()
        }
        .onChange(of: image?.rating ?? 0) { _, newValue in
            selectedRating = newValue
        }
        .onChange(of: image?.tags) { _, _ in
            updateEditableTags()
        }
    }

    // MARK: - Private Methods

    private func saveRating(_ rating: Int) {
        guard let image = image else { return }

        Task {
            do {
                let xmpService = XMPService(metadataStore: metadataStoreManager.store)
                try await xmpService.writeRating(url: image.url, rating: rating)
                await repository.refreshImages()
                await refreshMetadataRecord()
            } catch {
                CoreLog.error("Failed to save rating: \(error.localizedDescription)", category: "MetadataPanel")
            }
        }
    }

    private func addTag() {
        guard let _ = image else { return }
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !editableTags.contains(trimmed) else {
            toastCenter.show(NSLocalizedString("Tag already exists", comment: "Duplicate tag warning"))
            newTagText = ""
            return
        }
        editableTags.append(trimmed)
        newTagText = ""
        writeTags(editableTags)
    }

    private func removeTag(_ tag: String) {
        editableTags.removeAll(where: { $0 == tag })
        writeTags(editableTags)
    }

    private func updateEditableTags() {
        editableTags = image?.tags ?? []
    }

    private func writeTags(_ tags: [String]) {
        guard let image = image else { return }
        Task {
            do {
                let xmpService = XMPService(metadataStore: metadataStoreManager.store)
                try await xmpService.writeTags(url: image.url, tags: tags)
                toastCenter.show(NSLocalizedString("Tags updated", comment: "Tags updated notification"))
                await repository.refreshImages()
                await refreshMetadataRecord()
            } catch {
                CoreLog.error("Failed to write tags: \(error.localizedDescription)", category: "MetadataPanel")
            }
        }
    }

    private func refreshMetadataRecord() async {
        guard let image else {
            metadataRecord = nil
            return
        }
        metadataRecord = await metadataStoreManager.store.record(for: image.url)
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = proposal.replacingUnspecifiedDimensions()
        let bounds = CGRect(origin: .zero, size: size)
        let result = FlowLayout.computeFlowResult(in: bounds, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayout.computeFlowResult(in: bounds, subviews: subviews, spacing: spacing)
        for (index, origin) in result.placements {
            subviews[index].place(at: origin, proposal: .unspecified)
        }
    }

struct FlowResult {
        var size: CGSize
        var placements: [(index: Int, origin: CGPoint)]
    }

    static func computeFlowResult(in bounds: CGRect, subviews: Subviews, spacing: CGFloat) -> FlowResult {
        var placements: [(index: Int, origin: CGPoint)] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            placements.append((index, CGPoint(x: currentX, y: currentY)))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = currentY + lineHeight
        return FlowResult(size: CGSize(width: bounds.width, height: totalHeight), placements: placements)
    }
}

private struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(GypsumFont.caption)
                .foregroundColor(GypsumColor.accent)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(GypsumColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(GypsumColor.accent.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview("Metadata Panel") {
    MetadataPanel()
        .frame(width: 250)
        .environmentObject(MetadataStoreManager(rootDirectory: URL(fileURLWithPath: "/tmp")))
        .environmentObject(ObservableImageRepository(metadataStore: MetadataStore(rootDirectory: URL(fileURLWithPath: "/tmp"))))
        .environmentObject(ToastCenter())
}
