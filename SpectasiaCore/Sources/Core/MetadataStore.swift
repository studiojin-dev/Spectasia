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

    public func thumbnailURL(for originalURL: URL, size: ThumbnailSize) -> URL {
        let relativeBase = relativeBasePath(for: originalURL)
        let thumbRoot = rootDirectory.appendingPathComponent("thumbnails")
        let baseDir = thumbRoot.appendingPathComponent(relativeBase)
        let thumbURL = baseDir.appendingPathComponent("\(size.suffix).jpg")
        createDirectoryIfNeeded(baseDir)
        updateRecord(for: originalURL) { record in
            record.thumbnails[size.rawValue] = thumbURL.path
        }
        return thumbURL
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
