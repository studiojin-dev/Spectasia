import Foundation
import Combine
import AppKit
import Security
// MARK: - Logging

private let logCategory = "PermissionManager"

/// Manager for file system permissions and security-scoped bookmarks
@MainActor
@available(macOS 10.15, *)
public class PermissionManager: ObservableObject {
    @Published public var grantedDirectories: Set<String> = []
    @Published public var permissionStatus: String = "No permissions granted"

    private let bookmarkKey = "securityScopedBookmarks"

    public init() {
        loadBookmarks()
    }

    // MARK: - Bookmark Helpers

    public func storeBookmark(for url: URL) -> Data? {
        guard let bookmarkData = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]) else {
            CoreLog.error("Failed to create bookmark for \(url.path)", category: logCategory)
            return nil
        }
        saveBookmark(url: url, data: bookmarkData)
        grantedDirectories.insert(url.path)
        return bookmarkData
    }

    public func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                CoreLog.warning("Bookmark is stale for \(url.path)", category: logCategory)
            }
            return url
        } catch {
            CoreLog.error("Failed to resolve bookmark: \(error.localizedDescription)", category: logCategory)
            return nil
        }
    }

    /// Request permission to access a directory
    public func requestDirectoryAccess(prompt: String = "Select a folder to monitor") -> URL? {
        let panel = NSOpenPanel()
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return nil
        }

        guard storeBookmark(for: url) != nil else {
            return nil
        }

        // Add to granted directories
        grantedDirectories.insert(url.path)
        permissionStatus = "Access granted to \(url.lastPathComponent)"

        return url
    }

    /// Access directory with security scope
    public func accessDirectory(_ url: URL, block: (URL) -> Void) -> Bool {
        var isStale = false

        // Resolve bookmark to get security-scoped URL
        guard let bookmarkData = loadBookmark(for: url) else {
            return false
        }

        var bookmarkedURL: URL?
        do {
            bookmarkedURL = try URL(resolvingBookmarkData: bookmarkData,
                                                options: .withSecurityScope,
                                                relativeTo: nil,
                                                bookmarkDataIsStale: &isStale)

            if isStale {
                // Bookmark is stale, remove it
                removeBookmark(for: url)
                grantedDirectories.remove(url.path)
                return false
            }

            guard let securedURL = bookmarkedURL else {
                return false
            }

            // Access directory with security scope
            if securedURL.startAccessingSecurityScopedResource() {
                block(securedURL)
                return true
            }
            return false

        } catch {
            CoreLog.error("Failed to resolve bookmark: \(error.localizedDescription)", category: logCategory)
            return false
        }
    }

    /// Check if we have permission to access a directory
    public func hasAccess(to url: URL) -> Bool {
        return grantedDirectories.contains(url.path)
    }

    // MARK: - Private Helpers

    private func saveBookmark(url: URL, data: Data) {
        var bookmarks = loadAllBookmarks()
        bookmarks[url.path] = data

        do {
            let encoded = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(encoded, forKey: bookmarkKey)
        } catch {
            CoreLog.error("Failed to encode bookmarks: \(error.localizedDescription)", category: logCategory)
        }
    }

    private func loadBookmark(for url: URL) -> Data? {
        let bookmarks = loadAllBookmarks()
        return bookmarks[url.path]
    }

    private func removeBookmark(for url: URL) {
        var bookmarks = loadAllBookmarks()
        bookmarks.removeValue(forKey: url.path)

        do {
            let encoded = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(encoded, forKey: bookmarkKey)
        } catch {
            CoreLog.error("Failed to encode bookmarks after removal: \(error.localizedDescription)", category: logCategory)
        }
    }

    private func loadAllBookmarks() -> [String: Data] {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: Data].self, from: data)
        } catch {
            CoreLog.error("Failed to decode bookmarks, data may be corrupted: \(error.localizedDescription)", category: logCategory)
            // Clear corrupted data to prevent repeated errors
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return [:]
        }
    }

    private func loadBookmarks() {
        let bookmarks = loadAllBookmarks()
        grantedDirectories = Set(bookmarks.keys)
        permissionStatus = bookmarks.isEmpty ? "No permissions granted" : "\(bookmarks.count) folders accessible"
    }
}
