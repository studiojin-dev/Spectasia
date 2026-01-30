import SwiftUI
import SpectasiaCore

/// Three-panel layout for Spectasia: Sidebar, Content, Detail
public struct SpectasiaLayout: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject private var repository: ObservableImageRepository
    @EnvironmentObject private var directoryScanManager: DirectoryScanManager
    @EnvironmentObject private var permissionManager: PermissionManager
    private var accessibleDirectories: [String] {
        permissionManager.grantedDirectories.sorted()
    }
    @State private var showSettings: Bool = false
    @State private var directoryToAdd: URL? = nil
    @State private var thumbnailSizeOption: ThumbnailSizeOption = .medium
    @State private var lastViewModeMessage: String? = "Ready"
    @Binding private var images: [SpectasiaImage]
    @Binding private var selectedImage: SpectasiaImage?
    @Binding private var selectedDirectory: URL?
    @Binding private var currentViewMode: ViewMode
    @Binding private var isLoading: Bool
    @Binding private var backgroundTasks: Int

    private let onSelectDirectory: (AppConfig.DirectoryBookmark) -> Void

    /// View mode for displaying images
    public enum ViewMode: String, CaseIterable, Identifiable {
        case thumbnailGrid = "Thumbnail grid"
        case list = "List"
        case singleImage = "Single image"

        public var id: String { rawValue }
        public var title: String { rawValue }
    }

    public init(
        images: Binding<[SpectasiaImage]>,
        selectedImage: Binding<SpectasiaImage?>,
        selectedDirectory: Binding<URL?>,
        currentViewMode: Binding<ViewMode>,
        isLoading: Binding<Bool>,
        backgroundTasks: Binding<Int>,
        onSelectDirectory: @escaping (AppConfig.DirectoryBookmark) -> Void
    ) {
        self._images = images
        self._selectedImage = selectedImage
        self._selectedDirectory = selectedDirectory
        self._currentViewMode = currentViewMode
        self._isLoading = isLoading
        self._backgroundTasks = backgroundTasks
        self.onSelectDirectory = onSelectDirectory
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility,
                              sidebar: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GypsumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Settings")
                                            .font(GypsumFont.headline)
                                            .foregroundColor(GypsumColor.text)
                                        Text("Adjust metadata, AI, and cleanup behaviors.")
                                            .font(GypsumFont.caption)
                                            .foregroundColor(GypsumColor.textSecondary)
                                    }
                                    Spacer()
                                    Button(action: {
                                        showSettings = true
                                    }) {
                                        Label("Open", systemImage: "gearshape")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                Text(permissionManager.permissionStatus)
                                    .font(GypsumFont.caption)
                                    .foregroundColor(.secondary)
                                Button("Grant Full Disk Access") {
                                    permissionManager.openSecurityPreferencesForFullDiskAccess()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        Divider()

                        GypsumCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Watch folders")
                                    .font(GypsumFont.headline)
                                    .foregroundColor(GypsumColor.text)
                                Text("Add a directory once to keep its metadata, thumbnails, and AI tags in sync.")
                                    .font(GypsumFont.caption)
                                    .foregroundColor(GypsumColor.textSecondary)
                                HStack(spacing: 12) {
                                    DirectoryPicker(prompt: "Add Directory", selectedURL: $directoryToAdd)
                                    Button {
                                        directoryToAdd = nil
                                    } label: {
                                        Label("Add another folder", systemImage: "plus")
                                    }
                                    .buttonStyle(.bordered)
                                    Spacer()
                                }
                                .onChange(of: directoryToAdd) { _, newValue in
                                    guard let url = newValue else { return }
                                    Task {
                                        await directoryScanManager.addDirectory(url)
                                        let bookmark = await MainActor.run { directoryScanManager.bookmark(for: url.path) }
                                        if let bookmark {
                                            await MainActor.run {
                                                onSelectDirectory(bookmark)
                                            }
                                        }
                                    }
                                    directoryToAdd = nil
                                }
                            }
                        }
                        Divider()

                        GypsumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Directory tree")
                                        .font(GypsumFont.headline)
                                        .foregroundColor(GypsumColor.text)
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Button("Collapse") {
                                            directoryScanManager.collapseAllDirectories()
                                        }
                                        .buttonStyle(.bordered)
                                        Button("Expand") {
                                            directoryScanManager.expandAllDirectories()
                                        }
                                        .buttonStyle(.bordered)
                                        Button("Scan all") {
                                            directoryScanManager.reindexWatchedDirectories()
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                DirectoryTreeView(
                                    selectedPath: selectedDirectory?.path,
                                    onSelectDirectory: onSelectDirectory
                                )
                                .frame(maxHeight: 360)
                                if let message = directoryScanManager.scanCompletionMessage {
                                    Text(message)
                                        .font(GypsumFont.caption)
                                        .foregroundColor(GypsumColor.textSecondary)
                                        .padding(.top, 4)
                                } else {
                                    Text("Live indexing and metadata generation happen automatically below.")
                                        .font(GypsumFont.caption)
                                        .foregroundColor(GypsumColor.textSecondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        if !accessibleDirectories.isEmpty {
                            Divider()
                            GypsumCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Accessible directories")
                                        .font(GypsumFont.headline)
                                        .foregroundColor(GypsumColor.text)
                                    ForEach(accessibleDirectories, id: \.self) { path in
                                        let directoryName = (path as NSString).lastPathComponent
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(directoryName.isEmpty ? path : directoryName)
                                                .font(GypsumFont.caption)
                                                .foregroundColor(GypsumColor.textSecondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Text(path)
                                                .font(GypsumFont.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 4) {
                            Divider()
                            Text("Live indexing always runs in the background.")
                                .font(GypsumFont.caption)
                                .foregroundColor(.secondary)
                            Text("Images: \(images.count)")
                                .font(GypsumFont.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(minWidth: 280)
                }
            },
                              content: {
                Group {
                    if selectedDirectory == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(GypsumColor.textSecondary)
                            Text("Add or load a folder")
                                .font(.headline)
                            Text("Watch folders in the sidebar to begin indexing and viewing their images.")
                                .font(GypsumFont.caption)
                                .foregroundColor(GypsumColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(GypsumColor.background)
                    } else {
                        let indexingCount = directoryScanManager.activeIndexingPaths.count
                        let activityStatus: String = {
                            if isLoading {
                                return "Loading…"
                            }
                            if indexingCount > 0 {
                                return "Indexing \(indexingCount) folders…"
                            }
                            return repository.activityMessage ?? "Ready"
                        }()

                        VStack(spacing: 12) {
                            HStack {
                                if isLoading || repository.isBusy {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(activityStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Live indexing")
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

                            Picker("View mode", selection: $currentViewMode) {
                                ForEach(ViewMode.allCases) { mode in
                                    Text(mode.title)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            Text(lastViewModeMessage ?? "")
                                .font(GypsumFont.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            Picker("Thumbnail size", selection: $thumbnailSizeOption) {
                                ForEach(ThumbnailSizeOption.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal)

                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(GypsumColor.background.opacity(0.3))
                            } else {
                                switch currentViewMode {
                                case .thumbnailGrid:
                                    ImageGridView(
                                        images: images,
                                        selectedImage: $selectedImage,
                                        backgroundTasks: $backgroundTasks,
                                        sizeOption: thumbnailSizeOption
                                    )
                                case .list:
                                    ImageListView(
                                        images: images,
                                        selectedImage: $selectedImage
                                    )
                                case .singleImage:
                                    if let image = selectedImage {
                                        SingleImageView(
                                            image: image,
                                            gallery: images,
                                            onSelectImage: { selectedImage = $0 }
                                        )
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
                    }
                }
                .frame(minWidth: 800, minHeight: 600)
            },
                              detail: {
                if let image = selectedImage {
                    MetadataPanel(image: image)
                        .id(image.url)
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
        let metadataManager = MetadataStoreManager(rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
        let repository = ObservableImageRepository(metadataStore: metadataManager.store)
        repository.updateImages([
            SpectasiaImage(
                url: URL(fileURLWithPath: "/tmp/sample1.jpg"),
                metadata: ImageMetadata(rating: 3, tags: ["preview", "landscape"], fileSize: 1024, modificationDate: Date(), fileExtension: "jpg")
            ),
            SpectasiaImage(
                url: URL(fileURLWithPath: "/tmp/sample2.png"),
                metadata: ImageMetadata(rating: 5, tags: ["portrait"], fileSize: 2048, modificationDate: Date(), fileExtension: "png")
            )
        ])
        let appConfig = AppConfig()
        let permissionManager = PermissionManager()
        let scanManager = DirectoryScanManager(
            metadataStore: metadataManager.store,
            metadataStoreRoot: metadataManager.rootDirectory,
            appConfig: appConfig,
            permissionManager: permissionManager
        )

        return SpectasiaLayout(
            images: .constant(repository.images),
            selectedImage: .constant(repository.images.first),
            selectedDirectory: .constant(URL(fileURLWithPath: "/tmp")),
            currentViewMode: .constant(.thumbnailGrid),
            isLoading: .constant(false),
            backgroundTasks: .constant(0),
            onSelectDirectory: { _ in }
        )
        .environmentObject(repository)
        .environmentObject(scanManager)
    }
}
