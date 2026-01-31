import CoreImage
import Foundation
import CoreGraphics
import ImageIO
import CoreServices

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
    private static let defaultMaxCacheSizeBytes: Int64 = 1 * 1024 * 1024 * 1024 // 1 GiB

    private let metadataStore: MetadataStore
    private let fileManager = FileManager.default
    private let maxCacheSizeBytes: Int64
    private let ciContext: CIContext

    public init(metadataStore: MetadataStore, maxCacheSizeBytes: Int64) {
        self.metadataStore = metadataStore
        self.maxCacheSizeBytes = maxCacheSizeBytes
        self.ciContext = CIContext(options: [.priorityRequestLow: true])
    }

    public convenience init(metadataStore: MetadataStore) {
        self.init(metadataStore: metadataStore, maxCacheSizeBytes: Self.defaultMaxCacheSizeBytes)
    }

    public convenience init(cacheDirectory: String) {
        self.init(cacheDirectory: cacheDirectory, maxCacheSizeBytes: Self.defaultMaxCacheSizeBytes)
    }

    public convenience init(cacheDirectory: String, maxCacheSizeBytes: Int64) {
        let store = MetadataStore(rootDirectory: URL(fileURLWithPath: cacheDirectory))
        self.init(metadataStore: store, maxCacheSizeBytes: maxCacheSizeBytes)
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

        let prunePlan = await metadataStore.cachePrunePlan(maxBytes: maxCacheSizeBytes)
        if !prunePlan.entries.isEmpty {
            let entries = prunePlan.entries
            let metadataStoreRef = metadataStore
            Task.detached(priority: .background) {
                let cleanupManager = FileManager.default
                for entry in entries {
                    try? cleanupManager.removeItem(at: entry.url)
                }
                await metadataStoreRef.applyPrunedEntries(entries)
            }
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

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let metadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil)
        let shouldToneMap = shouldToneMapThumbnail(from: properties, cgImage: cgImage)
        let finalImage = shouldToneMap ? toneMapImage(cgImage) ?? cgImage : cgImage

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            kUTTypeJPEG,
            1,
            nil
        ) else {
            throw ThumbnailError.cannotEncodeThumbnail
        }

        let finalMetadata = metadata ?? CGImageMetadataCreateMutable()
        let destinationOptions: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ] as CFDictionary

        CGImageDestinationAddImageAndMetadata(destination, finalImage, finalMetadata, destinationOptions)
        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailError.cannotEncodeThumbnail
        }

        return output as Data
    }

    private func shouldToneMapThumbnail(from properties: [CFString: Any]?, cgImage: CGImage) -> Bool {
        if cgImage.bitsPerComponent > 8 {
            return true
        }
        if cgImage.bitmapInfo.contains(.floatComponents) {
            return true
        }
        if let depth = properties?[kCGImagePropertyDepth] as? Int, depth > 8 {
            return true
        }
        if let colorSpaceName = cgImage.colorSpace?.name as String?,
           colorSpaceName.localizedCaseInsensitiveContains("p3") ||
           colorSpaceName.localizedCaseInsensitiveContains("extended") {
            return true
        }
        return false
    }
    private func toneMapImage(_ cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(0.75, forKey: "inputHighlightAmount")
        filter.setValue(0.35, forKey: "inputShadowAmount")

        guard let output = filter.outputImage else { return nil }
        let targetColorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        return ciContext.createCGImage(output, from: output.extent, format: .RGBA8, colorSpace: targetColorSpace)
    }
}
// MARK: - Errors

public enum ThumbnailError: Error {
    case sourceFileNotFound
    case cannotCreateImageSource
    case cannotCreateThumbnail
    case cannotEncodeThumbnail
}
