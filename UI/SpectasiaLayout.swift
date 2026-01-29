import SwiftUI

/// Three-panel layout for Spectasia: Sidebar, Content, Detail
public struct SpectasiaLayout: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Binding private var images: [SpectasiaImage]
    @Binding private var selectedImage: SpectasiaImage?
    @Binding private var selectedDirectory: URL?
    @Binding private var currentViewMode: ViewMode
    @Binding private var isLoading: Bool
    @Binding private var backgroundTasks: Int

    /// View mode for displaying images
    public enum ViewMode {
        case thumbnailGrid
        case list
        case singleImage
    }

    public init(
        images: Binding<[SpectasiaImage]>,
        selectedImage: Binding<SpectasiaImage?>,
        selectedDirectory: Binding<URL?>,
        currentViewMode: Binding<ViewMode>,
        isLoading: Binding<Bool>,
        backgroundTasks: Binding<Int>
    ) {
        self._images = images
        self._selectedImage = selectedImage
        self._selectedDirectory = selectedDirectory
        self._currentViewMode = currentViewMode
        self._isLoading = isLoading
        self._backgroundTasks = backgroundTasks
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility,
                              sidebar: {
                VStack {
                    Text("Folders")
                        .padding()
                    Text("Images List")
                        .padding()
                    Spacer()
                }
                .frame(minWidth: 200)
            },
                              content: {
                VStack {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.1))
                    } else {
                        switch currentViewMode {
                        case .thumbnailGrid:
                            ImageGridView(
                                images: images,
                                selectedImage: $selectedImage,
                                backgroundTasks: $backgroundTasks
                            )
                        case .list:
                            ForEach(images) { image in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(image.id)")
                                            .font(.body)
                                        HStack(spacing: 12) {
                                            Text("\(image.metadata.fileSize) bytes")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(image.metadata.modificationDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .onTapGesture {
                                    $selectedImage.wrappedValue = image
                                }
                            }
                        case .singleImage:
                            if let image = selectedImage {
                                SingleImageView(imageURL: image.url)
                            }
                        }
                    }
                }
                .frame(minWidth: 800, minHeight: 600)
            },
                              detail: {
                Text("Detail Panel")
                    .frame(minWidth: 200)
            }
        )
        .navigationTitle("Library")
    }

    #Preview("Spectasia Layout") {
        SpectasiaLayout(
            images: .constant([]),
            selectedImage: .constant(nil),
            selectedDirectory: .constant(nil),
            currentViewMode: .constant(.thumbnailGrid),
            isLoading: .constant(false),
            backgroundTasks: .constant(0)
        )
    }
}

