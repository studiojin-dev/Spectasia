import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public struct SingleImageView: View {
    public let imageURL: URL
    @State private var loadedImage: PlatformImage? = nil
    @State private var loadError: String? = nil

    public init(imageURL: URL) {
        self.imageURL = imageURL
    }

    public var body: some View {
        Group {
            if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(loadError)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color.gray.opacity(0.05))
            } else if let loadedImage {
                #if canImport(AppKit)
                Image(nsImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.02))
                #else
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.02))
                #endif
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await load()
                    }
            }
        }
        .navigationTitle(imageURL.lastPathComponent)
    }

    @MainActor
    private func load() async {
        do {
            let data = try await Task.detached {
                try Data(contentsOf: imageURL)
            }.value
            if let image = PlatformImage(data: data) {
                loadedImage = image
            } else {
                loadError = "Unable to decode image at \(imageURL.path)"
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#if canImport(AppKit)
private typealias PlatformImage = NSImage
#else
import UIKit
private typealias PlatformImage = UIImage
#endif

#Preview("Single Image View") {
    // Use a temporary empty view for preview; replace with a valid URL in app context
    SingleImageView(imageURL: URL(fileURLWithPath: "/dev/null"))
}
