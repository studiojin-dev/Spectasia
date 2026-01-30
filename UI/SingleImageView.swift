import SwiftUI
import SpectasiaCore
#if canImport(AppKit)
import AppKit
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

    public init(image: SpectasiaImage, gallery: [SpectasiaImage] = [], onSelectImage: @escaping (SpectasiaImage) -> Void = { _ in }) {
        self.image = image
        self.gallery = gallery
        self.onSelectImage = onSelectImage
    }

    public var body: some View {
        VStack(spacing: 0) {
            Group {
                if let loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(loadError)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                } else if let loadedImage {
                    GeometryReader { geometry in
                        #if canImport(AppKit)
                        Image(nsImage: loadedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        #else
                        Image(uiImage: loadedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        #endif
                            .scaleEffect(zoomScale * magnifyBy)
                            .offset(x: translation.width + dragOffset.width, y: translation.height + dragOffset.height)
                            .gesture(
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
                            )
                            .onTapGesture(count: 2) {
                                zoomScale = 1.0
                                translation = .zero
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .background(Color.black.opacity(0.02))
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            await load()
                        }
                }
            }
            .navigationTitle(image.url.lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .status) {
                    Text("Zoom: \(String(format: "%.2fx", zoomScale * magnifyBy))")
                        .font(GypsumFont.caption)
                        .foregroundColor(.secondary)
                }
            }
            if !gallery.isEmpty {
                filmstrip
            }
        }
        .padding()
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
            .padding(.vertical, 8)
            .background(GypsumColor.surface.opacity(0.9))
        }
        .frame(height: 90)
    }

    @MainActor
    private func load() async {
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
}

#if canImport(AppKit)
private typealias PlatformImage = NSImage
#else
import UIKit
private typealias PlatformImage = UIImage
#endif

private struct FilmstripThumb: View {
    let image: SpectasiaImage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? GypsumColor.accent : GypsumColor.border, lineWidth: isSelected ? 2 : 1)
                    .frame(width: 92, height: 52)
                    .overlay(
                        Text(image.url.lastPathComponent)
                            .font(GypsumFont.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                            .padding(4)
                    )
                Text(image.url.lastPathComponent)
                    .font(GypsumFont.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 92)
            }
        }
        .buttonStyle(.plain)
    }
}
