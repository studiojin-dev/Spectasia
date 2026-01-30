//
//  ContentView.swift
//  Spectasia
//
//  Main view for Spectasia image viewer
//  Connects Core services with UI components

import SwiftUI
import SpectasiaCore

/// Main view for Spectasia image viewer
struct ContentView: View {
    @State private var selectedImage: SpectasiaImage? = nil
    @State private var selectedDirectory: URL? = nil
    @State private var backgroundTasks: Int = 0
    @State private var currentViewMode: SpectasiaLayout.ViewMode = .thumbnailGrid
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isMonitoring: Bool = true
    @State private var accessToken: SecurityScopeToken? = nil
    @State private var didRunStartupCleanup = false

    @EnvironmentObject var repository: ObservableImageRepository
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject var toastCenter: ToastCenter

    var body: some View {
        ZStack(alignment: .bottom) {
            SpectasiaLayout(
                images: $repository.images,
                selectedImage: $selectedImage,
                selectedDirectory: $selectedDirectory,
                currentViewMode: $currentViewMode,
                isLoading: $isLoading,
                backgroundTasks: $backgroundTasks,
                isMonitoring: $isMonitoring,
                recentDirectories: $appConfig.recentDirectoryBookmarks,
                favoriteDirectories: $appConfig.favoriteDirectoryBookmarks,
                onSelectDirectory: { bookmark in
                    if let url = permissionManager.resolveBookmark(bookmark.data) {
                        selectedDirectory = url
                    } else {
                        errorMessage = "Unable to access saved folder."
                        appConfig.removeRecentDirectory(path: bookmark.path)
                        appConfig.removeFavoriteDirectory(path: bookmark.path)
                    }
                },
                onToggleFavorite: { url in
                    guard let data = permissionManager.storeBookmark(for: url) else {
                        errorMessage = "Failed to save folder permission."
                        return
                    }
                    let bookmark = AppConfig.DirectoryBookmark(path: url.path, data: data)
                    appConfig.toggleFavoriteDirectory(bookmark)
                }
            )
            .onAppear {
                requestInitialDirectoryAccess()
                runStartupCleanupIfNeeded()
            }
            .onChange(of: appConfig.isAutoCleanupEnabledPublished) { _, _ in
                runStartupCleanupIfNeeded()
            }
            .onChange(of: selectedDirectory) { _, newValue in
                guard let url = newValue else { return }
                Task {
                    await loadDirectory(url)
                }
            }
            .onChange(of: isMonitoring) { _, newValue in
                guard let url = selectedDirectory else { return }
                Task {
                    await loadDirectory(url, monitor: newValue)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }

            if let message = toastCenter.message {
                Text(message)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
    }

    @MainActor
    private func requestInitialDirectoryAccess() {
        if repository.images.isEmpty {
            if let url = permissionManager.requestDirectoryAccess() {
                selectedDirectory = url
            }
        }
    }

    @MainActor
    private func loadDirectory(_ url: URL) async {
        await loadDirectory(url, monitor: isMonitoring)
    }

    @MainActor
    private func loadDirectory(_ url: URL, monitor: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let data = permissionManager.storeBookmark(for: url) else {
                errorMessage = "Failed to save folder permission."
                return
            }
            if monitor {
                accessToken = nil
                accessToken = permissionManager.beginAccess(to: url)
                guard let token = accessToken else {
                    errorMessage = "Failed to access folder."
                    return
                }
                try await repository.loadDirectory(token.url, monitor: monitor)
            } else {
                accessToken = nil
                _ = try await permissionManager.withAccess(to: url) { securedURL in
                    try await repository.loadDirectory(securedURL, monitor: monitor)
                }
            }
            let bookmark = AppConfig.DirectoryBookmark(path: url.path, data: data)
            appConfig.addRecentDirectory(bookmark)
        } catch {
            errorMessage = "Failed to load directory: \(url.path)"
            CoreLog.error("Failed to load directory \(url.path): \(error.localizedDescription)", category: "ContentView")
        }
    }

    private func runStartupCleanupIfNeeded() {
        guard appConfig.isAutoCleanupEnabledPublished, !didRunStartupCleanup else { return }
        didRunStartupCleanup = true
        Task { [metadataStoreManager, toastCenter] in
            let result = await metadataStoreManager.store.cleanupMissingFiles(removeMissingOriginals: appConfig.cleanupRemoveMissingOriginalsPublished)
            if result.removedRecords > 0 || result.removedFiles > 0 {
                let message = String(
                    format: NSLocalizedString("Cleaned metadata: %lld records, %lld files", comment: "Cleanup summary"),
                    result.removedRecords,
                    result.removedFiles
                )
                toastCenter.show(message)
            }
        }
    }
}

#Preview {
    ContentView()
}
