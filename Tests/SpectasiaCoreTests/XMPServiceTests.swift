import XCTest
@testable import SpectasiaCore

final class XMPServiceTests: XCTestCase {

    var tempDirectory: URL!
    var xmpService: XMPService!
    var testImageFile: URL!
    var originalFileHash: String!

    override func setUpWithError() throws {
        // Create temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        xmpService = XMPService()

        // Create a dummy image file (1x1 pixel JPEG)
        testImageFile = tempDirectory.appendingPathComponent("test.jpg")
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0x37, 0xFF, 0xD9])
        try jpegData.write(to: testImageFile)

        // Calculate original file hash
        originalFileHash = calculateFileHash(testImageFile)
    }

    override func tearDownWithError() throws {
        // Clean up
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testSidecarCreatedWhenMissing() throws {
        // Given: An image file without XMP sidecar
        let sidecarURL = testImageFile.deletingPathExtension().appendingPathExtension("xmp")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecarURL.path), "Sidecar should not exist initially")

        // When: Writing metadata
        try xmpService.writeRating(url: testImageFile, rating: 4)

        // Then: Sidecar should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecarURL.path), "Sidecar should be created")
    }

    func testWriteAndReadRating() throws {
        // Given: An image file
        let rating = 5

        // When: Writing rating
        try xmpService.writeRating(url: testImageFile, rating: rating)

        // Then: Should read back the same rating
        let metadata = try xmpService.readMetadata(url: testImageFile)
        XCTAssertEqual(metadata.rating, rating, "Rating should match")
    }

    func testWriteAndReadTags() throws {
        // Given: An image file
        let tags = ["nature", "landscape", "sunset"]

        // When: Writing tags
        try xmpService.writeTags(url: testImageFile, tags: tags)

        // Then: Should read back the same tags
        let metadata = try xmpService.readMetadata(url: testImageFile)
        XCTAssertEqual(Set(metadata.tags), Set(tags), "Tags should match")
    }

    func testOriginalFileNotModified() throws {
        // Given: Original file hash
        let originalModDate = try FileManager.default.attributesOfItem(atPath: testImageFile.path)[.modificationDate] as! Date

        // When: Writing metadata
        try xmpService.writeRating(url: testImageFile, rating: 3)
        try xmpService.writeTags(url: testImageFile, tags: ["test"])

        // Then: Original file hash should be unchanged
        let newHash = calculateFileHash(testImageFile)
        XCTAssertEqual(newHash, originalFileHash, "Original file should not be modified")

        // And: Modification date should be unchanged
        let newModDate = try FileManager.default.attributesOfItem(atPath: testImageFile.path)[.modificationDate] as! Date
        XCTAssertEqual(newModDate, originalModDate, "Original file modification date should not change")
    }

    func testMetadataPersistsAcrossInstances() throws {
        // Given: Write metadata with one service instance
        try xmpService.writeRating(url: testImageFile, rating: 5)
        try xmpService.writeTags(url: testImageFile, tags: ["persistent"])

        // When: Creating new service instance
        let newService = XMPService()
        let metadata = try newService.readMetadata(url: testImageFile)

        // Then: Should read the written metadata
        XCTAssertEqual(metadata.rating, 5, "Rating should persist")
        XCTAssertEqual(metadata.tags, ["persistent"], "Tags should persist")
    }

    func testReadMetadataFromNonExistentFile() throws {
        // Given: Non-existent file
        let nonExistentFile = tempDirectory.appendingPathComponent("doesnotexist.jpg")

        // When/Then: Should throw error
        XCTAssertThrowsError(try xmpService.readMetadata(url: nonExistentFile), "Should throw error for non-existent file")
    }

    // MARK: - Helper

    private func calculateFileHash(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        return data.map { String(format: "%02x", $0) }.joined()
    }

    static let allTests = [
        ("testSidecarCreatedWhenMissing", testSidecarCreatedWhenMissing),
        ("testWriteAndReadRating", testWriteAndReadRating),
        ("testWriteAndReadTags", testWriteAndReadTags),
        ("testOriginalFileNotModified", testOriginalFileNotModified),
        ("testMetadataPersistsAcrossInstances", testMetadataPersistsAcrossInstances),
        ("testReadMetadataFromNonExistentFile", testReadMetadataFromNonExistentFile),
    ]
}
