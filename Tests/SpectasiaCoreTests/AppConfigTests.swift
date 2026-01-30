import XCTest
@testable import SpectasiaCore

final class AppConfigTests: XCTestCase {

    override func setUpWithError() throws {
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "cacheDirectory")
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "autoAIToggle")
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: "cacheDirectory")
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "autoAIToggle")
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

    static let allTests = [
        ("testDefaultCacheDirectory", testDefaultCacheDirectory),
        ("testCacheDirectoryPersists", testCacheDirectoryPersists),
        ("testDefaultLanguage", testDefaultLanguage),
        ("testLanguagePersists", testLanguagePersists),
        ("testDefaultAutoAI", testDefaultAutoAI),
        ("testAutoAIPersists", testAutoAIPersists),
    ]
}
