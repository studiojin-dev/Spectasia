import Foundation

/// Current status of a directory scan.
@available(macOS 10.15, *)
public enum DirectoryScanStatus: String, Codable, Sendable {
    case idle
    case scanning
    case complete
}

/// Record describing a scanned directory.
@available(macOS 10.15, *)
public struct DirectoryRecord: Codable, Sendable {
    public let path: String
    public var parentPath: String?
    public var status: DirectoryScanStatus
    public var fileCount: Int
    public var lastScanDate: Date?

    public init(
        path: String,
        parentPath: String? = nil,
        status: DirectoryScanStatus = .idle,
        fileCount: Int = 0,
        lastScanDate: Date? = nil
    ) {
        self.path = path
        self.parentPath = parentPath
        self.status = status
        self.fileCount = fileCount
        self.lastScanDate = lastScanDate
    }
}

/// Metadata for files discovered during indexing.
@available(macOS 10.15, *)
public struct AIAnalysisSnapshot: Codable, Sendable {
    public let tags: [String]
    public let animals: [String]
    public let objects: [String]
    public let faceCount: Int
    public let mood: String?
    public let analyzedAt: Date

    public init(
        tags: [String],
        animals: [String],
        objects: [String],
        faceCount: Int,
        mood: String?,
        analyzedAt: Date
    ) {
        self.tags = tags
        self.animals = animals
        self.objects = objects
        self.faceCount = faceCount
        self.mood = mood
        self.analyzedAt = analyzedAt
    }
}

@available(macOS 10.15, *)
public struct FileRecord: Codable, Sendable {
    public let path: String
    public var directoryPath: String
    public var size: Int64
    public var modificationDate: Date
    public var thumbnailGeneratedAt: Date?
    public var aiAnalyzedAt: Date?
    public var aiSnapshot: AIAnalysisSnapshot?

    public init(
        path: String,
        directoryPath: String,
        size: Int64,
        modificationDate: Date,
        thumbnailGeneratedAt: Date? = nil,
        aiAnalyzedAt: Date? = nil,
        aiSnapshot: AIAnalysisSnapshot? = nil
    ) {
        self.path = path
        self.directoryPath = directoryPath
        self.size = size
        self.modificationDate = modificationDate
        self.thumbnailGeneratedAt = thumbnailGeneratedAt
        self.aiAnalyzedAt = aiAnalyzedAt
        self.aiSnapshot = aiSnapshot
    }
}

/// Actor responsible for indexing directories and storing metadata snapshots.
@available(macOS 10.15, *)
public actor MetadataIndexStore {
    private struct Payload: Codable {
        let directories: [String: DirectoryRecord]
        let files: [String: FileRecord]
    }

    private let fileManager = FileManager.default
    private var rootDirectory: URL
    private var indexURL: URL
    private var directories: [String: DirectoryRecord] = [:]
    private var files: [String: FileRecord] = [:]
    private var persistTask: Task<Void, Never>?

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.indexURL = rootDirectory.appendingPathComponent("scan-index.json")
        Self.createDirectoryIfNeeded(rootDirectory)
        let payload = Self.loadIndex(from: indexURL)
        self.directories = payload.directories
        self.files = payload.files
    }

    public func updateRootDirectory(_ newRoot: URL) {
        rootDirectory = newRoot
        indexURL = newRoot.appendingPathComponent("scan-index.json")
        Self.createDirectoryIfNeeded(newRoot)
        let payload = Self.loadIndex(from: indexURL)
        directories = payload.directories
        files = payload.files
    }

    public func directoryRecords() -> [DirectoryRecord] {
        Array(directories.values)
    }

    public func directoryRecord(for path: String) -> DirectoryRecord? {
        directories[path]
    }

    public func updateDirectory(
        path: String,
        parentPath: String? = nil,
        status: DirectoryScanStatus? = nil,
        fileCount: Int? = nil,
        lastScanDate: Date? = nil
    ) {
        var record = directories[path] ?? DirectoryRecord(path: path)
        if let parent = parentPath {
            record.parentPath = parent
        }
        if let status = status {
            record.status = status
        }
        if let fileCount = fileCount {
            record.fileCount = fileCount
        }
        if let lastScanDate = lastScanDate {
            record.lastScanDate = lastScanDate
        }
        record.status = status ?? record.status
        directories[path] = record
        schedulePersist()
    }

    public func updateDirectoryStatus(path: String, status: DirectoryScanStatus) {
        updateDirectory(path: path, status: status)
    }

    @discardableResult
    public func addOrUpdateFileRecord(
        for fileURL: URL,
        directoryPath: String,
        size: Int64,
        modificationDate: Date
    ) -> FileRecord {
        let path = fileURL.path
        var record = files[path] ?? FileRecord(path: path, directoryPath: directoryPath, size: size, modificationDate: modificationDate)
        record.size = size
        record.modificationDate = modificationDate
        record.directoryPath = directoryPath
        files[path] = record
        schedulePersist()
        return record
    }

    public func markThumbnailGenerated(for fileURL: URL, at date: Date) {
        updateFileRecord(fileURL: fileURL) { record in
            record.thumbnailGeneratedAt = date
        }
    }

    public func markAIAnalyzed(for fileURL: URL, at date: Date) {
        updateFileRecord(fileURL: fileURL) { record in
            record.aiAnalyzedAt = date
        }
    }

    public func updateAIAnalysis(
        for fileURL: URL,
        result: AIAnalysisResult,
        at date: Date
    ) {
        updateFileRecord(fileURL: fileURL) { record in
            record.aiAnalyzedAt = date
            record.aiSnapshot = AIAnalysisSnapshot(
                tags: result.tags,
                animals: result.animals,
                objects: result.objects,
                faceCount: result.faceCount,
                mood: result.mood,
                analyzedAt: date
            )
        }
    }

    public func fileRecord(for fileURL: URL) -> FileRecord? {
        files[fileURL.path]
    }

    public func needsThumbnail(for fileURL: URL, since modificationDate: Date) -> Bool {
        guard let record = files[fileURL.path] else {
            return true
        }
        if let generatedAt = record.thumbnailGeneratedAt {
            return generatedAt < modificationDate
        }
        return true
    }

    public func needsAIAnalysis(for fileURL: URL, since modificationDate: Date) -> Bool {
        guard let record = files[fileURL.path] else {
            return true
        }
        if let analyzedAt = record.aiAnalyzedAt {
            return analyzedAt < modificationDate
        }
        return true
    }

    // MARK: - Private Helpers

    private func updateFileRecord(fileURL: URL, mutate: (inout FileRecord) -> Void) {
        let path = fileURL.path
        guard var record = files[path] else {
            return
        }
        mutate(&record)
        files[path] = record
        schedulePersist()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [directories, files, indexURL] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            let payload = Payload(directories: directories, files: files)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(payload) {
                try? data.write(to: indexURL, options: .atomic)
            }
        }
    }

    private static func loadIndex(from url: URL) -> Payload {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return Payload(directories: [:], files: [:])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            return Payload(directories: [:], files: [:])
        }
    }

    private static func createDirectoryIfNeeded(_ url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
