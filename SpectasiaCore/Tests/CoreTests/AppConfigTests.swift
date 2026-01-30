import XCTest
@testable import SpectasiaCore

@MainActor
final class AppConfigTests: XCTestCase {

    override func setUpWithError() throws {
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "cacheDirectory")
        UserDefaults.standard.removeObject(forKey: "metadataStoreDirectory")
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "autoAIToggle")
        UserDefaults.standard.removeObject(forKey: "recentDirectoryBookmarks")
        UserDefaults.standard.removeObject(forKey: "favoriteDirectoryBookmarks")
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: "cacheDirectory")
        UserDefaults.standard.removeObject(forKey: "metadataStoreDirectory")
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "autoAIToggle")
        UserDefaults.standard.removeObject(forKey: "recentDirectoryBookmarks")
        UserDefaults.standard.removeObject(forKey: "favoriteDirectoryBookmarks")
    }

    func testDefaultCacheDirectory() throws {
        // Given: No cache directory set
        let config = AppConfig()

        // Then: Should default to a reasonable path
        let defaultPath = config.cacheDirectory
        XCTAssertTrue(defaultPath.contains("Caches"), "Default cache directory should contain 'Caches'")
        XCTAssertTrue(defaultPath.contains("Spectasia"), "Default cache directory should contain 'Spectasia'")
    }

    func testCacheDirectoryPersists() throws {
        // Given: A custom cache directory
        let customPath = "/Volumes/External/MyCache"

        // When: Setting cache directory
        let config = AppConfig()
        config.cacheDirectory = customPath

        // Then: Should persist across instances
        let newConfig = AppConfig()
        XCTAssertEqual(newConfig.cacheDirectory, customPath, "Cache directory should persist")
    }

    func testDefaultMetadataStoreDirectory() throws {
        let config = AppConfig()
        let defaultPath = config.metadataStoreDirectory
        XCTAssertTrue(defaultPath.contains("Application Support"), "Default metadata store should use Application Support")
        XCTAssertTrue(defaultPath.contains("Spectasia"), "Default metadata store should contain 'Spectasia'")
    }

    func testMetadataStoreDirectoryPersists() throws {
        let customPath = "/Volumes/External/MetadataStore"
        let config = AppConfig()
        config.metadataStoreDirectory = customPath
        let newConfig = AppConfig()
        XCTAssertEqual(newConfig.metadataStoreDirectory, customPath, "Metadata store directory should persist")
    }

    func testDefaultLanguage() throws {
        // Given: No language set
        let config = AppConfig()

        // Then: Should default to English
        XCTAssertEqual(config.language, .english, "Default language should be English")
    }

    func testLanguagePersists() throws {
        // Given: Set language to Korean
        let config = AppConfig()
        config.language = .korean

        // When: Creating new instance
        let newConfig = AppConfig()

        // Then: Language should be Korean
        XCTAssertEqual(newConfig.language, .korean, "Language should persist")
    }

    func testDefaultAutoAI() throws {
        // Given: No setting
        let config = AppConfig()

        // Then: Should default to false
        XCTAssertFalse(config.isAutoAIEnabled, "Auto AI should default to false")
    }

    func testAutoAIPersists() throws {
        // Given: Enable auto AI
        let config = AppConfig()
        config.isAutoAIEnabled = true

        // When: Creating new instance
        let newConfig = AppConfig()

        // Then: Should be enabled
        XCTAssertTrue(newConfig.isAutoAIEnabled, "Auto AI toggle should persist")
    }

    func testRecentDirectoriesPersist() throws {
        // Given: Recent directories
        let config = AppConfig()
        let first = AppConfig.DirectoryBookmark(path: "/tmp/a", data: Data([1, 2, 3]))
        let second = AppConfig.DirectoryBookmark(path: "/tmp/b", data: Data([4, 5, 6]))
        config.addRecentDirectory(first)
        config.addRecentDirectory(second)

        // When: Creating new instance
        let newConfig = AppConfig()

        // Then: Should load the same order
        XCTAssertEqual(newConfig.recentDirectoryBookmarks.count, 2)
        XCTAssertEqual(newConfig.recentDirectoryBookmarks.first?.path, "/tmp/b")
    }

    func testRecentDirectoriesMaxCount() throws {
        // Given: More than maxCount
        let config = AppConfig()
        for index in 0..<12 {
            let bookmark = AppConfig.DirectoryBookmark(path: "/tmp/\(index)", data: Data([UInt8(index)]))
            config.addRecentDirectory(bookmark, maxCount: 10)
        }

        // Then: Should be capped
        XCTAssertEqual(config.recentDirectoryBookmarks.count, 10)
        XCTAssertEqual(config.recentDirectoryBookmarks.first?.path, "/tmp/11")
    }

    func testToggleFavoriteDirectory() throws {
        // Given: A bookmark
        let config = AppConfig()
        let bookmark = AppConfig.DirectoryBookmark(path: "/tmp/fav", data: Data([9, 9, 9]))

        // When: Toggling on
        config.toggleFavoriteDirectory(bookmark)
        XCTAssertTrue(config.isFavoriteDirectory(bookmark.path))

        // When: Toggling off
        config.toggleFavoriteDirectory(bookmark)
        XCTAssertFalse(config.isFavoriteDirectory(bookmark.path))
    }

    // Linux test manifest not needed for Swift Package Manager on macOS.
}
