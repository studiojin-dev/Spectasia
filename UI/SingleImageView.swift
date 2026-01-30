import SwiftUI
import SpectasiaCore
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

public struct SingleImageView: View {
    public let image: SpectasiaImage
    public let gallery: [SpectasiaImage]
    public let onSelectImage: (SpectasiaImage) -> Void

    @State private var loadedImage: PlatformImage? = nil
    @State private var loadError: String? = nil
    @State private var zoomScale: CGFloat = 1.0
    @State private var translation: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    @State private var overlayPosition: OverlayPosition = .bottom
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager

    public init(
        image: SpectasiaImage,
        gallery: [SpectasiaImage] = [],
        onSelectImage: @escaping (SpectasiaImage) -> Void = { _ in }
    ) {
        self.image = image
        self.gallery = gallery
        self.onSelectImage = onSelectImage
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
            if !gallery.isEmpty {
                filmstrip
            }
        }
        .navigationTitle(image.url.lastPathComponent)
        .toolbar {
#if os(macOS)
            ToolbarItemGroup(placement: .automatic) {
                Button(action: previousImage) {
                    Label("Previous", systemImage: "arrow.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(previous == nil)
                Button(action: nextImage) {
                    Label("Next", systemImage: "arrow.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(next == nil)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    overlayPosition = overlayPosition.next()
                } label: {
                    Label("Overlay", systemImage: "info.circle")
                }
            }
#else
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button(action: previousImage) {
                    Label("Previous", systemImage: "arrow.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(previous == nil)
                Button(action: nextImage) {
                    Label("Next", systemImage: "arrow.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(next == nil)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    overlayPosition = overlayPosition.next()
                } label: {
                    Label("Overlay", systemImage: "info.circle")
                }
            }
#endif
        }
    }

    private var content: some View {
        Group {
            if loadError != nil {
                errorView
            } else if let loadedImage {
                imageView(loadedImage)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadImage()
                    }
            }
        }
        .overlay(overlay, alignment: overlayPosition.alignment)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(loadError ?? "Failed to load image.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
    }

    private func imageView(_ platformImage: PlatformImage) -> some View {
        GeometryReader { geometry in
            imageViewContent(for: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomScale * magnifyBy)
                .offset(x: translation.width + dragOffset.width, y: translation.height + dragOffset.height)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.black.opacity(0.02))
        .gesture(
            simultaneousGestures
        )
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded {
                    resetZoom()
                }
        )
    }
}

    private func imageViewContent(for platformImage: PlatformImage) -> Image {
        #if canImport(AppKit)
        return Image(nsImage: platformImage)
        #else
        return Image(uiImage: platformImage)
        #endif
    }

    private var simultaneousGestures: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    translation.width += value.translation.width
                    translation.height += value.translation.height
                },
            MagnificationGesture()
                .updating($magnifyBy) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    zoomScale = max(0.5, min(zoomScale * value, 4))
                }
        )
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EXIF / Metadata")
                .font(GypsumFont.caption)
                .bold()
            Text("Size: \(ByteCountFormatter.string(fromByteCount: image.metadata.fileSize, countStyle: .file))")
                .font(GypsumFont.caption2)
            Text("Modified: \(image.metadata.modificationDate.formatted(date: .abbreviated, time: .shortened))")
                .font(GypsumFont.caption2)
            Text("Format: \(image.metadata.fileExtension.uppercased())")
                .font(GypsumFont.caption2)
            Text("Zoom: \(Int(zoomScale * 100))%")
                .font(GypsumFont.caption2)
        }
        .padding(8)
        .background(GypsumColor.surface.opacity(0.9))
        .cornerRadius(8)
        .padding(overlayPosition.padding)
    }

    private var filmstrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(gallery.prefix(8)) { candidate in
                    FilmstripThumb(
                        image: candidate,
                        isSelected: candidate.id == image.id
                    ) {
                        onSelectImage(candidate)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(GypsumColor.surface.opacity(0.9))
        }
        .frame(height: 90)
    }


    private var previous: SpectasiaImage? {
        guard let index = gallery.firstIndex(where: { $0.id == image.id }), index > 0 else { return nil }
        return gallery[index - 1]
    }

    private var next: SpectasiaImage? {
        guard let index = gallery.firstIndex(where: { $0.id == image.id }), index < gallery.count - 1 else { return nil }
        return gallery[index + 1]
    }

    private func previousImage() {
        if let prev = previous {
            onSelectImage(prev)
        }
    }

    private func nextImage() {
        if let next = next {
            onSelectImage(next)
        }
    }

    @MainActor
    private func loadImage() async {
        do {
            let data = try await Task.detached {
                try Data(contentsOf: image.url)
            }.value
            if let platformImage = PlatformImage(data: data) {
                loadedImage = platformImage
            } else {
                loadError = "Unable to decode image at \(image.url.path)"
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func resetZoom() {
        zoomScale = 1.0
        translation = .zero
    }
}

#if canImport(AppKit)
private struct FilmstripThumb: View {
    let image: SpectasiaImage
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager
    @State private var thumbnail: Image?
    @State private var isLoading = true
    @State private var loadTask: Task<Void, Never>?

    private let thumbSize: CGFloat = 70

    private var thumbnailService: ThumbnailService {
        ThumbnailService(metadataStore: metadataStoreManager.store)
    }

    private var thumbnailSize: ThumbnailSize {
        .medium
    }

    var body: some View {
        ZStack {
            if let thumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbSize, height: thumbSize)
                    .clipped()
            } else if isLoading {
                Rectangle()
                    .fill(GypsumColor.surface)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(ProgressView().scaleEffect(0.6))
            } else {
                Rectangle()
                    .fill(GypsumColor.surface)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(GypsumColor.textSecondary)
                    )
            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .background(GypsumColor.surface)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? GypsumColor.accent : GypsumColor.border, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            action()
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
        if let cachedThumbnailURL = image.thumbnails[thumbnailSize],
           let cachedImage = NSImage(contentsOf: cachedThumbnailURL) {
            thumbnail = Image(nsImage: cachedImage)
            isLoading = false
            return
        }

        isLoading = true
        loadTask?.cancel()
        loadTask = Task {
            do {
                let thumbnailURL = try await thumbnailService.generateThumbnail(
                    for: image.url,
                    size: thumbnailSize
                )
                if let fetched = NSImage(contentsOf: thumbnailURL) {
                    await MainActor.run {
                        thumbnail = Image(nsImage: fetched)
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
#else
private struct FilmstripThumb: View {
    let image: SpectasiaImage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(image.url.lastPathComponent)
                .font(GypsumFont.caption)
                .lineLimit(1)
                .foregroundColor(isSelected ? GypsumColor.accent : GypsumColor.text)
                .frame(width: 140, height: 70)
                .background(GypsumColor.surface.opacity(0.7))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? GypsumColor.accent : GypsumColor.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
#endif

#if canImport(AppKit)
private typealias PlatformImage = NSImage
#else
private typealias PlatformImage = UIImage
#endif

private enum OverlayPosition: CaseIterable {
    case top, bottom, topLeading, topTrailing, bottomLeading, bottomTrailing

    var alignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    var padding: EdgeInsets {
        let inset: CGFloat = 12
        switch self {
        case .top:
            return EdgeInsets(top: inset, leading: inset, bottom: 0, trailing: inset)
        case .bottom:
            return EdgeInsets(top: 0, leading: inset, bottom: inset, trailing: inset)
        case .topLeading:
            return EdgeInsets(top: inset, leading: inset, bottom: 0, trailing: 0)
        case .topTrailing:
            return EdgeInsets(top: inset, leading: 0, bottom: 0, trailing: inset)
        case .bottomLeading:
            return EdgeInsets(top: 0, leading: inset, bottom: inset, trailing: 0)
        case .bottomTrailing:
            return EdgeInsets(top: 0, leading: 0, bottom: inset, trailing: inset)
        }
    }

    func next() -> OverlayPosition {
        let all = OverlayPosition.allCases
        if let currentIndex = all.firstIndex(of: self), currentIndex < all.count - 1 {
            return all[currentIndex + 1]
        }
        return all.first ?? self
    }
}
