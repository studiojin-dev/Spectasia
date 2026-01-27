import Foundation
import SwiftUI
import AppKit
import os.log

// MARK: - Logging

private let logger = Logger(subsystem: "com.spectasia.gui", category: "PermissionManager")

/// Manager for file system permissions and security-scoped bookmarks
@MainActor
public class PermissionManager: ObservableObject {
    @Published public var grantedDirectories: Set<String> = []
    @Published public var permissionStatus: String = "No permissions granted"

    private let bookmarkKey = "securityScopedBookmarks"

    public init() {
        loadBookmarks()
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

        // Request security-scoped bookmark
        guard let bookmarkData = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]) else {
            logger.error("Failed to create bookmark for \(url.path)")
            return nil
        }

        // Save bookmark
        saveBookmark(url: url, data: bookmarkData)

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
            return securedURL.startAccessingSecurityScopedResource {
                block(securedURL)
                return true
            }

        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
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
            logger.error("Failed to encode bookmarks: \(error.localizedDescription)")
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
            logger.error("Failed to encode bookmarks after removal: \(error.localizedDescription)")
        }
    }

    private func loadAllBookmarks() -> [String: Data] {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: Data].self, from: data)
        } catch {
            logger.error("Failed to decode bookmarks, data may be corrupted: \(error.localizedDescription)")
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

/// Preferences view for managing folders
public struct FolderPreferencesView: View {
    @StateObject private var permissionManager = PermissionManager()
    @State private var monitoredFolders: [String] = []

    public init() {}

    public var body: some View {
        List {
            Section("Monitored Folders") {
                ForEach(monitoredFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text((folder as NSString).lastPathComponent)
                            .font(GypsumFont.body)
                        Spacer()
                        Button("Remove") {
                            removeFolder(folder)
                        }
                        .font(GypsumFont.caption)
                    }
                }

                Button("Add Folder") {
                    addFolder()
                }
                .font(GypsumFont.body)
            }

            Section("Permissions") {
                Text(permissionManager.permissionStatus)
                    .font(GypsumFont.caption)
                    .foregroundColor(GypsumColor.textSecondary)
            }
        }
        .navigationTitle("Folders")
    }

    private func addFolder() {
        if let url = permissionManager.requestDirectoryAccess(prompt: "Select image folder to monitor") {
            monitoredFolders.append(url.path)
        }
    }

    private func removeFolder(_ folder: String) {
        monitoredFolders.removeAll { $0 == folder }
    }
}

#Preview("Folder Preferences") {
    FolderPreferencesView()
        .frame(width: 400, height: 300)
}
