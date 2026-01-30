import Foundation

/// Observable wrapper to manage MetadataStore lifecycle from UI.
@MainActor
@available(macOS 10.15, *)
public final class MetadataStoreManager: ObservableObject {
    @Published public var rootDirectory: URL {
        didSet {
            Task {
                await store.updateRoot(rootDirectory)
            }
        }
    }

    public let store: MetadataStore

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.store = MetadataStore(rootDirectory: rootDirectory)
    }
}
