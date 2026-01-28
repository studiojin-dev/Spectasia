import SwiftUI

/// Right panel showing metadata, tags, and ratings
public struct MetadataPanel: View {
    let image: SpectasiaImage?
    @State private var selectedRating: Int = 0
    private let xmpService = XMPService()

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

                // Tag chips
                if let tags = image?.tags, !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(GypsumFont.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GypsumColor.accent.opacity(0.1))
                                .foregroundColor(GypsumColor.accent)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    Text("No tags")
                        .font(GypsumFont.caption)
                        .foregroundColor(GypsumColor.textSecondary)
                }
            }
            .padding()
            .background(GypsumColor.surface)
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .background(GypsumColor.background)
    }

    // MARK: - Private Methods

    private func saveRating(_ rating: Int) {
        guard let image = image else { return }

        Task {
            do {
                try xmpService.writeRating(url: image.url, rating: rating)
            } catch {
                print("Failed to save rating: \(error.localizedDescription)")
            }
        }
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

#Preview("Metadata Panel") {
    MetadataPanel()
        .frame(width: 250)
}
