import Foundation
import Combine

// MARK: - Logging

private let logCategory = "ImageRepository"

// MARK: - Models

/// Represents an image in the repository
public struct SpectasiaImage: Sendable, Identifiable {
    public var url: URL
    public var metadata: ImageMetadata
    public var thumbnails: [ThumbnailSize: URL]
    public var tags: [String] {
        get { metadata.tags }
        set { metadata.tags = newValue }
    }
    public var rating: Int {
        get { metadata.rating }
        set { metadata.rating = newValue }
    }
    public var id: String {
        url.path
    }

    public init(url: URL, metadata: ImageMetadata = ImageMetadata(), thumbnails: [ThumbnailSize: URL] = [:]) {
        self.url = url
        self.metadata = metadata
        self.thumbnails = thumbnails
    }
}

// MARK: - Protocols

/// Protocol for background task coordination
@available(macOS 10.15, *)
public protocol BackgroundCoordinating: Actor {
    func queueThumbnailGeneration(for url: URL, size: ThumbnailSize, priority: TaskPriority, regenerate: Bool)
    func queueAIAnalysis(for url: URL, priority: TaskPriority)
    func startProcessing()
    func pauseProcessing()
    func getProcessingStatus() -> String
}

/// Task priority for background processing
public enum TaskPriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 1
    case high = 2

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Background Coordinator

/// Actor-based coordinator for background image processing
@available(macOS 10.15, *)
public actor BackgroundCoordinator: BackgroundCoordinating {
    private var thumbnailQueue: [(url: URL, size: ThumbnailSize, priority: TaskPriority, regenerate: Bool)] = []
    private var aiQueue: [(url: URL, priority: TaskPriority)] = []
    private var isProcessing = false

    private let thumbnailService: ThumbnailService
    private let aiService: AIService
    private let xmpService: XMPService

    public init(
        thumbnailService: ThumbnailService,
        aiService: AIService = AIService(),
        xmpService: XMPService
    ) {
        self.thumbnailService = thumbnailService
        self.aiService = aiService
        self.xmpService = xmpService
    }

    public func queueThumbnailGeneration(for url: URL, size: ThumbnailSize, priority: TaskPriority = .normal, regenerate: Bool = false) {
        thumbnailQueue.append((url, size, priority, regenerate))
        // Sort by priority (high first)
        thumbnailQueue.sort { $0.priority > $1.priority }
    }

    public func queueAIAnalysis(for url: URL, priority: TaskPriority = .normal) {
        aiQueue.append((url, priority))
        // Sort by priority (high first)
        aiQueue.sort { $0.priority > $1.priority }
    }

    public func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true

        Task {
            await processQueues()
        }
    }

    public func pauseProcessing() {
        isProcessing = false
    }

    public func getProcessingStatus() -> String {
        let totalTasks = thumbnailQueue.count + aiQueue.count
        return "Processing \(totalTasks) tasks"
    }

    // MARK: - Private Methods

    private func processQueues() async {
        while isProcessing && (!thumbnailQueue.isEmpty || !aiQueue.isEmpty) {
            // Process thumbnail tasks first (higher priority)
            if let task = thumbnailQueue.first {
                thumbnailQueue.removeFirst()
                await processThumbnailTask(task)
            }

            // Process AI tasks
            if let task = aiQueue.first {
                aiQueue.removeFirst()
                await processAITask(task)
            }
        }
        isProcessing = false
    }

    private func processThumbnailTask(_ task: (url: URL, size: ThumbnailSize, priority: TaskPriority, regenerate: Bool)) async {
        do {
            _ = try await thumbnailService.generateThumbnail(for: task.url, size: task.size, regenerate: task.regenerate)
        } catch {
            // Log error but continue processing
            CoreLog.error("Thumbnail generation failed for \(task.url.path): \(error.localizedDescription)", category: logCategory)
        }
    }

    private func processAITask(_ task: (url: URL, priority: TaskPriority)) async {
        do {
            let tags = try aiService.analyze(imageAt: task.url, language: .english)
            // Save tags to XMP
            try await xmpService.writeTags(url: task.url, tags: tags)
        } catch {
            // Log error but continue processing
            CoreLog.error("AI analysis failed for \(task.url.path): \(error.localizedDescription)", category: logCategory)
        }
    }
}

// MARK: - Image Repository

