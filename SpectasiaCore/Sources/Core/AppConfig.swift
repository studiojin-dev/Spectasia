import Foundation
import Combine
import SwiftUI

/// Supported languages for the app
public enum AppLanguage: String, Codable {
    case english = "en"
    case korean = "ko"
}

/// Application configuration manager
/// Persists settings using UserDefaults
@MainActor
@available(macOS 10.15, *)
public class AppConfig: ObservableObject {

    public struct DirectoryBookmark: Codable, Hashable {
        public let path: String
        public let data: Data

        public init(path: String, data: Data) {
            self.path = path
            self.data = data
        }
    }
    
    // MARK: - Keys
    private enum Keys {
        static let cacheDirectory = "cacheDirectory"
        static let metadataStoreDirectory = "metadataStoreDirectory"
        static let appLanguage = "appLanguage"
        static let autoAIToggle = "autoAIToggle"
        static let autoCleanupToggle = "autoCleanupToggle"
        static let cleanupRemoveMissingOriginals = "cleanupRemoveMissingOriginals"
        static let recentDirectoryBookmarks = "recentDirectoryBookmarks"
        static let favoriteDirectoryBookmarks = "favoriteDirectoryBookmarks"
    }

    // MARK: - Properties

    @Published public var cacheDirectoryPublished: String {
        didSet { UserDefaults.standard.set(cacheDirectoryPublished, forKey: Keys.cacheDirectory) }
    }
    @Published public var metadataStoreDirectoryPublished: String {
        didSet { UserDefaults.standard.set(metadataStoreDirectoryPublished, forKey: Keys.metadataStoreDirectory) }
    }
    @Published public var languagePublished: AppLanguage {
        didSet { UserDefaults.standard.set(languagePublished.rawValue, forKey: Keys.appLanguage) }
    }
    @Published public var isAutoAIEnabledPublished: Bool {
        didSet { UserDefaults.standard.set(isAutoAIEnabledPublished, forKey: Keys.autoAIToggle) }
    }
    @Published public var isAutoCleanupEnabledPublished: Bool {
        didSet { UserDefaults.standard.set(isAutoCleanupEnabledPublished, forKey: Keys.autoCleanupToggle) }
    }
    @Published public var cleanupRemoveMissingOriginalsPublished: Bool {
        didSet { UserDefaults.standard.set(cleanupRemoveMissingOriginalsPublished, forKey: Keys.cleanupRemoveMissingOriginals) }
    }
    @Published public var recentDirectoryBookmarks: [DirectoryBookmark] {
        didSet { persistDirectoryBookmarks(recentDirectoryBookmarks, key: Keys.recentDirectoryBookmarks) }
    }
    @Published public var favoriteDirectoryBookmarks: [DirectoryBookmark] {
        didSet { persistDirectoryBookmarks(favoriteDirectoryBookmarks, key: Keys.favoriteDirectoryBookmarks) }
    }

