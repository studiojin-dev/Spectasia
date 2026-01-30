import XCTest
@testable import SpectasiaCore

final class ThumbnailServiceTests: XCTestCase {

    var tempDirectory: URL!
    var cacheDirectory: URL!
    var thumbnailService: ThumbnailService!
    var testImageFile: URL!

    override func setUpWithError() throws {
        // Create temporary directories
        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        cacheDirectory = tempDir.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure thumbnail service with cache directory
        thumbnailService = ThumbnailService(cacheDirectory: cacheDirectory.path)

        // Create a test image file using CoreGraphics
        testImageFile = tempDirectory.appendingPathComponent("test.jpg")
        try createTestImage(at: testImageFile)
    }

    override func tearDownWithError() throws {
        // Clean up
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testGenerateSmallThumbnail() throws {
        // When: Generating 120px thumbnail
        let thumbnailURL = try thumbnailService.generateThumbnail(
            for: testImageFile,
            size: .small
        )

        // Then: Thumbnail should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailURL.path), "Thumbnail should exist")
        XCTAssertTrue(thumbnailURL.path.contains("120"), "Thumbnail should contain size in filename")
    }

    func testGenerateMediumThumbnail() throws {
        // When: Generating 480px thumbnail
        let thumbnailURL = try thumbnailService.generateThumbnail(
            for: testImageFile,
            size: .medium
        )

        // Then: Thumbnail should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailURL.path), "Thumbnail should exist")
        XCTAssertTrue(thumbnailURL.path.contains("480"), "Thumbnail should contain size in filename")
    }

    func testGenerateLargeThumbnail() throws {
        // When: Generating 1024px thumbnail
        let thumbnailURL = try thumbnailService.generateThumbnail(
            for: testImageFile,
            size: .large
        )

        // Then: Thumbnail should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailURL.path), "Thumbnail should exist")
        XCTAssertTrue(thumbnailURL.path.contains("1024"), "Thumbnail should contain size in filename")
    }

    func testCacheHitReturnsExistingThumbnail() throws {
        // Given: Generate a thumbnail
        let firstURL = try thumbnailService.generateThumbnail(
            for: testImageFile,
            size: .small
        )

        // When: Requesting the same thumbnail again
        let secondURL = try thumbnailService.generateThumbnail(
            for: testImageFile,
            size: .small
        )

        // Then: Should return the same file (cache hit)
        XCTAssertEqual(firstURL.path, secondURL.path, "Should return cached thumbnail")
    }

    func testThumbnailStoredInCacheDirectory() throws {
        // When: Generating thumbnail
        let thumbnailURL = try thumbnailService.generateThumbnail(
            for: testImageFile,
            size: .small
        )

        // Then: Should be stored in cache directory
        XCTAssertTrue(thumbnailURL.path.hasPrefix(cacheDirectory.path), "Thumbnail should be in cache directory")
    }

    func testGenerateThumbnailForNonExistentFile() throws {
        // Given: Non-existent file
        let nonExistentFile = tempDirectory.appendingPathComponent("doesnotexist.jpg")

        // When/Then: Should throw error
        XCTAssertThrowsError(
            try thumbnailService.generateThumbnail(for: nonExistentFile, size: .small),
            "Should throw error for non-existent file"
        )
    }

    // MARK: - Helper

    private func createTestImage(at url: URL) throws {
        let size = CGSize(width: 100, height: 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "TestError", code: -1, userInfo: nil)
        }

        // Fill with red color
        context.setFillColor(CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))

        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "TestError", code: -1, userInfo: nil)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "TestError", code: -1, userInfo: nil)
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "TestError", code: -1, userInfo: nil)
        }

        try data.write(to: url)
    }

    // Linux test manifest not needed for Swift Package Manager on macOS.
}
