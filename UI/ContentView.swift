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
        .task {
            await loadImages()
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

    private func requestInitialDirectoryAccess() {
        if repository.images.isEmpty {
            if let url = permissionManager.requestDirectoryAccess() {
                selectedDirectory = url
            }
        }
    }

    private func loadDirectory(_ url: URL) async {
        await loadDirectory(url, monitor: isMonitoring)
    }

    private func loadDirectory(_ url: URL, monitor: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.loadDirectory(url, monitor: monitor)
            if let data = permissionManager.storeBookmark(for: url) {
                let bookmark = AppConfig.DirectoryBookmark(path: url.path, data: data)
                await MainActor.run {
                    appConfig.addRecentDirectory(bookmark)
                }
            }
        } catch {
            errorMessage = "Failed to load directory: \(url.path)"
            CoreLog.error("Failed to load directory \(url.path): \(error.localizedDescription)", category: "ContentView")
        }
    }

    private func loadImages() async {
        guard selectedDirectory == nil else { return }
        isLoading = true
        defer { isLoading = false }

        let loadedImages = [
            SpectasiaImage(
                url: URL(fileURLWithPath: "/tmp/test1.jpg"),
                metadata: ImageMetadata(
                    rating: 4,
                    tags: ["nature", "landscape"],
                    fileSize: 1024000,
                    modificationDate: Date(),
                    fileExtension: "jpg"
                )
            ),
            SpectasiaImage(
                url: URL(fileURLWithPath: "/tmp/test2.jpg"),
                metadata: ImageMetadata(
                    rating: 3,
                    tags: ["portrait", "people"],
                    fileSize: 2048000,
                    modificationDate: Date().addingTimeInterval(-86400),
                    fileExtension: "jpg"
                )
            )
        ]

        let fetchedImages = repository.images
        let allImages = fetchedImages.isEmpty ? loadedImages : fetchedImages

        await MainActor.run {
            repository.updateImages(allImages)
        }
    }
}

#Preview {
    ContentView()
}
