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
                        try await repository.rescanCurrentDirectory()
                        toastCenter.show(NSLocalizedString("Rescan completed", comment: "Rescan finished"))
                    } catch {
                        toastCenter.show(NSLocalizedString("Rescan failed", comment: "Rescan failed"))
                    }
                }
            }

            Button("Regenerate Thumbnails (Current Directory)") {
                Task {
                    await repository.regenerateThumbnailsForCurrentDirectory()
                    toastCenter.show(NSLocalizedString("Thumbnails refreshed (current)", comment: "Thumbnails refreshed for current directory"))
                }
            }

            Button("Regenerate Thumbnails (All Loaded)") {
                Task {
                    await repository.regenerateThumbnailsForAllImages()
                    toastCenter.show(NSLocalizedString("Thumbnails refreshed (all)", comment: "Thumbnails refreshed for all images"))
                }
            }

            Divider()

            Button("Cleanup Missing Metadata") {
                Task { [metadataStoreManager, toastCenter] in
                    let result = await metadataStoreManager.store.cleanupMissingFiles(removeMissingOriginals: appConfig.cleanupRemoveMissingOriginalsPublished)
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
