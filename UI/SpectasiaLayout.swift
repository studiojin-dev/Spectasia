import SwiftUI
import SpectasiaCore

/// Three-panel layout for Spectasia: Sidebar, Content, Detail
public struct SpectasiaLayout: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings: Bool = false
    @Binding private var images: [SpectasiaImage]
    @Binding private var selectedImage: SpectasiaImage?
    @Binding private var selectedDirectory: URL?
    @Binding private var currentViewMode: ViewMode
    @Binding private var isLoading: Bool
    @Binding private var backgroundTasks: Int
    @Binding private var isMonitoring: Bool
    @Binding private var recentDirectories: [AppConfig.DirectoryBookmark]
    @Binding private var favoriteDirectories: [AppConfig.DirectoryBookmark]

    private let onSelectDirectory: (AppConfig.DirectoryBookmark) -> Void
    private let onToggleFavorite: (URL) -> Void

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
        backgroundTasks: Binding<Int>,
        isMonitoring: Binding<Bool>,
        recentDirectories: Binding<[AppConfig.DirectoryBookmark]>,
        favoriteDirectories: Binding<[AppConfig.DirectoryBookmark]>,
        onSelectDirectory: @escaping (AppConfig.DirectoryBookmark) -> Void,
        onToggleFavorite: @escaping (URL) -> Void
    ) {
        self._images = images
        self._selectedImage = selectedImage
        self._selectedDirectory = selectedDirectory
        self._currentViewMode = currentViewMode
        self._isLoading = isLoading
        self._backgroundTasks = backgroundTasks
        self._isMonitoring = isMonitoring
        self._recentDirectories = recentDirectories
        self._favoriteDirectories = favoriteDirectories
        self.onSelectDirectory = onSelectDirectory
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility,
                              sidebar: {
                ScrollView {
                    VStack {
                    Text("Folders")
                        .padding()
                    Button(action: {
                        showSettings = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    DirectoryPicker(prompt: "Select Folder", selectedURL: $selectedDirectory)
                        .padding(.bottom, 8)
                    Toggle("Monitoring", isOn: $isMonitoring)
                        .toggleStyle(.switch)
                        .padding(.horizontal)
                    if let directory = selectedDirectory {
                        HStack(spacing: 6) {
                            Text(directory.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Button(action: {
                                onToggleFavorite(directory)
                            }) {
                                Image(systemName: favoriteDirectories.contains(where: { $0.path == directory.path }) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("No folder selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    if !favoriteDirectories.isEmpty {
                        Text("Favorites")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        ForEach(favoriteDirectories, id: \.self) { bookmark in
                            Button(action: {
                                onSelectDirectory(bookmark)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text(bookmark.path)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                    if !recentDirectories.isEmpty {
                        Text("Recent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        ForEach(recentDirectories, id: \.self) { bookmark in
                            Button(action: {
                                onSelectDirectory(bookmark)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text(bookmark.path)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                    Text("Images: \(images.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                    }
                    .frame(minWidth: 200)
                }
            },
                              content: {
                VStack {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Loading…" : "Ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(isMonitoring ? "Monitoring On" : "Monitoring Off")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if backgroundTasks > 0 {
                            Text("Tasks: \(backgroundTasks)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

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
                            ImageListView(
                                images: images,
                                selectedImage: $selectedImage
                            )
                        case .singleImage:
                            if let image = selectedImage {
                                SingleImageView(imageURL: image.url)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("No image selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
                .frame(minWidth: 800, minHeight: 600)
            },
                              detail: {
                if let image = selectedImage {
                    MetadataPanel(image: image)
                        .frame(minWidth: 240)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "sidebar.right")
                            .foregroundColor(.secondary)
                        Text("No image selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 240)
                }
            }
        )
        .navigationTitle("Library")
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    #Preview("Spectasia Layout") {
        SpectasiaLayout(
            images: .constant([]),
            selectedImage: .constant(nil),
            selectedDirectory: .constant(nil),
            currentViewMode: .constant(.thumbnailGrid),
            isLoading: .constant(false),
            backgroundTasks: .constant(0),
            isMonitoring: .constant(true),
            recentDirectories: .constant([]),
            favoriteDirectories: .constant([]),
            onSelectDirectory: { _ in },
            onToggleFavorite: { _ in }
        )
    }
}
