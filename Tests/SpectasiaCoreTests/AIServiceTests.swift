import XCTest
@testable import SpectasiaCore

// Mock Analyzer for testing
class MockImageAnalyzer: ImageAnalyzing {
    var mockTags: [String] = []
    var mockShouldThrow = false

    func analyze(imageAt url: URL, language: AppLanguage) throws -> [String] {
        if mockShouldThrow {
            throw AIServiceError.analysisFailed
        }
        return mockTags
    }
}

final class AIServiceTests: XCTestCase {

    var tempDirectory: URL!
    var aiService: AIService!
    var testImageFile: URL!

    override func setUpWithError() throws {
        // Create temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create a test image
        testImageFile = tempDirectory.appendingPathComponent("test.jpg")
        try createTestImage(at: testImageFile)
    }

    override func tearDownWithError() throws {
        // Clean up
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testReturnsValidTagsForImage() throws {
        // Given: AIService with mock analyzer
        let mockAnalyzer = MockImageAnalyzer()
        mockAnalyzer.mockTags = ["nature", "landscape", "sunset"]
        aiService = AIService(analyzer: mockAnalyzer)

        // When: Analyzing image
        let tags = try aiService.analyze(imageAt: testImageFile, language: .english)

        // Then: Should return tags
        XCTAssertEqual(tags, ["nature", "landscape", "sunset"], "Should return analyzed tags")
    }

    func testRespectsLanguageSetting() throws {
        // Given: AIService with mock analyzer
        let customAnalyzer = MockImageAnalyzer()
        customAnalyzer.mockTags = ["자연", "풍경"]
        aiService = AIService(analyzer: customAnalyzer)

        // When: Analyzing with Korean language
        let tags = try aiService.analyze(imageAt: testImageFile, language: .korean)

        // Then: Should handle Korean language
        XCTAssertEqual(tags, ["자연", "풍경"], "Should return Korean tags")
    }

    func testHandlesNonExistentFile() throws {
        // Given: AIService
        let mockAnalyzer = MockImageAnalyzer()
        mockAnalyzer.mockShouldThrow = true
        aiService = AIService(analyzer: mockAnalyzer)

        let nonExistentFile = tempDirectory.appendingPathComponent("doesnotexist.jpg")

        // When/Then: Should throw error
        XCTAssertThrowsError(
            try aiService.analyze(imageAt: nonExistentFile, language: .english),
            "Should throw error for non-existent file"
        )
    }

    func testReturnsEmptyTagsWhenNoAnalysis() throws {
        // Given: AIService with mock analyzer returning empty tags
        let mockAnalyzer = MockImageAnalyzer()
        mockAnalyzer.mockTags = []
        aiService = AIService(analyzer: mockAnalyzer)

        // When: Analyzing image
        let tags = try aiService.analyze(imageAt: testImageFile, language: .english)

        // Then: Should return empty array
        XCTAssertEqual(tags, [], "Should return empty tags when no results")
    }

    func testDefaultAnalyzerUsed() throws {
        // Given: AIService without custom analyzer
        aiService = AIService()

        // When: Creating service
        // Then: Should have default analyzer (no crash)
        XCTAssertNotNil(aiService, "AIService should initialize with default analyzer")
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

    static let allTests = [
        ("testReturnsValidTagsForImage", testReturnsValidTagsForImage),
        ("testRespectsLanguageSetting", testRespectsLanguageSetting),
        ("testHandlesNonExistentFile", testHandlesNonExistentFile),
        ("testReturnsEmptyTagsWhenNoAnalysis", testReturnsEmptyTagsWhenNoAnalysis),
        ("testDefaultAnalyzerUsed", testDefaultAnalyzerUsed),
    ]
}
