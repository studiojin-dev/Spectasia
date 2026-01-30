import SwiftUI
import SpectasiaCore

struct SpectasiaCommands: Commands {
    @EnvironmentObject private var repository: ObservableImageRepository
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject private var appConfig: AppConfig

    var body: some Commands {
        CommandMenu("Library") {
            Button("Rescan Current Directory") {
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

            Button("Regenerate Thumbnails (Current Directory)") {
                Task {
                    await repository.startActivity(message: NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
                    toastCenter.setStatus(NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
                    await repository.regenerateThumbnailsForCurrentDirectory()
                    await repository.finishActivity()
                    toastCenter.setStatus(nil)
                    toastCenter.show(NSLocalizedString("Thumbnails refreshed (current)", comment: "Thumbnails refreshed for current directory"))
                }
            }

            Button("Regenerate Thumbnails (All Loaded)") {
                Task {
                    await repository.startActivity(message: NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
                    toastCenter.setStatus(NSLocalizedString("Refreshing thumbnails…", comment: "Thumbnail refresh in progress"))
                    await repository.regenerateThumbnailsForAllImages()
                    await repository.finishActivity()
                    toastCenter.setStatus(nil)
                    toastCenter.show(NSLocalizedString("Thumbnails refreshed (all)", comment: "Thumbnails refreshed for all images"))
                }
            }

            Divider()

            Button("Cleanup Missing Metadata") {
                let excludedPaths = appConfig.cleanupExcludedPathsPublished
                let removeMissing = appConfig.cleanupRemoveMissingOriginalsPublished
                Task { [metadataStoreManager, toastCenter, repository, excludedPaths, removeMissing] in
                    await repository.startActivity(message: NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))
                    toastCenter.setStatus(NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))
                    let result = await metadataStoreManager.store.cleanupMissingFiles(
                        removeMissingOriginals: removeMissing,
                        isOriginalSafeToRemove: { url in
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
        }
    }
}
