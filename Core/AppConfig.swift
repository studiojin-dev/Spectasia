import Foundation

/// Supported languages for the app
public enum AppLanguage: String, Codable {
    case english = "en"
    case korean = "ko"
}

/// Application configuration manager
/// Persists settings using UserDefaults
public struct AppConfig {
    // MARK: - Keys
    private enum Keys {
        static let cacheDirectory = "cacheDirectory"
        static let appLanguage = "appLanguage"
        static let autoAIToggle = "autoAIToggle"
    }

    // MARK: - Properties

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

    public init() {}

    // MARK: - Private Helpers

    private func defaultCacheDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDir = paths.first ?? "/tmp"
        return (cachesDir as NSString).appendingPathComponent("Spectasia")
    }
}
