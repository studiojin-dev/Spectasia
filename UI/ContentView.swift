//
//  ContentView.swift
//  Spectasia
//
//  Main view for Spectasia image viewer
//  Connects Core services with UI components

import SwiftUI

/// Main view for Spectasia image viewer
struct ContentView: View {
    @State private var selectedImage: SpectasiaImage? = nil
    @State private var selectedDirectory: URL? = nil
    @State private var backgroundTasks: Int = 0
    @State private var currentViewMode: SpectasiaLayout.ViewMode = .thumbnailGrid
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    @EnvironmentObject var repository: ObservableImageRepository

    var body: some View {
        SpectasiaLayout(
            images: $repository.images,
            selectedImage: $selectedImage,
            selectedDirectory: $selectedDirectory,
            currentViewMode: $currentViewMode,
            isLoading: $isLoading,
            backgroundTasks: $backgroundTasks
        )
        .onAppear {
            requestInitialDirectoryAccess()
        }
        .task {
            await loadImages()
        }
    }

    private func requestInitialDirectoryAccess() {
        if repository.images.isEmpty {
            let permissionManager = PermissionManager()
            permissionManager.requestDirectoryAccess()
        }
    }

    private func loadImages() async {
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
