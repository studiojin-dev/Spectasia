import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
import SpectasiaCore

/// Grid view for browsing images with thumbnails
public struct ImageGridView: View {
    let images: [SpectasiaImage]
    let selectedImage: Binding<SpectasiaImage?>
    let backgroundTasks: Binding<Int>
    let sizeOption: ThumbnailSizeOption
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager

    private var gridSize: CGFloat {
        switch sizeOption {
        case .small: return 88
        case .medium: return 132
        case .large: return 176
        }
    }

    private var thumbnailSize: ThumbnailSize {
        switch sizeOption {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }

    public init(
        images: [SpectasiaImage],
        selectedImage: Binding<SpectasiaImage?>,
        backgroundTasks: Binding<Int>,
        sizeOption: ThumbnailSizeOption
    ) {
        self.images = images
        self.selectedImage = selectedImage
        self.backgroundTasks = backgroundTasks
        self.sizeOption = sizeOption
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
                        selectedImage: selectedImage,
                        size: CGSize(width: gridSize, height: gridSize),
                        thumbnailSize: thumbnailSize
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
    @Binding var selectedImage: SpectasiaImage?
    let size: CGSize
    let thumbnailSize: ThumbnailSize
    @State private var thumbnail: Image?
    @State private var isLoading = true
    @State private var loadTask: Task<Void, Never>?
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager

    private var isSelected: Bool {
        selectedImage?.url == spectasiaImage.url
    }

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
            if isSelected {
                selectedImage = nil
            } else {
                selectedImage = spectasiaImage
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func loadThumbnail() {
        // Check if we already have a cached thumbnail
        if let cachedThumbnailURL = spectasiaImage.thumbnails[thumbnailSize] {
            // Load from cache
            if let nsImage = NSImage(contentsOf: cachedThumbnailURL) {
                self.thumbnail = Image(nsImage: nsImage)
                self.isLoading = false
                return
            }
        }

        // Generate thumbnail using ThumbnailService
        isLoading = true
        loadTask?.cancel()
        let metadataStore = metadataStoreManager.store
        let sourceURL = spectasiaImage.url
        let size = thumbnailSize
        loadTask = Task(priority: .userInitiated) {
            do {
                let thumbnailURL = try await Task.detached(priority: .utility) {
                    let service = ThumbnailService(metadataStore: metadataStore)
                    return try await service.generateThumbnail(for: sourceURL, size: size)
                }.value

                try Task.checkCancellation()

                if let nsImage = NSImage(contentsOf: thumbnailURL) {
                    await MainActor.run {
                        self.thumbnail = Image(nsImage: nsImage)
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
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
        backgroundTasks: .constant(0),
        sizeOption: .medium
    )
}
