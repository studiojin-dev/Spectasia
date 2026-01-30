import XCTest
@testable import SpectasiaCore

@MainActor
final class PermissionManagerTests: XCTestCase {

    override func setUpWithError() throws {
        UserDefaults.standard.removeObject(forKey: "securityScopedBookmarks")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "securityScopedBookmarks")
    }

    func testResolveBookmarkWithInvalidDataReturnsNil() throws {
        let manager = PermissionManager()
        let invalidData = Data([0x00, 0x01, 0x02])
        let resolved = manager.resolveBookmark(invalidData)
        XCTAssertNil(resolved, "Invalid bookmark data should return nil")
    }

    func testStoreAndResolveBookmarkForDirectory() throws {
        let manager = PermissionManager()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        guard let data = manager.storeBookmark(for: tempDir) else {
            XCTFail("Failed to create bookmark data")
            return
        }

        let resolved = manager.resolveBookmark(data)
        let resolvedPath = resolved?.resolvingSymlinksInPath().path
        let originalPath = tempDir.resolvingSymlinksInPath().path
        XCTAssertEqual(resolvedPath, originalPath, "Resolved URL should match original path")
    }
}
