import Foundation

/// Manages watched directories, schedules indexing, and exposes a directory tree to the UI.
@available(macOS 10.15, *)
@MainActor
public final class DirectoryScanManager: ObservableObject {
    public struct DirectoryNode: Identifiable, Hashable {
        public let id: String
        public let url: URL
        public var status: DirectoryScanStatus
        public var fileCount: Int
        public var lastScanDate: Date?
        public var children: [DirectoryNode]
        public var isRoot: Bool

        public init(
            id: String,
            url: URL,
            status: DirectoryScanStatus,
            fileCount: Int,
            lastScanDate: Date?,
            children: [DirectoryNode] = [],
            isRoot: Bool = false
        ) {
            self.id = id
            self.url = url
            self.status = status
            self.fileCount = fileCount
            self.lastScanDate = lastScanDate
            self.children = children
            self.isRoot = isRoot
        }
    }

    @Published public private(set) var watchedDirectories: [AppConfig.DirectoryBookmark] = []
    @Published public private(set) var directoryTree: [DirectoryNode] = []
    @Published public private(set) var expandedPaths: Set<String> = []
    @Published public private(set) var activeIndexingPaths: Set<String> = []
    @Published public var scanCompletionMessage: String? = nil

    private let metadataStore: MetadataStore
    private let metadataIndexStore: MetadataIndexStore
    private let permissionManager: PermissionManager
    private let appConfig: AppConfig
    private var scanningTasks: [String: Task<Void, Never>] = [:]
    private var securityTokens: [String: SecurityScopeToken] = [:]
    private let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "bmp", "webp"
    ]

    public init(
        metadataStore: MetadataStore,
        metadataStoreRoot: URL,
        appConfig: AppConfig,
        permissionManager: PermissionManager
    ) {
        self.metadataStore = metadataStore
        self.metadataIndexStore = MetadataIndexStore(rootDirectory: metadataStoreRoot)
        self.appConfig = appConfig
        self.permissionManager = permissionManager

        Task {
            await reloadWatchedDirectories()
            await refreshDirectoryTree()
            await startIndexingAll()
        }
    }

    // MARK: - Public API

    public func addDirectory(_ url: URL) async {
        CoreLog.info("Adding watched directory \(url.path)", category: "DirectoryScanManager")
        guard let bookmarkData = permissionManager.storeBookmark(for: url) else {
            CoreLog.error("Failed to create bookmark for \(url.path)", category: "DirectoryScanManager")
            return
        }
        let bookmark = AppConfig.DirectoryBookmark(path: url.path, data: bookmarkData)
        appConfig.addMonitoredDirectory(bookmark)
        watchedDirectories = appConfig.monitoredDirectoryBookmarks
        await metadataIndexStore.updateDirectory(path: url.path, parentPath: url.deletingLastPathComponent().path, status: .idle, fileCount: 0, lastScanDate: nil)
        await refreshDirectoryTree()
        publishScanMessage(String(format: NSLocalizedString("Watching %@", comment: "Toast when a folder is added to the watch list."), displayName(for: url)))
        startIndexing(bookmark: bookmark)
    }

    public func removeDirectory(at path: String) async {
        CoreLog.info("Removing watched directory \(path)", category: "DirectoryScanManager")
        await cancelScan(path: path)
        appConfig.removeMonitoredDirectory(path: path)
        watchedDirectories = appConfig.monitoredDirectoryBookmarks
        securityTokens[path] = nil
        await refreshDirectoryTree()
        publishScanMessage(String(format: NSLocalizedString("Stopped watching %@", comment: "Toast shown when a watch folder is removed."), displayName(forPath: path)))
    }

    public func toggleExpansion(for path: String) {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
    }

    public func isExpanded(_ path: String) -> Bool {
        expandedPaths.contains(path)
    }

    public func isIndexing(_ path: String) -> Bool {
        activeIndexingPaths.contains(path)
    }

    public func expandAllDirectories() {
        let allPaths = gatherNodePaths(from: directoryTree)
        expandedPaths = Set(allPaths)
    }

    public func collapseAllDirectories() {
        expandedPaths.removeAll()
    }

    public func reindexWatchedDirectories() {
        for bookmark in watchedDirectories {
            startIndexingRoot(at: bookmark.path)
        }
    }

    public func startIndexingRoot(at path: String) {
        guard let bookmark = watchedDirectories.first(where: { $0.path == path }) else { return }
        startIndexing(bookmark: bookmark)
    }

    @MainActor
    public func bookmark(for path: String) -> AppConfig.DirectoryBookmark? {
        watchedDirectories.first { $0.path == path }
    }

    // MARK: - Private Helpers

    private func startIndexingAll() async {
        for bookmark in appConfig.monitoredDirectoryBookmarks {
            startIndexing(bookmark: bookmark)
        }
    }

    private func startIndexing(bookmark: AppConfig.DirectoryBookmark) {
        let path = bookmark.path
        guard scanningTasks[path] == nil else { return }
        let displayName = displayName(forPath: path)
        guard let directoryURL = permissionManager.resolveBookmark(bookmark.data) else {
            CoreLog.error("Unable to resolve bookmark for indexing: \(path)", category: "DirectoryScanManager")
            publishFailure(for: displayName)
            return
        }
        guard let token = permissionManager.beginAccess(to: directoryURL) else {
            CoreLog.error("Failed to start access for \(path)", category: "DirectoryScanManager")
            publishFailure(for: displayName)
            return
        }
        securityTokens[path] = token
        markIndexing(path: path, active: true)
        let language = appConfig.languagePublished
        let metadataStoreRef = metadataStore
        let metadataIndexRef = metadataIndexStore
        let extensions = imageExtensions

        let scanTask = Task.detached(priority: .background) {
            await DirectoryScanManager.performScan(
                root: directoryURL,
                metadataStore: metadataStoreRef,
                metadataIndexStore: metadataIndexRef,
                imageExtensions: extensions,
                language: language
            )
        }

        scanningTasks[path] = scanTask

        Task {
            await scanTask.value
            scanningTasks[path] = nil
            securityTokens[path] = nil
            markIndexing(path: path, active: false)
            await refreshDirectoryTree()
            await publishCompletion(for: path, displayName: displayName)
        }
    }

    private func cancelScan(path: String) async {
        if let task = scanningTasks[path] {
            task.cancel()
            scanningTasks[path] = nil
        }
        securityTokens[path] = nil
        markIndexing(path: path, active: false)
    }

    private func markIndexing(path: String, active: Bool) {
        if active {
            activeIndexingPaths.insert(path)
        } else {
            activeIndexingPaths.remove(path)
        }
    }

    private func reloadWatchedDirectories() async {
        watchedDirectories = appConfig.monitoredDirectoryBookmarks
    }

    private func refreshDirectoryTree() async {
        let records = await metadataIndexStore.directoryRecords()
        let watchedSet = Set(watchedDirectories.map { $0.path })
        let grouped = Dictionary(grouping: records, by: { $0.parentPath })

        func buildNode(from record: DirectoryRecord) -> DirectoryNode {
            let children = (grouped[record.path] ?? [])
                .sorted(by: { $0.path < $1.path })
                .map(buildNode)
            return DirectoryNode(
                id: record.path,
                url: URL(fileURLWithPath: record.path),
                status: record.status,
                fileCount: record.fileCount,
                lastScanDate: record.lastScanDate,
                children: children,
                isRoot: watchedSet.contains(record.path)
            )
        }

        var roots: [DirectoryNode] = []
        for path in watchedSet.sorted() {
            if let record = records.first(where: { $0.path == path }) {
                roots.append(buildNode(from: record))
            } else {
                let stubChildren = (grouped[path] ?? [])
                    .sorted(by: { $0.path < $1.path })
                    .map(buildNode)
                roots.append(DirectoryNode(
                    id: path,
                    url: URL(fileURLWithPath: path),
                    status: .idle,
                    fileCount: 0,
                    lastScanDate: nil,
                    children: stubChildren,
                    isRoot: true
                ))
            }
        }

        directoryTree = roots
    }

    private func gatherNodePaths(from nodes: [DirectoryNode]) -> [String] {
        var paths: [String] = []
        for node in nodes {
            paths.append(node.id)
            paths.append(contentsOf: gatherNodePaths(from: node.children))
        }
        return paths
    }

    // MARK: - Static Scan Helpers

    private static func performScan(
        root: URL,
        metadataStore: MetadataStore,
        metadataIndexStore: MetadataIndexStore,
        imageExtensions: Set<String>,
        language: AppLanguage
    ) async {
        var queue: [URL] = [root]
        while !queue.isEmpty {
            if Task.isCancelled {
                return
            }
            let currentLevel = queue
            queue = []
            await withTaskGroup(of: [URL].self) { group in
                for directory in currentLevel {
                    group.addTask {
                        await DirectoryScanManager.scanDirectory(
                            directory: directory,
                            metadataStore: metadataStore,
                            metadataIndexStore: metadataIndexStore,
                            imageExtensions: imageExtensions,
                            language: language
                        )
                    }
                }
                for await discovered in group {
                    queue.append(contentsOf: discovered)
                }
            }
        }
    }

    private static func scanDirectory(
        directory: URL,
        metadataStore: MetadataStore,
        metadataIndexStore: MetadataIndexStore,
        imageExtensions: Set<String>,
        language: AppLanguage
    ) async -> [URL] {
        var discoveredDirectories: [URL] = []
        let fileManager = FileManager.default
        let parentPath = directory.deletingLastPathComponent().path
        await metadataIndexStore.updateDirectory(
            path: directory.path,
            parentPath: parentPath,
            status: .scanning,
            fileCount: 0,
            lastScanDate: nil
        )

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var fileCount = 0
        for url in contents {
            if Task.isCancelled {
                break
            }
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                discoveredDirectories.append(url)
                await metadataIndexStore.updateDirectory(
                    path: url.path,
                    parentPath: directory.path,
                    status: .idle,
                    fileCount: 0,
                    lastScanDate: nil
                )
                continue
            }

            if !imageExtensions.contains(url.pathExtension.lowercased()) {
                continue
            }

            fileCount += 1
                    let attrs = try? fileManager.attributesOfItem(atPath: url.path)
                    let modificationDate = (attrs?[.modificationDate] as? Date) ?? Date()
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            await metadataIndexStore.addOrUpdateFileRecord(
                for: url,
                directoryPath: directory.path,
                size: size,
                modificationDate: modificationDate
            )
            await MetadataTaskRunner.scheduleTasks(
                fileURL: url,
                modificationDate: modificationDate,
                metadataStore: metadataStore,
                metadataIndexStore: metadataIndexStore,
                language: language
            )
        }

        await metadataIndexStore.updateDirectory(
            path: directory.path,
            parentPath: parentPath,
            status: .complete,
            fileCount: fileCount,
            lastScanDate: Date()
        )
        return discoveredDirectories
    }

    private struct MetadataTaskRunner {
        static func scheduleTasks(
            fileURL: URL,
            modificationDate: Date,
            metadataStore: MetadataStore,
            metadataIndexStore: MetadataIndexStore,
            language: AppLanguage
        ) async {
            if await metadataIndexStore.needsThumbnail(for: fileURL, since: modificationDate) {
                Task.detached(priority: .background) {
                    await runThumbnailTask(
                        fileURL: fileURL,
                        metadataStore: metadataStore,
                        metadataIndexStore: metadataIndexStore
                    )
                }
            }
            if await metadataIndexStore.needsAIAnalysis(for: fileURL, since: modificationDate) {
                Task.detached(priority: .background) {
                    await runAITask(
                        fileURL: fileURL,
                        metadataStore: metadataStore,
                        metadataIndexStore: metadataIndexStore,
                        language: language
                    )
                }
            }
        }

        private static func runThumbnailTask(
            fileURL: URL,
            metadataStore: MetadataStore,
            metadataIndexStore: MetadataIndexStore
        ) async {
            let thumbnailService = ThumbnailService(metadataStore: metadataStore)
            do {
                _ = try await thumbnailService.generateThumbnail(for: fileURL, size: .small, regenerate: false)
                await metadataIndexStore.markThumbnailGenerated(for: fileURL, at: Date())
            } catch {
                CoreLog.error("Thumbnail failed for \(fileURL.path): \(error.localizedDescription)", category: "DirectoryScanManager")
            }
        }

        private static func runAITask(
            fileURL: URL,
            metadataStore: MetadataStore,
            metadataIndexStore: MetadataIndexStore,
            language: AppLanguage
        ) async {
            let aiService = AIService()
            do {
                _ = try aiService.analyze(imageAt: fileURL, language: language)
                await metadataIndexStore.markAIAnalyzed(for: fileURL, at: Date())
            } catch {
                CoreLog.error("AI analysis failed for \(fileURL.path): \(error.localizedDescription)", category: "DirectoryScanManager")
            }
        }
    }

    private func publishScanMessage(_ message: String) {
        scanCompletionMessage = message
    }

    private func publishFailure(for displayName: String) {
        publishScanMessage(String(format: NSLocalizedString("Indexing failed for %@", comment: "Toast shown when indexing cannot start"), displayName))
    }

    private func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    private func displayName(forPath path: String) -> String {
        displayName(for: URL(fileURLWithPath: path))
    }

    private func publishCompletion(for path: String, displayName: String) async {
        let record = await metadataIndexStore.directoryRecord(for: path)
        let count = record?.fileCount ?? 0
        publishScanMessage(String(format: NSLocalizedString("Indexed %lld files in %@", comment: "Toast shown after indexing completes"), Int64(count), displayName))
    }
}
