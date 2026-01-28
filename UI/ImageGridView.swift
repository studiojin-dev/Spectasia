import SwiftUI

/// Grid view for browsing images with thumbnails
public struct ImageGridView: View {
    let images: [SpectasiaImage]
    let selectedImage: Binding<SpectasiaImage?>
    let backgroundTasks: Binding<Int>
    let gridSize: CGFloat = 120

    public init(
        images: [SpectasiaImage],
        selectedImage: Binding<SpectasiaImage?>,
        backgroundTasks: Binding<Int>
    ) {
        self.images = images
        self.selectedImage = selectedImage
        self.backgroundTasks = backgroundTasks
    }

    public var body: some View {
        ScrollView {
            if images.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(GypsumColor.textSecondary)
                    Text("No images found")
                        .font(GypsumFont.body)
                        .foregroundColor(GypsumColor.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: gridSize, maximum: gridSize), spacing: 2)
                ], spacing: 2) {
                    ForEach(images, id: \.url) { spectasiaImage in
                        ImageThumbnail(
                            spectasiaImage: spectasiaImage,
                            size: CGSize(width: gridSize, height: gridSize)
                        )
                    }
                }
                .padding()
            }
        }
        .background(GypsumColor.background)
    }
}

/// Thumbnail view for a single image
struct ImageThumbnail: View {
    let spectasiaImage: SpectasiaImage
    let size: CGSize
    @State private var thumbnail: Image?
    @State private var isSelected = false
    @State private var isLoading = true

    private let thumbnailService = ThumbnailService()

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .border(isSelected ? GypsumColor.accent : Color.clear, width: 3)
            } else if isLoading {
                Rectangle()
                    .fill(GypsumColor.surface)
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            } else {
                Rectangle()
                    .fill(GypsumColor.surface)
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(GypsumColor.textSecondary)
                    )
            }
        }
        .cornerRadius(4)
        .onTapGesture {
            isSelected.toggle()
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        // Check if we already have a cached thumbnail
        if let cachedThumbnailURL = spectasiaImage.thumbnails[.small] {
            // Load from cache
            if let nsImage = NSImage(contentsOf: cachedThumbnailURL) {
                self.thumbnail = Image(nsImage: nsImage)
                self.isLoading = false
                return
            }
        }

        // Generate thumbnail using ThumbnailService
        isLoading = true
        Task {
            do {
                let thumbnailURL = try thumbnailService.generateThumbnail(
                    for: spectasiaImage.url,
                    size: .small
                )

                // Load the generated thumbnail
                if let nsImage = NSImage(contentsOf: thumbnailURL) {
                    await MainActor.run {
                        self.thumbnail = Image(nsImage: nsImage)
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview("Image Grid") {
    ImageGridView(
        images: [],
        selectedImage: .constant(nil),
        backgroundTasks: .constant(0)
    )
}
