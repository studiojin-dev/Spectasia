import AppKit
import SwiftUI
import SpectasiaCore

struct SpectasiaCommands: Commands {
    @EnvironmentObject private var repository: ObservableImageRepository
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject private var appConfig: AppConfig

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
}