    /// Directory for caching thumbnails and metadata
    public var cacheDirectory: String {
        get {
            if let custom = UserDefaults.standard.string(forKey: Keys.cacheDirectory) {
                return custom
            }
            // Default: ~/Library/Caches/Spectasia
            return Self.defaultCacheDirectory()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.cacheDirectory)
        }
    }

    /// Directory for XMP + thumbnail storage
    public var metadataStoreDirectory: String {
        get {
            if let custom = UserDefaults.standard.string(forKey: Keys.metadataStoreDirectory) {
                return custom
            }
            return Self.defaultMetadataStoreDirectory()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.metadataStoreDirectory)
        }
    }

    /// Current app language
    public var language: AppLanguage {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.appLanguage),
               let language = AppLanguage(rawValue: rawValue) {
                return language
            }
            return .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.appLanguage)
        }
    }

    /// Whether AI analysis runs automatically
    public var isAutoAIEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.autoAIToggle)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoAIToggle)
        }
    }

    /// Whether metadata cleanup runs automatically on launch
    public var isAutoCleanupEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.autoCleanupToggle)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoCleanupToggle)
        }
    }

    /// Whether cleanup removes entries for missing original files
    public var cleanupRemoveMissingOriginals: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.cleanupRemoveMissingOriginals) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.cleanupRemoveMissingOriginals)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.cleanupRemoveMissingOriginals)
        }
    }

    // MARK: - Initialization

    public init() {
        // Initialize published values from persisted storage
        self.cacheDirectoryPublished = UserDefaults.standard.string(forKey: Keys.cacheDirectory) ?? Self.defaultCacheDirectory()
        self.metadataStoreDirectoryPublished = UserDefaults.standard.string(forKey: Keys.metadataStoreDirectory) ?? Self.defaultMetadataStoreDirectory()
        if let rawValue = UserDefaults.standard.string(forKey: Keys.appLanguage), let lang = AppLanguage(rawValue: rawValue) {
            self.languagePublished = lang
        } else {
            self.languagePublished = .english
        }
        self.isAutoAIEnabledPublished = UserDefaults.standard.bool(forKey: Keys.autoAIToggle)
        self.isAutoCleanupEnabledPublished = UserDefaults.standard.bool(forKey: Keys.autoCleanupToggle)
        if UserDefaults.standard.object(forKey: Keys.cleanupRemoveMissingOriginals) == nil {
            self.cleanupRemoveMissingOriginalsPublished = true
        } else {
            self.cleanupRemoveMissingOriginalsPublished = UserDefaults.standard.bool(forKey: Keys.cleanupRemoveMissingOriginals)
        }
        self.recentDirectoryBookmarks = Self.loadDirectoryBookmarks(key: Keys.recentDirectoryBookmarks)
        self.favoriteDirectoryBookmarks = Self.loadDirectoryBookmarks(key: Keys.favoriteDirectoryBookmarks)
    }

    // MARK: - Recent/Favorites

    public func addRecentDirectory(_ bookmark: DirectoryBookmark, maxCount: Int = 10) {
        var updated = recentDirectoryBookmarks.filter { $0.path != bookmark.path }
        updated.insert(bookmark, at: 0)
        if updated.count > maxCount {
            updated = Array(updated.prefix(maxCount))
        }
        recentDirectoryBookmarks = updated
    }

    public func toggleFavoriteDirectory(_ bookmark: DirectoryBookmark) {
        if favoriteDirectoryBookmarks.contains(where: { $0.path == bookmark.path }) {
            favoriteDirectoryBookmarks.removeAll { $0.path == bookmark.path }
        } else {
            favoriteDirectoryBookmarks.append(bookmark)
        }
        favoriteDirectoryBookmarks.sort { $0.path < $1.path }
    }

    public func isFavoriteDirectory(_ path: String) -> Bool {
        return favoriteDirectoryBookmarks.contains(where: { $0.path == path })
    }

    public func removeRecentDirectory(path: String) {
        recentDirectoryBookmarks.removeAll { $0.path == path }
    }

    public func removeFavoriteDirectory(path: String) {
        favoriteDirectoryBookmarks.removeAll { $0.path == path }
    }

    public func bookmarkData(for path: String) -> Data? {
        if let match = recentDirectoryBookmarks.first(where: { $0.path == path }) {
            return match.data
        }
        if let match = favoriteDirectoryBookmarks.first(where: { $0.path == path }) {
            return match.data
        }
        return nil
    }

    // MARK: - Persistence

    private func persistDirectoryBookmarks(_ bookmarks: [DirectoryBookmark], key: String) {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            CoreLog.error("Failed to encode directory bookmarks: \(error.localizedDescription)", category: "AppConfig")
        }
    }

    private static func loadDirectoryBookmarks(key: String) -> [DirectoryBookmark] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([DirectoryBookmark].self, from: data)
        } catch {
            CoreLog.error("Failed to decode directory bookmarks: \(error.localizedDescription)", category: "AppConfig")
            return []
        }
    }

    // MARK: - Private Helpers

    private static func defaultCacheDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDir = paths.first ?? "/tmp"
        return (cachesDir as NSString).appendingPathComponent("Spectasia")
    }

    private static func defaultMetadataStoreDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let appSupportDir = paths.first ?? "/tmp"
        return (appSupportDir as NSString).appendingPathComponent("Spectasia/Metadata")
    }
}
