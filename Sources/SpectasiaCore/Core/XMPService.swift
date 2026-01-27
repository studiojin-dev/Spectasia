import Foundation

/// Image metadata read from XMP sidecar
public struct ImageMetadata: Sendable {
    public var rating: Int
    public var tags: [String]

    public init(rating: Int = 0, tags: [String] = []) {
        self.rating = rating
        self.tags = tags
    }
}

/// Service for reading/writing XMP metadata via sidecar files
public class XMPService {
    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Public Methods

    /// Read metadata from XMP sidecar
    /// - Parameter url: URL of the image file
    /// - Returns: ImageMetadata containing rating and tags
    /// - Throws: XMPError if file doesn't exist or cannot be read
    public func readMetadata(url: URL) throws -> ImageMetadata {
        // Check if image exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw XMPError.fileNotFound
        }

        // Try to read from sidecar
        let sidecarURL = url.deletingPathExtension().appendingPathExtension("xmp")

        guard fileManager.fileExists(atPath: sidecarURL.path) else {
            // No sidecar exists, return empty metadata
            return ImageMetadata()
        }

        // Parse XMP from sidecar
        let xmpContent = try String(contentsOf: sidecarURL, encoding: .utf8)
        return parseXMP(xmpContent)
    }

    /// Write rating to XMP sidecar
    /// - Parameters:
    ///   - url: URL of the image file
    ///   - rating: Rating value (0-5)
    /// - Throws: XMPError if operation fails
    public func writeRating(url: URL, rating: Int) throws {
        var metadata = try readMetadata(url: url)
        metadata.rating = rating
        try writeMetadata(url: url, metadata: metadata)
    }

    /// Write tags to XMP sidecar
    /// - Parameters:
    ///   - url: URL of the image file
    ///   - tags: Array of tag strings
    /// - Throws: XMPError if operation fails
    public func writeTags(url: URL, tags: [String]) throws {
        var metadata = try readMetadata(url: url)
        metadata.tags = tags
        try writeMetadata(url: url, metadata: metadata)
    }

    // MARK: - Private Methods

    private func writeMetadata(url: URL, metadata: ImageMetadata) throws {
        let sidecarURL = url.deletingPathExtension().appendingPathExtension("xmp")
        let xmpContent = generateXMP(metadata: metadata, imageURL: url)
        try xmpContent.write(to: sidecarURL, atomically: true, encoding: .utf8)
    }

    private func parseXMP(_ xmpContent: String) -> ImageMetadata {
        var rating = 0
        var tags: [String] = []

        // Simple XML parsing for XMP
        // In production, use proper XML parser
        if let ratingRange = xmpContent.range(of: "xmp:Rating=\"", options: .caseInsensitive) {
            let start = ratingRange.upperBound
            if let endRange = xmpContent[start...].range(of: "\"") {
                let ratingString = String(xmpContent[start..<endRange.lowerBound])
                rating = Int(ratingString) ?? 0
            }
        }

        // Parse Dublin Core subjects (tags)
        if let subjectStart = xmpContent.range(of: "<dc:subject>") {
            let start = subjectStart.upperBound
            if let subjectEnd = xmpContent[start...].range(of: "</dc:subject>") {
                let subjectContent = String(xmpContent[start..<subjectEnd.lowerBound])
                // Extract individual tags from <rdf:li> elements
                let liPattern = "<rdf:li>(.*?)</rdf:li>"
                if let regex = try? NSRegularExpression(pattern: liPattern, options: []) {
                    let matches = regex.matches(in: subjectContent, options: [], range: NSRange(subjectContent.startIndex..., in: subjectContent))
                    tags = matches.compactMap { match in
                        if let range = Range(match.range(at: 1), in: subjectContent) {
                            return String(subjectContent[range])
                        }
                        return nil
                    }
                }
            }
        }

        return ImageMetadata(rating: rating, tags: tags)
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

// MARK: - Errors

public enum XMPError: Error {
    case fileNotFound
    case invalidXMPFormat
}
