import Foundation
import CoreGraphics
import ImageIO

// MARK: - Constants

/// Thumbnail size constants
private enum ThumbnailSizeConstants {
    static let smallPixelSize = 120
    static let mediumPixelSize = 480
    static let largePixelSize = 1024
}

/// Thumbnail size options
public enum ThumbnailSize: String, Sendable, Codable {
    case small   // 120px
    case medium  // 480px
    case large   // 1024px

    var pixelSize: Int {
        switch self {
        case .small: return ThumbnailSizeConstants.smallPixelSize
        case .medium: return ThumbnailSizeConstants.mediumPixelSize
        case .large: return ThumbnailSizeConstants.largePixelSize
        }
    }

    var suffix: String {
        switch self {
        case .small: return String(ThumbnailSizeConstants.smallPixelSize)
        case .medium: return String(ThumbnailSizeConstants.mediumPixelSize)
        case .large: return String(ThumbnailSizeConstants.largePixelSize)
        }
    }
}

/// Service for generating and caching image thumbnails
@available(macOS 10.15, *)
public final class ThumbnailService: @unchecked Sendable {
    private let metadataStore: MetadataStore
    private let fileManager = FileManager.default

    public init(metadataStore: MetadataStore) {
        self.metadataStore = metadataStore
    }

    public convenience init(cacheDirectory: String) {
        let store = MetadataStore(rootDirectory: URL(fileURLWithPath: cacheDirectory))
        self.init(metadataStore: store)
    }

    @MainActor
    public convenience init(config: AppConfig) {
        self.init(cacheDirectory: config.metadataStoreDirectory)
    }

    // MARK: - Public Methods

    /// Generate or retrieve cached thumbnail
    /// - Parameters:
    ///   - url: URL of the source image
    ///   - size: Desired thumbnail size
    /// - Returns: URL of the thumbnail file
    /// - Throws: ThumbnailError if generation fails
    public func generateThumbnail(for url: URL, size: ThumbnailSize, regenerate: Bool = false) async throws -> URL {
        // Check if source exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw ThumbnailError.sourceFileNotFound
        }

        // Check cache
        if !regenerate, let existing = await metadataStore.currentThumbnailURL(for: url, size: size) {
            return existing
        }

        // Generate thumbnail
        let cacheURL = await metadataStore.allocateThumbnailURL(for: url, size: size)
        let thumbnailData = try generateThumbnailData(from: url, size: size)
        try thumbnailData.write(to: cacheURL)

        let previousURL = await metadataStore.updateThumbnailURL(for: url, size: size, to: cacheURL)
        if let previousURL, previousURL != cacheURL {
            try? fileManager.removeItem(at: previousURL)
        }

        return cacheURL
    }

    // MARK: - Private Methods

    private func generateThumbnailData(from url: URL, size: ThumbnailSize) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ThumbnailError.cannotCreateImageSource
        }

        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: size.pixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            0,
            options as CFDictionary
        ) else {
            throw ThumbnailError.cannotCreateThumbnail
        }

        // Convert CGImage to JPEG data
        guard let data = cgImage.jpegData() else {
            throw ThumbnailError.cannotEncodeThumbnail
        }

        return data
    }
}

// MARK: - CGImage Extension

extension CGImage {
    func jpegData(compressionQuality: CGFloat = 0.8) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }
}

// MARK: - Errors

public enum ThumbnailError: Error {
    case sourceFileNotFound
    case cannotCreateImageSource
    case cannotCreateThumbnail
    case cannotEncodeThumbnail
}
