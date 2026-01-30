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

    private let fileManager = FileManager.default
    private var rootDirectory: URL
    private var indexURL: URL
    private var records: [String: Record] = [:]
    private var persistTask: Task<Void, Never>?

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.indexURL = rootDirectory.appendingPathComponent("metadata-index.json")
        createDirectoryIfNeeded(rootDirectory)
        loadIndex()
    }

    // MARK: - Public API

    public func updateRoot(_ newRoot: URL) {
        rootDirectory = newRoot
        indexURL = newRoot.appendingPathComponent("metadata-index.json")
        createDirectoryIfNeeded(newRoot)
        loadIndex()
    }

    public func xmpURL(for originalURL: URL) -> URL {
        let relativeBase = relativeBasePath(for: originalURL)
        let xmpRoot = rootDirectory.appendingPathComponent("xmp")
        let xmpURL = xmpRoot
            .appendingPathComponent(relativeBase)
            .appendingPathExtension("xmp")
        createDirectoryIfNeeded(xmpURL.deletingLastPathComponent())
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
        return url
    }

    public func allocateThumbnailURL(for originalURL: URL, size: ThumbnailSize) -> URL {
        let relativeBase = relativeBasePath(for: originalURL)
        let thumbRoot = rootDirectory.appendingPathComponent("thumbnails")
        let baseDir = thumbRoot.appendingPathComponent(relativeBase)
        let uniqueName = "\(size.suffix)-\(UUID().uuidString).jpg"
        let thumbURL = baseDir.appendingPathComponent(uniqueName)
        createDirectoryIfNeeded(baseDir)
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
        isOriginalSafeToRemove: ((URL) -> Bool)? = nil
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

    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            records = [:]
            return
        }
        do {
            let data = try Data(contentsOf: indexURL)
            records = try JSONDecoder().decode([String: Record].self, from: data)
        } catch {
            records = [:]
        }
    }

    private func createDirectoryIfNeeded(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