/// Repository for managing image collection
@available(macOS 10.15, *)
public actor ImageRepository {
    private let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "bmp", "webp"
    ]
    private let backgroundCoordinator: any BackgroundCoordinating
    private nonisolated(unsafe) let fileMonitor: FileMonitorService
    private let xmpService: XMPService
    private let thumbnailService: ThumbnailService

    public private(set) var images: [SpectasiaImage] = []
    private var currentDirectory: URL?
    private var changeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    public init(
        metadataStore: MetadataStore,
        backgroundCoordinator: (any BackgroundCoordinating)? = nil,
        fileMonitor: FileMonitorService = FileMonitorService(),
        xmpService: XMPService? = nil,
        thumbnailService: ThumbnailService? = nil
    ) {
        let thumbService = thumbnailService ?? ThumbnailService(metadataStore: metadataStore)
        let xmp = xmpService ?? XMPService(metadataStore: metadataStore)
        let coordinator = backgroundCoordinator ?? BackgroundCoordinator(
            thumbnailService: thumbService,
            xmpService: xmp
        )
        self.backgroundCoordinator = coordinator
        self.fileMonitor = fileMonitor
        self.xmpService = xmp
        self.thumbnailService = thumbService

        // Setup file monitoring asynchronously
        Task {
            await setupFileMonitoring()
        }
    }

    // MARK: - Public Methods

    /// Add an image to the repository
    public func addImage(at url: URL) async throws {
        // Check if already exists
        guard !images.contains(where: { $0.url.path == url.path }) else {
            return
        }

        // Load metadata
        let metadata = try await xmpService.readMetadata(url: url)

        // Create image
        let image = SpectasiaImage(url: url, metadata: metadata)
        images.append(image)
        notifyChange()

        // Queue background tasks
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .small, priority: .high, regenerate: false)
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .medium, priority: .normal, regenerate: false)
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .large, priority: .low, regenerate: false)
        await backgroundCoordinator.queueAIAnalysis(for: url, priority: .normal)

        // Start processing
        await backgroundCoordinator.startProcessing()
    }

    /// Remove an image from the repository
    public func removeImage(at url: URL) {
        images.removeAll { $0.url.path == url.path }
        notifyChange()
    }

    /// Get all images in the repository
    public func getImages() async -> [SpectasiaImage] {
        return images
    }

    /// Load images from a directory and add them to the repository
    public func loadImages(in directory: URL) async throws {
        currentDirectory = directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw RepositoryError.directoryNotFound
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let imageURLs = contents.filter { url in
            imageExtensions.contains(url.pathExtension.lowercased())
        }

        for url in imageURLs {
            try await addImage(at: url)
        }
        notifyChange()
    }

    /// Load images and start monitoring a directory for changes
    public func loadAndMonitor(directory: URL) async throws {
        currentDirectory = directory
        try startMonitoring(directory: directory.path)
        try await loadImages(in: directory)
    }

    public func stopMonitoringDirectory() {
        stopMonitoring()
    }

    /// Start monitoring a directory for changes
    public nonisolated func startMonitoring(directory: String) throws {
        try fileMonitor.startMonitoring(directory: directory)
    }

    /// Stop monitoring
    public nonisolated func stopMonitoring() {
        fileMonitor.stopMonitoring()
    }

    /// Get current processing status
    public func getProcessingStatus() async -> String {
        return await backgroundCoordinator.getProcessingStatus()
    }

    public func thumbnailURL(for url: URL, size: ThumbnailSize) async throws -> URL {
        return try await thumbnailService.generateThumbnail(for: url, size: size, regenerate: false)
    }

    public func rescanCurrentDirectory() async throws {
        guard let directory = currentDirectory else { return }
        try await rescanDirectory(directory)
    }

    public func rescanDirectory(_ directory: URL) async throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let imageURLs = contents.filter { url in
            imageExtensions.contains(url.pathExtension.lowercased())
        }

        let existingPaths = Set(images.map { $0.url.path })
        let newPaths = Set(imageURLs.map { $0.path })

        // Remove missing
        let removed = existingPaths.subtracting(newPaths)
        if !removed.isEmpty {
            images.removeAll { removed.contains($0.url.path) }
        }

        // Add new
        for url in imageURLs where !existingPaths.contains(url.path) {
            try await addImage(at: url)
        }

        // Refresh metadata for existing
        let common = existingPaths.intersection(newPaths)
        for url in imageURLs where common.contains(url.path) {
            await refreshImageMetadata(at: url)
        }

        notifyChange()
    }

    public func regenerateThumbnails(for url: URL) async {
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .small, priority: .high, regenerate: true)
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .medium, priority: .normal, regenerate: true)
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .large, priority: .low, regenerate: true)
        await backgroundCoordinator.startProcessing()
    }

    public func regenerateThumbnailsForCurrentDirectory() async {
        guard let directory = currentDirectory else { return }
        let urls = images.filter { $0.url.deletingLastPathComponent() == directory }
        for image in urls {
            await regenerateThumbnails(for: image.url)
        }
    }

    public func regenerateThumbnailsForAllImages() async {
        for image in images {
            await regenerateThumbnails(for: image.url)
        }
    }

    // MARK: - Private Methods

    private func setupFileMonitoring() {
        fileMonitor.onFileCreated = { [weak self] url in
            guard let self = self else { return }
            Task {
                try? await self.addImage(at: url)
            }
        }

        fileMonitor.onFileDeleted = { [weak self] url in
            guard let self = self else { return }
            Task {
                await self.removeImage(at: url)
            }
        }

        fileMonitor.onFileModified = { [weak self] url in
            guard let self = self else { return }
            Task {
                await self.refreshImageMetadata(at: url)
                await self.regenerateThumbnails(for: url)
            }
        }
    }

    private func refreshImageMetadata(at url: URL) async {
        guard let index = images.firstIndex(where: { $0.url.path == url.path }) else {
            return
        }
        do {
            let metadata = try await xmpService.readMetadata(url: url)
            images[index].metadata = metadata
            notifyChange()
        } catch {
            CoreLog.error("Failed to refresh metadata for \(url.path): \(error.localizedDescription)", category: logCategory)
        }
    }

    private func notifyChange() {
        for continuation in changeContinuations.values {
            continuation.yield()
        }
    }

    public nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            Task { [weak self] in
                await self?.addContinuation(continuation, id: id)
            }
            continuation.onTermination = { _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }

    private func addContinuation(_ continuation: AsyncStream<Void>.Continuation, id: UUID) {
        changeContinuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        changeContinuations[id] = nil
    }
}

