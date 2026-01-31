import Foundation

/// Image metadata read from XMP sidecar
public struct ImageMetadata: Sendable, Equatable {
    public var rating: Int
    public var tags: [String]
    public var fileSize: Int64
    public var modificationDate: Date
    public var fileExtension: String

    public init(rating: Int = 0, tags: [String] = [], fileSize: Int64 = 0, modificationDate: Date = Date(), fileExtension: String = "") {
        self.rating = rating
        self.tags = tags
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.fileExtension = fileExtension
    }
}

/// Service for reading/writing XMP metadata via sidecar files
@available(macOS 10.15, *)
public final class XMPService: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let metadataStore: MetadataStore

    public init(metadataStore: MetadataStore) {
        self.metadataStore = metadataStore
    }

    // MARK: - Public Methods

    /// Read metadata from XMP sidecar
    /// - Parameter url: URL of the image file
    /// - Returns: ImageMetadata containing rating and tags
    /// - Throws: XMPError if file doesn't exist or cannot be read
    public func readMetadata(url: URL) async throws -> ImageMetadata {
        // Check if image exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw XMPError.fileNotFound
        }

        // Try to read from sidecar
        let sidecarURL = await metadataStore.xmpURL(for: url)

        guard fileManager.fileExists(atPath: sidecarURL.path) else {
            // No sidecar exists, return empty metadata
            return metadataWithFileInfo(from: ImageMetadata(), url: url)
        }

        // Parse XMP from sidecar
        let xmpContent = try String(contentsOf: sidecarURL, encoding: .utf8)
        let parsed = parseXMP(xmpContent)
        if parsed.didFail {
            CoreLog.warning("XMP parse failed for \(url.path), resetting metadata", category: "XMPService")
            try? fileManager.removeItem(at: sidecarURL)
            let resetMetadata = metadataWithFileInfo(from: ImageMetadata(), url: url)
            try await writeMetadata(url: url, metadata: ImageMetadata())
            return resetMetadata
        }
        return metadataWithFileInfo(from: parsed.metadata, url: url)
    }

    /// Write rating to XMP sidecar
    /// - Parameters:
    ///   - url: URL of the image file
    ///   - rating: Rating value (0-5)
    /// - Throws: XMPError if operation fails
    public func writeRating(url: URL, rating: Int) async throws {
        var metadata = try await readMetadata(url: url)
        metadata.rating = rating
        try await writeMetadata(url: url, metadata: metadata)
    }

    /// Write tags to XMP sidecar
    /// - Parameters:
    ///   - url: URL of the image file
    ///   - tags: Array of tag strings
    /// - Throws: XMPError if operation fails
    public func writeTags(url: URL, tags: [String]) async throws {
        var metadata = try await readMetadata(url: url)
        metadata.tags = tags
        try await writeMetadata(url: url, metadata: metadata)
    }

    // MARK: - Private Methods

    private func writeMetadata(url: URL, metadata: ImageMetadata) async throws {
        let sidecarURL = await metadataStore.xmpURL(for: url)
        let xmpContent = generateXMP(metadata: metadata, imageURL: url)
        try xmpContent.write(to: sidecarURL, atomically: true, encoding: .utf8)
    }

    private func parseXMP(_ xmpContent: String) -> ParsedXMP {
        guard let data = xmpContent.data(using: .utf8) else {
            return ParsedXMP(metadata: ImageMetadata(), didFail: true)
        }

        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        let delegate = XMPParserDelegate()
        parser.delegate = delegate
        let success = parser.parse()

        let metadata = ImageMetadata(rating: delegate.rating, tags: delegate.tags)
        let failed = !success || delegate.encounteredError
        return ParsedXMP(metadata: metadata, didFail: failed)
    }

    private func metadataWithFileInfo(from metadata: ImageMetadata, url: URL) -> ImageMetadata {
        var updated = metadata
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path) {
            if let size = attrs[.size] as? NSNumber {
                updated.fileSize = size.int64Value
            }
            if let modDate = attrs[.modificationDate] as? Date {
                updated.modificationDate = modDate
            }
        }
        updated.fileExtension = url.pathExtension.lowercased()
        return updated
    }

    private func generateXMP(metadata: ImageMetadata, imageURL: URL) -> String {
        var xmp = """
        <?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Spectasia">
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about=""
            xmlns:xmp="http://ns.adobe.com/xap/1.0/"
            xmlns:dc="http://purl.org/dc/elements/1.1/"
            xmp:Rating="\(metadata.rating)">
        """

        // Add tags if present
        if !metadata.tags.isEmpty {
            let tagsList = metadata.tags.map { "<rdf:li>\($0)</rdf:li>" }.joined()
            xmp += """
            <dc:subject>
              <rdf:Seq>
                \(tagsList)
              </rdf:Seq>
            </dc:subject>
            """
        }

        xmp += """
          </rdf:Description>
        </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """

        return xmp
    }
}

private struct ParsedXMP {
    let metadata: ImageMetadata
    let didFail: Bool
}

private final class XMPParserDelegate: NSObject, XMLParserDelegate {
    var rating: Int = 0
    var tags: [String] = []

    private var collectingTag = false
    private var currentTag = ""
    private(set) var encounteredError: Bool = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "Description" && (qName == "rdf:Description" || attributeDict.keys.contains("xmp:Rating") || attributeDict.keys.contains("Rating")) {
            if let ratingString = attributeDict["xmp:Rating"] ?? attributeDict["Rating"] {
                rating = Int(ratingString) ?? rating
            }
        }

        if elementName == "li" || qName == "rdf:li" {
            collectingTag = true
            currentTag = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard collectingTag else { return }
        currentTag += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if (elementName == "li" || qName == "rdf:li") && collectingTag {
            let trimmed = currentTag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                tags.append(trimmed)
            }
            collectingTag = false
            currentTag = ""
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        CoreLog.error("XMP parse error: \(error.localizedDescription)", category: "XMPService")
        encounteredError = true
    }
}

// MARK: - Errors

public enum XMPError: Error {
    case fileNotFound
    case invalidXMPFormat
}
