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
    @State private var selectedImageID: String? = nil
    @State private var selectedDirectory: URL? = nil
    @State private var backgroundTasks: Int = 0
    @State private var currentViewMode: SpectasiaLayout.ViewMode = .thumbnailGrid
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var accessToken: SecurityScopeToken? = nil
    @State private var didRunStartupCleanup = false

    @EnvironmentObject var repository: ObservableImageRepository
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject var toastCenter: ToastCenter
    @EnvironmentObject var directoryScanManager: DirectoryScanManager

    private var selectedImage: SpectasiaImage? {
        repository.images.first { $0.id == selectedImageID }
    }

    private var selectedImageBinding: Binding<SpectasiaImage?> {
        Binding(
            get: { repository.images.first(where: { $0.id == selectedImageID }) },
            set: { newValue in
                selectedImageID = newValue?.id
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SpectasiaLayout(
                images: $repository.images,
                selectedImage: selectedImageBinding,
                selectedDirectory: $selectedDirectory,
                currentViewMode: $currentViewMode,
                isLoading: $isLoading,
                backgroundTasks: $backgroundTasks,
                onSelectDirectory: { bookmark in
                    if let url = permissionManager.resolveBookmark(bookmark.data) {
                        selectedDirectory = url
                    } else {
                        errorMessage = "Unable to access saved folder."
                        appConfig.removeRecentDirectory(path: bookmark.path)
                        appConfig.removeFavoriteDirectory(path: bookmark.path)
                    }
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
            .onChange(of: repository.images.map(\.id)) { _, _ in
                alignSelectedImage(with: repository.images)
            }
            .onChange(of: directoryScanManager.scanCompletionMessage) { _, message in
                if let message {
                    toastCenter.show(message)
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

            if let status = toastCenter.statusMessage {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .padding(.bottom, 52)
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
        isLoading = true
        defer { isLoading = false }

        do {
            guard let data = permissionManager.storeBookmark(for: url) else {
                errorMessage = "Failed to save folder permission."
                return
            }
            accessToken = nil
            accessToken = permissionManager.beginAccess(to: url)
            guard let token = accessToken else {
                errorMessage = "Failed to access folder."
                return
            }
            try await repository.loadDirectory(token.url, monitor: true)
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
        // Capture current settings on the main actor before doing background work
        let excludedPaths = appConfig.cleanupExcludedPathsPublished
        let removeMissing = appConfig.cleanupRemoveMissingOriginalsPublished

        // Perform cleanup work off the main actor while keeping UI updates on the main actor
        let capturedExcludedPaths = excludedPaths
        let capturedRemoveMissing = removeMissing

        Task { [capturedExcludedPaths, capturedRemoveMissing] in
            // We are on the main actor when called from SwiftUI lifecycle; perform initial UI updates directly
            await repository.startActivity(message: NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))
            toastCenter.setStatus(NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))

            // Run the cleanup asynchronously
            let result = await metadataStoreManager.store.cleanupMissingFiles(
                removeMissingOriginals: capturedRemoveMissing,
                isOriginalSafeToRemove: { (url: URL) -> Bool in
                    // Only capture immutable value types from this context
                    !capturedExcludedPaths.contains(where: { path in url.path.hasPrefix(path) })
                }
            )

            // Finish UI updates back on the main actor
            await repository.finishActivity()
            await MainActor.run {
                toastCenter.setStatus(nil)
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

    @MainActor
    private func alignSelectedImage(with images: [SpectasiaImage]) {
        guard let currentID = selectedImageID else { return }
        if images.contains(where: { $0.id == currentID }) {
            return
        }
        selectedImageID = nil
    }
}

#Preview {
    ContentView()
}

