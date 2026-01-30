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

    @EnvironmentObject var repository: ObservableImageRepository
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var appConfig: AppConfig

    var body: some View {
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
            _ = try await permissionManager.withAccess(to: url) { securedURL in
                try await repository.loadDirectory(securedURL, monitor: monitor)
            }
            let bookmark = AppConfig.DirectoryBookmark(path: url.path, data: data)
            appConfig.addRecentDirectory(bookmark)
        } catch {
            errorMessage = "Failed to load directory: \(url.path)"
            CoreLog.error("Failed to load directory \(url.path): \(error.localizedDescription)", category: "ContentView")
        }
    }
}

#Preview {
    ContentView()
}
