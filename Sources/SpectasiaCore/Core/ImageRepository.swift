import Foundation
import os.log

// MARK: - Logging

private let logger = Logger(subsystem: "com.spectasia.core", category: "ImageRepository")

// MARK: - Models

/// Represents an image in the repository
public struct SpectasiaImage: Sendable {
    public let url: URL
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

    public init(url: URL, metadata: ImageMetadata = ImageMetadata(), thumbnails: [ThumbnailSize: URL] = [:]) {
        self.url = url
        self.metadata = metadata
        self.thumbnails = thumbnails
    }
}

// MARK: - Protocols

/// Protocol for background task coordination
public protocol BackgroundCoordinating: Actor {
    func queueThumbnailGeneration(for url: URL, size: ThumbnailSize, priority: TaskPriority)
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
public actor BackgroundCoordinator: BackgroundCoordinating {
    private var thumbnailQueue: [(url: URL, size: ThumbnailSize, priority: TaskPriority)] = []
    private var aiQueue: [(url: URL, priority: TaskPriority)] = []
    private var isProcessing = false

    private let thumbnailService: ThumbnailService
    private let aiService: AIService
    private let xmpService: XMPService

    public init(
        thumbnailService: ThumbnailService = ThumbnailService(),
        aiService: AIService = AIService(),
        xmpService: XMPService = XMPService()
    ) {
        self.thumbnailService = thumbnailService
        self.aiService = aiService
        self.xmpService = xmpService
    }

    public func queueThumbnailGeneration(for url: URL, size: ThumbnailSize, priority: TaskPriority = .normal) {
        thumbnailQueue.append((url, size, priority))
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

    private func processThumbnailTask(_ task: (url: URL, size: ThumbnailSize, priority: TaskPriority)) async {
        do {
            _ = try thumbnailService.generateThumbnail(for: task.url, size: task.size)
        } catch {
            // Log error but continue processing
            logger.error("Thumbnail generation failed for \(task.url.path): \(error.localizedDescription)")
        }
    }

    private func processAITask(_ task: (url: URL, priority: TaskPriority)) async {
        do {
            let tags = try aiService.analyze(imageAt: task.url, language: .english)
            // Save tags to XMP
            try xmpService.writeTags(url: task.url, tags: tags)
        } catch {
            // Log error but continue processing
            logger.error("AI analysis failed for \(task.url.path): \(error.localizedDescription)")
        }
    }
}

// MARK: - Image Repository

/// Repository for managing image collection
public actor ImageRepository {
    private let config: AppConfig
    private let backgroundCoordinator: BackgroundCoordinating
    private nonisolated(unsafe) let fileMonitor: FileMonitorService
    private let xmpService: XMPService

    public private(set) var images: [SpectasiaImage] = []

    public init(
        config: AppConfig = AppConfig(),
        backgroundCoordinator: BackgroundCoordinating? = nil,
        fileMonitor: FileMonitorService = FileMonitorService(),
        xmpService: XMPService = XMPService()
    ) {
        self.config = config
        self.backgroundCoordinator = backgroundCoordinator ?? BackgroundCoordinator()
        self.fileMonitor = fileMonitor
        self.xmpService = xmpService

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
        let metadata = try xmpService.readMetadata(url: url)

        // Create image
        let image = SpectasiaImage(url: url, metadata: metadata)
        images.append(image)

        // Queue background tasks
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .small, priority: .high)
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .medium, priority: .normal)
        await backgroundCoordinator.queueThumbnailGeneration(for: url, size: .large, priority: .low)
        await backgroundCoordinator.queueAIAnalysis(for: url, priority: .normal)

        // Start processing
        await backgroundCoordinator.startProcessing()
    }

    /// Remove an image from the repository
    public func removeImage(at url: URL) {
        images.removeAll { $0.url.path == url.path }
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
    }
}
