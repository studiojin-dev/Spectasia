import SwiftUI
import SpectasiaCore

struct SpectasiaCommands: Commands {
    @EnvironmentObject private var repository: ObservableImageRepository
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager

    var body: some Commands {
        CommandMenu("Library") {
            Button("Rescan Current Directory") {
                Task {
                    do {
                        try await repository.rescanCurrentDirectory()
                        toastCenter.show("Rescan completed")
                    } catch {
                        toastCenter.show("Rescan failed")
                    }
                }
            }

            Button("Regenerate Thumbnails (Current Directory)") {
                Task {
                    await repository.regenerateThumbnailsForCurrentDirectory()
                    toastCenter.show("Thumbnails refreshed (current)")
                }
            }

            Button("Regenerate Thumbnails (All Loaded)") {
                Task {
                    await repository.regenerateThumbnailsForAllImages()
                    toastCenter.show("Thumbnails refreshed (all)")
                }
            }

            Divider()

            Button("Cleanup Missing Metadata") {
                Task { [metadataStoreManager, toastCenter] in
                    let result = await metadataStoreManager.store.cleanupMissingFiles(removeMissingOriginals: true)
                    toastCenter.show("Cleaned metadata: \(result.removedRecords) records, \(result.removedFiles) files")
                }
            }
        }
    }
}
