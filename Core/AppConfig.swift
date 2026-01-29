import Foundation
import SwiftUI

/// Supported languages for the app
public enum AppLanguage: String, Codable {
    case english = "en"
    case korean = "ko"
}

/// Application configuration manager
/// Persists settings using UserDefaults
public class AppConfig: ObservableObject {
    // MARK: - Keys
    private enum Keys {
        static let cacheDirectory = "cacheDirectory"
        static let appLanguage = "appLanguage"
        static let autoAIToggle = "autoAIToggle"
    }

    // MARK: - Properties

    @Published public var cacheDirectoryPublished: String {
        didSet { UserDefaults.standard.set(cacheDirectoryPublished, forKey: Keys.cacheDirectory) }
    }
    @Published public var languagePublished: AppLanguage {
        didSet { UserDefaults.standard.set(languagePublished.rawValue, forKey: Keys.appLanguage) }
    }
    @Published public var isAutoAIEnabledPublished: Bool {
        didSet { UserDefaults.standard.set(isAutoAIEnabledPublished, forKey: Keys.autoAIToggle) }
    }

    /// Directory for caching thumbnails and metadata
    public var cacheDirectory: String {
        get {
            if let custom = UserDefaults.standard.string(forKey: Keys.cacheDirectory) {
                return custom
            }
            // Default: ~/Library/Caches/Spectasia
            return defaultCacheDirectory()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.cacheDirectory)
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

    // MARK: - Initialization

    public init() {
        // Initialize published values from persisted storage
        self.cacheDirectoryPublished = UserDefaults.standard.string(forKey: Keys.cacheDirectory) ?? defaultCacheDirectory()
        if let rawValue = UserDefaults.standard.string(forKey: Keys.appLanguage), let lang = AppLanguage(rawValue: rawValue) {
            self.languagePublished = lang
        } else {
            self.languagePublished = .english
        }
        self.isAutoAIEnabledPublished = UserDefaults.standard.bool(forKey: Keys.autoAIToggle)

        // Observe published changes and persist to UserDefaults
        // Note: Using didSet on published-backed properties to mirror to computed properties
        // will be implemented via property observers below.
    }

    // MARK: - Private Helpers

    private func defaultCacheDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDir = paths.first ?? "/tmp"
        return (cachesDir as NSString).appendingPathComponent("Spectasia")
    }
}

