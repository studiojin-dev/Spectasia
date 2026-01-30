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

    @EnvironmentObject var repository: ObservableImageRepository
    @EnvironmentObject var permissionManager: PermissionManager

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
        .onChange(of: selectedDirectory) { _, newValue in
            guard let url = newValue else { return }
            Task {
                await loadDirectory(url)
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
        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.loadDirectory(url)
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
