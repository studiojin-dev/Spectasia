import AppKit
import SwiftUI
import SpectasiaCore

struct SpectasiaCommands: Commands {
    @ObservedObject private var repository: ObservableImageRepository
    private let toastCenter: ToastCenter
    private let metadataStoreManager: MetadataStoreManager
    private let appConfig: AppConfig
    private let selectionStore: SelectionStore

    private var selectedImage: SpectasiaImage? {
        repository.images.first(where: { $0.id == selectionStore.selectedImageID })
    }

    private var selectedIndex: Int? {
        guard let selected = selectedImage else { return nil }
        return repository.images.firstIndex(where: { $0.id == selected.id })
    }

    init(
        repository: ObservableImageRepository,
        toastCenter: ToastCenter,
        metadataStoreManager: MetadataStoreManager,
        appConfig: AppConfig,
        selectionStore: SelectionStore
    ) {
        self.repository = repository
        self.toastCenter = toastCenter
        self.metadataStoreManager = metadataStoreManager
        self.appConfig = appConfig
        self.selectionStore = selectionStore
    }

    var body: some Commands {
        CommandMenu("File") {
            Button("Rescan Current Directory") {
                rescanCurrentDirectory()
            }
            .keyboardShortcut("r", modifiers: .command)

            Menu("Regenerate Thumbnails") {
                Button("Current Directory") {
                    regenerateThumbnailsForCurrentDirectory()
                }
                Button("All Loaded Images") {
                    regenerateThumbnailsForAllImages()
                }
            }
        }

        CommandMenu("View") {
            Button("Thumbnail Grid") {
                postViewMode(.thumbnailGrid)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("List View") {
                postViewMode(.list)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Single Image View") {
                postViewMode(.singleImage)
            }
            .keyboardShortcut("3", modifiers: .command)

            Divider()

            Button("Toggle Full Screen") {
                toggleFullScreen()
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Exit Full Screen") {
                exitFullScreen()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Divider()

            Button("Fit to Window") {
                postZoomFit()
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(selectedImage == nil)

            Button("Actual Size") {
                postZoomActual()
            }
            .keyboardShortcut("9", modifiers: .command)
            .disabled(selectedImage == nil)
        }

        CommandMenu("Rating") {
            Button("Clear Rating") {
                setRating(0)
            }
            .keyboardShortcut(.init("0"), modifiers: .control)
            .disabled(selectedImage == nil)

            Divider()

            ForEach(1...5, id: \.self) { rating in
                Button(String(repeating: "★", count: rating)) {
                    setRating(rating)
                }
                .keyboardShortcut(.init(Character("\(rating)")), modifiers: .control)
                .disabled(selectedImage == nil)
            }
        }

        CommandMenu("Navigate") {
            Button("Previous Image") {
                goToImage(delta: -1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(selectedImage == nil || selectedIndex == nil || selectedIndex == 0)

            Button("Next Image") {
                goToImage(delta: 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(selectedImage == nil || selectedIndex == nil || selectedIndex == repository.images.count - 1)
        }

        CommandMenu("Tools") {
            Button("Open Settings…") {
                NotificationCenter.default.post(name: .SpectasiaOpenSettings, object: nil)
            }

            Divider()
            Button("Cleanup Missing Metadata") {
                cleanupMetadata()
            }

            if repository.queueSummary.totalTasks > 0 || repository.queueSummary.isProcessing {
                Divider()
                Text(repository.queueSummary.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        CommandMenu("Help") {
            Button("Spectasia Help") {
                openHelpLink()
            }
        }
    }

    private func rescanCurrentDirectory() {
        Task {
            do {
                await repository.startActivity(message: NSLocalizedString("Rescanning…", comment: "Rescan in progress"))
                toastCenter.setStatus(NSLocalizedString("Rescanning…", comment: "Rescan in progress"))
                try await repository.rescanCurrentDirectory()
                await repository.finishActivity()
                toastCenter.setStatus(nil)
                toastCenter.show(NSLocalizedString("Rescan completed", comment: "Rescan finished"))
            } catch {
                await repository.finishActivity()
                toastCenter.setStatus(nil)
                toastCenter.show(NSLocalizedString("Rescan failed", comment: "Rescan failed"))
            }
        }
    }

    private func regenerateThumbnailsForCurrentDirectory() {
        Task {
            await repository.startActivity(message: NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
            toastCenter.setStatus(NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
            await repository.regenerateThumbnailsForCurrentDirectory()
            await repository.finishActivity()
            toastCenter.setStatus(nil)
            toastCenter.show(NSLocalizedString("Thumbnails refreshed (current)", comment: "Thumbnails refreshed for current directory"))
        }
    }

    private func regenerateThumbnailsForAllImages() {
        Task {
            await repository.startActivity(message: NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
            toastCenter.setStatus(NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
            await repository.regenerateThumbnailsForAllImages()
            await repository.finishActivity()
            toastCenter.setStatus(nil)
            toastCenter.show(NSLocalizedString("Thumbnails refreshed (all)", comment: "Thumbnails refreshed for all images"))
        }
    }

    private func cleanupMetadata() {
        Task { [metadataStoreManager, toastCenter, repository] in
            let excludedPaths = await MainActor.run { appConfig.cleanupExcludedPathsPublished }
            let removeMissing = await MainActor.run { appConfig.cleanupRemoveMissingOriginalsPublished }
            await repository.startActivity(message: NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))
            toastCenter.setStatus(NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))
            let result = await metadataStoreManager.store.cleanupMissingFiles(
                removeMissingOriginals: removeMissing,
                isOriginalSafeToRemove: { @Sendable (url: URL) -> Bool in
                    !excludedPaths.contains(where: { url.path.hasPrefix($0) })
                }
            )
            await repository.finishActivity()
            toastCenter.setStatus(nil)
            let message = String(
                format: NSLocalizedString("Cleaned metadata: %lld records, %lld files", comment: "Cleanup summary"),
                result.removedRecords,
                result.removedFiles
            )
            toastCenter.show(message)
        }
    }

    private func postViewMode(_ mode: SpectasiaLayout.ViewMode) {
        NotificationCenter.default.post(name: .SpectasiaChangeViewMode, object: mode)
    }

    private func openHelpLink() {
        guard let url = URL(string: "https://spectasia.app/help") else { return }
        NSWorkspace.shared.open(url)
    }

    private func setRating(_ rating: Int) {
        guard let image = selectedImage else { return }
        Task {
            do {
                let xmpService = XMPService(metadataStore: metadataStoreManager.store)
                try await xmpService.writeRating(url: image.url, rating: rating)
                await repository.refreshImages()
                await MainActor.run {
                    toastCenter.show(NSLocalizedString("Rating updated", comment: "Rating saved message"))
                }
            } catch {
                await MainActor.run {
                    toastCenter.show(NSLocalizedString("Failed to save rating", comment: "Rating failure"))
                }
                CoreLog.error("Failed to save rating: \(error.localizedDescription)", category: "SpectasiaCommands")
            }
        }
    }

    private func goToImage(delta: Int) {
        guard let index = selectedIndex else { return }
        let newIndex = index + delta
        guard repository.images.indices.contains(newIndex) else { return }
        selectionStore.selectedImageID = repository.images[newIndex].id
    }

    private func toggleFullScreen() {
        #if os(macOS)
        NSApp.keyWindow?.toggleFullScreen(nil)
        #endif
    }

    private func exitFullScreen() {
        #if os(macOS)
        if NSApp.keyWindow?.styleMask.contains(.fullScreen) == true {
            NSApp.keyWindow?.toggleFullScreen(nil)
        }
        #endif
    }

    private func postZoomFit() {
        guard selectedImage != nil else { return }
        NotificationCenter.default.post(name: .SpectasiaSingleImageZoomFit, object: nil)
    }

    private func postZoomActual() {
        guard selectedImage != nil else { return }
        NotificationCenter.default.post(name: .SpectasiaSingleImageZoomActual, object: nil)
    }
}
