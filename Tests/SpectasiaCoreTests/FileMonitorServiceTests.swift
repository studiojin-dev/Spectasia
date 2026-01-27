import XCTest
@testable import SpectasiaCore

final class FileMonitorServiceTests: XCTestCase {

    var tempDirectory: URL!
    var monitorService: FileMonitorService!

    override func setUpWithError() throws {
        // Create temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        monitorService = FileMonitorService()
    }

    override func tearDownWithError() throws {
        // Stop monitoring
        monitorService.stopMonitoring()

        // Reset callbacks to prevent interference between tests
        monitorService.onFileCreated = nil
        monitorService.onFileDeleted = nil
        monitorService.onFileModified = nil

        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testDetectsNewFile() throws {
        // Given: Monitoring temp directory
        let expectation = self.expectation(description: "File created event")
        var detectedFile: URL?

        monitorService.onFileCreated = { fileURL in
            detectedFile = fileURL
            expectation.fulfill()
        }

        try monitorService.startMonitoring(directory: tempDirectory.path)

        // When: Creating a new file
        let testFile = tempDirectory.appendingPathComponent("test.jpg")
        try Data().write(to: testFile)

        // Then: Should detect the new file
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(detectedFile, "Should detect new file")
        XCTAssertEqual(detectedFile?.path, testFile.path, "Should detect correct file")
    }

    func testDetectsDeletedFile() throws {
        // Given: A file exists and we're monitoring
        let expectation = self.expectation(description: "File deleted event")
        var deletedFile: URL?

        let testFile = tempDirectory.appendingPathComponent("test2.jpg")
        try Data().write(to: testFile)

        monitorService.onFileDeleted = { fileURL in
            deletedFile = fileURL
            expectation.fulfill()
        }

        try monitorService.startMonitoring(directory: tempDirectory.path)

        // When: Deleting the file
        try FileManager.default.removeItem(at: testFile)

        // Then: Should detect deletion
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(deletedFile, "Should detect deleted file")
        XCTAssertEqual(deletedFile?.path, testFile.path, "Should detect correct deleted file")
    }

    func testIgnoresNonImageFiles() throws {
        // Given: Monitoring temp directory
        var imageFileDetected = false
        let expectation = self.expectation(description: "Image file should be detected")

        monitorService.onFileCreated = { fileURL in
            // Only count if it's an image file (shouldn't trigger for .txt)
            if fileURL.pathExtension == "jpg" ||
               fileURL.pathExtension == "png" ||
               fileURL.pathExtension == "heic" ||
               fileURL.pathExtension == "jpeg" {
                imageFileDetected = true
                expectation.fulfill()
            }
        }

        try monitorService.startMonitoring(directory: tempDirectory.path)

        // When: Creating both image and non-image files
        let textFile = tempDirectory.appendingPathComponent("test.txt")
        let imageFile = tempDirectory.appendingPathComponent("test.jpg")
        try "text content".write(to: textFile, atomically: true, encoding: .utf8)
        try Data().write(to: imageFile)

        // Then: Should detect image file but not text file
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(imageFileDetected, "Should detect image files")
    }

    func testStopsMonitoring() throws {
        // Given: Monitoring directory
        var filesDetected: [URL] = []
        let expectation = self.expectation(description: "First file detected")

        monitorService.onFileCreated = { fileURL in
            filesDetected.append(fileURL)
            if filesDetected.count == 1 {
                expectation.fulfill()
            }
        }

        try monitorService.startMonitoring(directory: tempDirectory.path)

        // When: Creating a file while monitoring
        let testFile1 = tempDirectory.appendingPathComponent("test3.jpg")
        try Data().write(to: testFile1)

        wait(for: [expectation], timeout: 2.0)

        // Stop monitoring
        monitorService.stopMonitoring()

        // Then: Creating another file should not be detected
        let testFile2 = tempDirectory.appendingPathComponent("test4.jpg")
        try Data().write(to: testFile2)

        // Give it time to potentially detect (shouldn't)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertEqual(filesDetected.count, 1, "Should only detect files while monitoring")
        XCTAssertEqual(filesDetected.first?.path, testFile1.path, "Should detect correct file")
    }

    static let allTests = [
        ("testDetectsNewFile", testDetectsNewFile),
        ("testDetectsDeletedFile", testDetectsDeletedFile),
        ("testIgnoresNonImageFiles", testIgnoresNonImageFiles),
        ("testStopsMonitoring", testStopsMonitoring),
    ]
}
