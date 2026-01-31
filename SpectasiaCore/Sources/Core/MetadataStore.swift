import Foundation

/// Thread-safe manager for XMP and thumbnail paths with persistent index.
@available(macOS 10.15, *)
public actor MetadataStore {
    public struct Record: Codable, Sendable {
        public var xmpPath: String?
        public var thumbnails: [String: String]
        public var updatedAt: Date

        public init(xmpPath: String? = nil, thumbnails: [String: String] = [:], updatedAt: Date = Date()) {
            self.xmpPath = xmpPath
            self.thumbnails = thumbnails
            self.updatedAt = updatedAt
        }
    }

    public struct ThumbnailPruneEntry: Sendable {
        public let originalPath: String
        public let key: String
        public let url: URL
        public let timestamp: Date
        public let fileSize: Int64

        public init(originalPath: String, key: String, url: URL, timestamp: Date, fileSize: Int64) {
            self.originalPath = originalPath
            self.key = key
            self.url = url
            self.timestamp = timestamp
            self.fileSize = fileSize
        }
    }

    public struct CachePrunePlan: Sendable {
        public let entries: [ThumbnailPruneEntry]
        public let currentSize: Int64
        public let targetSize: Int64

        public init(entries: [ThumbnailPruneEntry], currentSize: Int64, targetSize: Int64) {
            self.entries = entries
            self.currentSize = currentSize
            self.targetSize = targetSize
        }

        public var bytesToFree: Int64 {
            max(0, currentSize - targetSize)
        }
    }

    private let fileManager = FileManager.default
    private var rootDirectory: URL
    private var indexURL: URL
    private var records: [String: Record] = [:]
    private var persistTask: Task<Void, Never>?

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.indexURL = rootDirectory.appendingPathComponent("metadata-index.json")
        Self.createDirectoryIfNeeded(rootDirectory)
        self.records = Self.loadIndex(from: indexURL)
    }

    // MARK: - Public API

    public func updateRoot(_ newRoot: URL) {
        rootDirectory = newRoot
        indexURL = newRoot.appendingPathComponent("metadata-index.json")
        Self.createDirectoryIfNeeded(newRoot)
        records = Self.loadIndex(from: indexURL)
    }

    public func thumbnailDirectory() -> URL {
        let thumbRoot = rootDirectory.appendingPathComponent("thumbnails")
        Self.createDirectoryIfNeeded(thumbRoot)
        return thumbRoot
    }

    public func xmpURL(for originalURL: URL) -> URL {
        let relativeBase = relativeBasePath(for: originalURL)
        let xmpRoot = rootDirectory.appendingPathComponent("xmp")
        let xmpURL = xmpRoot
            .appendingPathComponent(relativeBase)
            .appendingPathExtension("xmp")
        Self.createDirectoryIfNeeded(xmpURL.deletingLastPathComponent())
        updateRecord(for: originalURL) { record in
            record.xmpPath = xmpURL.path
        }
        return xmpURL
    }

    public func currentThumbnailURL(for originalURL: URL, size: ThumbnailSize) -> URL? {
        guard let record = records[originalURL.path],
              let path = record.thumbnails[size.rawValue] else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: url.path) else {
            updateRecord(for: originalURL) { record in
                record.thumbnails.removeValue(forKey: size.rawValue)
            }
            return nil
        }
        touchRecord(for: originalURL)
        return url
    }

    public func allocateThumbnailURL(for originalURL: URL, size: ThumbnailSize) -> URL {
        let relativeBase = relativeBasePath(for: originalURL)
        let thumbRoot = rootDirectory.appendingPathComponent("thumbnails")
        let baseDir = thumbRoot.appendingPathComponent(relativeBase)
        let uniqueName = "\(size.suffix)-\(UUID().uuidString).jpg"
        let thumbURL = baseDir.appendingPathComponent(uniqueName)
        Self.createDirectoryIfNeeded(baseDir)
        return thumbURL
    }

    public func updateThumbnailURL(for originalURL: URL, size: ThumbnailSize, to url: URL) -> URL? {
        let previous = currentThumbnailURL(for: originalURL, size: size)
        updateRecord(for: originalURL) { record in
            record.thumbnails[size.rawValue] = url.path
        }
        return previous
    }

    public func cleanupMissingFiles(
        removeMissingOriginals: Bool = true,
        isOriginalSafeToRemove: (@Sendable (URL) -> Bool)? = nil
    ) -> (removedRecords: Int, removedFiles: Int) {
        var removedRecords = 0
        var removedFiles = 0

        for (originalPath, record) in records {
            let originalURL = URL(fileURLWithPath: originalPath)
            let originalExists = fileManager.fileExists(atPath: originalURL.path)

            if removeMissingOriginals && !originalExists {
                if let isOriginalSafeToRemove, !isOriginalSafeToRemove(originalURL) {
                    continue
                }
                if let xmp = record.xmpPath {
                    let url = URL(fileURLWithPath: xmp)
                    if fileManager.fileExists(atPath: url.path) {
                        try? fileManager.removeItem(at: url)
                        removedFiles += 1
                    }
                }
                for (_, thumbPath) in record.thumbnails {
                    let url = URL(fileURLWithPath: thumbPath)
                    if fileManager.fileExists(atPath: url.path) {
                        try? fileManager.removeItem(at: url)
                        removedFiles += 1
                    }
                }
                records[originalPath] = nil
                removedRecords += 1
                continue
            }

            var updated = record
            if let xmpPath = record.xmpPath {
                let url = URL(fileURLWithPath: xmpPath)
                if !fileManager.fileExists(atPath: url.path) {
                    updated.xmpPath = nil
                }
            }
            for (sizeKey, thumbPath) in record.thumbnails {
                let url = URL(fileURLWithPath: thumbPath)
                if !fileManager.fileExists(atPath: url.path) {
                    updated.thumbnails.removeValue(forKey: sizeKey)
                }
            }
            records[originalPath] = updated
        }

        schedulePersist()
        return (removedRecords, removedFiles)
    }

    public func currentCacheSize() -> Int64 {
        collectThumbnailEntries(excludingOriginals: []).reduce(0) { $0 + $1.fileSize }
    }

    public func pruneCache(maxBytes: Int64, excludingOriginals: Set<String> = []) -> (removedThumbnails: Int, freedBytes: Int64) {
        let plan = cachePrunePlan(maxBytes: maxBytes, excludingOriginals: excludingOriginals)
        guard !plan.entries.isEmpty else {
            return (0, 0)
        }

        for entry in plan.entries {
            if fileManager.fileExists(atPath: entry.url.path) {
                try? fileManager.removeItem(at: entry.url)
            }
        }

        let applied = applyPrunedEntries(plan.entries)
        return applied
    }

    public func cachePrunePlan(maxBytes: Int64, excludingOriginals: Set<String> = []) -> CachePrunePlan {
        guard maxBytes > 0 else {
            return CachePrunePlan(entries: [], currentSize: 0, targetSize: maxBytes)
        }

        var entries = collectThumbnailEntries(excludingOriginals: excludingOriginals)
        let totalSize = entries.reduce(0) { $0 + $1.fileSize }
        guard totalSize > maxBytes else {
            return CachePrunePlan(entries: [], currentSize: totalSize, targetSize: maxBytes)
        }

        entries.sort { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.fileSize < rhs.fileSize
            }
            return lhs.timestamp < rhs.timestamp
        }

        var currentSize = totalSize
        var toRemove: [ThumbnailPruneEntry] = []
        for entry in entries {
            if currentSize <= maxBytes {
                break
            }
            toRemove.append(entry)
            currentSize -= entry.fileSize
        }

        return CachePrunePlan(entries: toRemove, currentSize: totalSize, targetSize: maxBytes)
    }

    public func applyPrunedEntries(_ entries: [ThumbnailPruneEntry]) -> (removedThumbnails: Int, freedBytes: Int64) {
        guard !entries.isEmpty else {
            return (0, 0)
        }

        var freed: Int64 = 0
        for entry in entries {
            freed += entry.fileSize
            if var record = records[entry.originalPath] {
                record.thumbnails.removeValue(forKey: entry.key)
                record.updatedAt = Date()
                if record.thumbnails.isEmpty && record.xmpPath == nil {
                    records[entry.originalPath] = nil
                } else {
                    records[entry.originalPath] = record
                }
            }
        }

        schedulePersist()
        return (entries.count, freed)
    }

    public func record(for originalURL: URL) -> Record? {
        records[originalURL.path]
    }

    // MARK: - Private Helpers

    private func relativeBasePath(for originalURL: URL) -> String {
        let components = originalURL.standardizedFileURL.pathComponents
        let trimmed = components.dropFirst()
        let path = trimmed.joined(separator: "/")
        return (path as NSString).deletingPathExtension
    }

    private func updateRecord(for originalURL: URL, mutate: (inout Record) -> Void) {
        let key = originalURL.path
        var record = records[key] ?? Record()
        mutate(&record)
        record.updatedAt = Date()
        records[key] = record
        schedulePersist()
    }

    private func touchRecord(for originalURL: URL) {
        let key = originalURL.path
        guard var record = records[key] else { return }
        record.updatedAt = Date()
        records[key] = record
        schedulePersist()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [indexURL, records] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            let payload = records
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(payload) {
                try? data.write(to: indexURL, options: .atomic)
            }
        }
    }

    private static func loadIndex(from url: URL) -> [String: Record] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Record].self, from: data)
        } catch {
            return [:]
        }
    }

    private static func createDirectoryIfNeeded(_ url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func collectThumbnailEntries(excludingOriginals: Set<String>) -> [ThumbnailPruneEntry] {
        var entries: [ThumbnailPruneEntry] = []
        for (originalPath, record) in records {
            if excludingOriginals.contains(originalPath) {
                continue
            }
            for (key, path) in record.thumbnails {
                let url = URL(fileURLWithPath: path)
                guard fileManager.fileExists(atPath: url.path) else { continue }
                let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
                entries.append(ThumbnailPruneEntry(
                    originalPath: originalPath,
                    key: key,
                    url: url,
                    timestamp: record.updatedAt,
                    fileSize: size
                ))
            }
        }
        return entries
    }
}
