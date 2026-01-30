import SwiftUI
import UniformTypeIdentifiers
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
    @State private var treePickerPresented: Bool = false
    @State private var thumbnailSizeOption: ThumbnailSizeOption = .medium
    @State private var viewModeState: ViewModeState = .ready(.thumbnailGrid)
    @State private var viewModeTransitionTask: Task<Void, Never>? = nil
    @State private var viewModeMessageResetTask: Task<Void, Never>? = nil
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
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Folders")
                                            .font(GypsumFont.headline)
                                            .foregroundColor(GypsumColor.text)
                                        Text("\(directoryScanManager.watchedDirectories.count) watched folder\(directoryScanManager.watchedDirectories.count == 1 ? "" : "s")")
                                            .font(GypsumFont.caption)
                                            .foregroundColor(GypsumColor.textSecondary)
                                    }
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Button {
                                            treePickerPresented = true
                                        } label: {
                                            Label("Add folder", systemImage: "plus")
                                        }
                                        .buttonStyle(.bordered)
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
                                Divider()
                                DirectoryTreeView(
                                    selectedPath: selectedDirectory?.path,
                                    onSelectDirectory: onSelectDirectory
                                )
                                .frame(maxHeight: 360)
                                Text("Tap a node to open the folder in the viewer.")
                                    .font(GypsumFont.caption)
                                    .foregroundColor(GypsumColor.textSecondary)
                                    .padding(.vertical, 4)
                                if let message = directoryScanManager.scanCompletionMessage {
                                    Text(message)
                                        .font(GypsumFont.caption)
                                        .foregroundColor(GypsumColor.textSecondary)
                                } else {
                                    Text("Live indexing and metadata generation happen automatically in the background.")
                                        .font(GypsumFont.caption)
                                        .foregroundColor(GypsumColor.textSecondary)
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
                    if directoryScanManager.directoryTree.isEmpty {
                        InitialDirectorySelectionView(
                            directoryToAdd: $directoryToAdd,
                            hasWatchDirectories: false
                        )
                    } else if selectedDirectory == nil {
                        InitialDirectorySelectionView(
                            directoryToAdd: $directoryToAdd,
                            hasWatchDirectories: true
                        )
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

                            Picker("View mode", selection: viewModeBinding) {
                                ForEach(ViewMode.allCases) { mode in
                                    Text(mode.title)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            Text(viewModeState.message)
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
        .fileImporter(
            isPresented: $treePickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    directoryToAdd = url
                }
            case .failure(let error):
                CoreLog.error("Directory selection failed: \(error.localizedDescription)", category: "SpectasiaLayout")
            }
        }
        .onAppear {
            viewModeState = .ready(currentViewMode)
        }
        .onChange(of: currentViewMode) { _, newMode in
            if viewModeState != .switching(newMode) {
                viewModeState = .ready(newMode)
            }
        }
    }

    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { currentViewMode },
            set: { handleViewModeChange(to: $0) }
        )
    }

    private func handleViewModeChange(to requested: ViewMode) {
        if requested == currentViewMode {
            viewModeState = .ready(requested)
            return
        }

        if requested == .singleImage && !ensureSingleImageAvailable() {
            viewModeState = .blocked(currentViewMode, reason: "Select an image before using single-image mode.")
            viewModeMessageResetTask?.cancel()
            viewModeMessageResetTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    viewModeState = .ready(currentViewMode)
                }
            }
            return
        }

        transition(to: requested)
    }

    private func ensureSingleImageAvailable() -> Bool {
        if selectedImage != nil {
            return true
        }
        if let first = images.first {
            selectedImage = first
            return true
        }
        return false
    }

    private func transition(to newMode: ViewMode) {
        viewModeTransitionTask?.cancel()
        viewModeMessageResetTask?.cancel()
        viewModeMessageResetTask = nil
        viewModeState = .switching(newMode)
        viewModeTransitionTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await MainActor.run {
                currentViewMode = newMode
                viewModeState = .ready(newMode)
                viewModeTransitionTask = nil
            }
        }
    }

    private enum ViewModeState: Equatable {
        case ready(ViewMode)
        case switching(ViewMode)
        case blocked(ViewMode, reason: String)

        var message: String {
            switch self {
            case .ready(let mode):
                return "Viewing \(mode.title)"
            case .switching(let mode):
                return "Switching to \(mode.title)…"
            case .blocked(_, let reason):
                return reason
            }
        }
    }


    private struct InitialDirectorySelectionView: View {
        @Binding var directoryToAdd: URL?
        let hasWatchDirectories: Bool

        private var iconName: String {
            hasWatchDirectories ? "tray" : "folder.badge.plus"
        }

        private var titleText: String {
            hasWatchDirectories ? "Select a watched folder" : "No watch folders configured yet"
        }

        private var subtitleText: String {
            if hasWatchDirectories {
                return "Choose a folder from the directory tree on the left to begin browsing its images."
            }
            return "Add a folder to start scanning metadata, generating thumbnails, and running AI analysis."
        }

        private var manualInstruction: String {
            hasWatchDirectories
                ? "Manual selection only — tap a tree node once you've added the folder."
                : "Manual selection only — the app won’t prompt automatically on launch."
        }

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundColor(GypsumColor.textSecondary)
                Text(titleText)
                    .font(.title3)
                Text(subtitleText)
                    .font(GypsumFont.caption)
                    .foregroundColor(GypsumColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                DirectoryPicker(
                    prompt: hasWatchDirectories ? "Add another folder" : "Add folder",
                    selectedURL: $directoryToAdd
                )
                Text(manualInstruction)
                    .font(GypsumFont.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GypsumColor.background)
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