// MARK: - ObservableObject Wrapper

/// ObservableObject wrapper for actor-based ImageRepository
@available(macOS 10.15, *)
@MainActor
public class ObservableImageRepository: ObservableObject {
    public let repository: ImageRepository
    
    @Published public var images: [SpectasiaImage] = []
    @Published public var activityMessage: String? = nil
    @Published public var isBusy: Bool = false
    @Published public var activityCount: Int = 0
    private var refreshTask: Task<Void, Never>?
    
    public init(metadataStore: MetadataStore, repository: ImageRepository? = nil) {
        let repo = repository ?? ImageRepository(metadataStore: metadataStore)
        self.repository = repo
        objectWillChange.send()
        Task {
            await observeChanges()
        }
    }
    
    public func refreshImages() async {
        self.images = await repository.images
    }

    public func updateImages(_ images: [SpectasiaImage]) {
        self.images = images
    }
    
    public func getImages() async -> [SpectasiaImage] {
        return await repository.getImages()
    }

    public func loadDirectory(_ url: URL) async throws {
        try await repository.loadAndMonitor(directory: url)
        await refreshImages()
    }

    public func loadDirectory(_ url: URL, monitor: Bool) async throws {
        if monitor {
            try await repository.loadAndMonitor(directory: url)
        } else {
            await repository.stopMonitoringDirectory()
            try await repository.loadImages(in: url)
        }
        await refreshImages()
    }

    public func stopMonitoring() async {
        await repository.stopMonitoringDirectory()
    }

    public func thumbnailURL(for url: URL, size: ThumbnailSize) async throws -> URL {
        return try await repository.thumbnailURL(for: url, size: size)
    }

    public func rescanCurrentDirectory() async throws {
        try await repository.rescanCurrentDirectory()
        await refreshImages()
    }

    public func rescanDirectory(_ url: URL) async throws {
        try await repository.rescanDirectory(url)
        await refreshImages()
    }

    public func regenerateThumbnails(for url: URL) async {
        await repository.regenerateThumbnails(for: url)
    }

    public func regenerateThumbnailsForCurrentDirectory() async {
        await repository.regenerateThumbnailsForCurrentDirectory()
    }

    public func regenerateThumbnailsForAllImages() async {
        await repository.regenerateThumbnailsForAllImages()
    }

    private func observeChanges() async {
        let stream = repository.changes()
        for await _ in stream {
            scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self else { return }
            await self.refreshImages()
        }
    }

    @MainActor
    public func startActivity(message: String) {
        activityCount += 1
        activityMessage = message
        isBusy = true
    }

    @MainActor
    public func finishActivity() {
        activityCount = max(0, activityCount - 1)
        if activityCount == 0 {
            isBusy = false
            activityMessage = nil
        }
    }
}

// MARK: - Errors

public enum RepositoryError: Error {
    case directoryNotFound
}
