import SwiftUI

/// Three-panel layout for Spectasia: Sidebar, Content, Detail
public struct SpectasiaLayout: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedDirectory: URL?
    @State private var images: [SpectasiaImage] = []
    @State private var selectedImage: SpectasiaImage?
    @State private var backgroundTasks: Int = 0

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, 
                             sidebar: {
            VStack {
                SidebarPanel(selectedDirectory: $selectedDirectory, images: $images)
                ContentPanel(images: $images, selectedImage: $selectedImage, backgroundTasks: $backgroundTasks)
            }
        },
                             detail: {
            DetailPanel(selectedImage: $selectedImage)
        })
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sidebar Panel

struct SidebarPanel: View {
    @Binding var selectedDirectory: URL?
    @Binding var images: [SpectasiaImage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(GypsumColor.accent)
                Text("Spectasia")
                    .font(GypsumFont.headline)
                    .foregroundColor(GypsumColor.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Directory list
            if images.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(GypsumColor.textSecondary)
                    Text("No directory selected")
                        .font(GypsumFont.body)
                        .foregroundColor(GypsumColor.textSecondary)
                    Text("Open a folder to start browsing images")
                        .font(GypsumFont.caption)
                        .foregroundColor(GypsumColor.textSecondary)
                }
                .padding()
            } else {
                Text("Directories")
                    .font(GypsumFont.caption)
                    .foregroundColor(GypsumColor.textSecondary)
                    .padding(.horizontal, 16)
                
                List(uniqueFolders(from: images), id: \.self, selection: $selectedDirectory) { folder in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(GypsumColor.accent)
                        Text(folder.lastPathComponent)
                            .font(GypsumFont.body)
                            .foregroundColor(GypsumColor.text)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Spectasia")
    }
    
    private func uniqueFolders(from images: [SpectasiaImage]) -> [URL] {
        Set(images.map { $0.url.deletingLastPathComponent() })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }
}

// MARK: - Content Panel

struct ContentPanel: View {
    @Binding var images: [SpectasiaImage]
    @Binding var selectedImage: SpectasiaImage?
    @Binding var backgroundTasks: Int
    
    var body: some View {
        ImageGridView(
            images: images,
            selectedImage: $selectedImage,
            backgroundTasks: $backgroundTasks
        )
        .navigationTitle("Library")
    }
}

// MARK: - Detail Panel

struct DetailPanel: View {
    @Binding var selectedImage: SpectasiaImage?
    
    var body: some View {
        if let image = selectedImage {
            VStack(spacing: 0) {
                SingleImageView(imageURL: image.url)
                Divider()
                    .padding(.vertical, 8)
                MetadataPanel(image: image)
            }
            .navigationTitle("Detail")
        } else {
            VStack(spacing: 16) {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(GypsumColor.textSecondary)
                    Text("Select an image to view")
                        .font(GypsumFont.headline)
                        .foregroundColor(GypsumColor.textSecondary)
                    Text("Click on any image in the grid to see details")
                        .font(GypsumFont.caption)
                        .foregroundColor(GypsumColor.textSecondary)
                }
                Spacer()
            }
            .navigationTitle("Detail")
            .background(GypsumColor.background)
        }
    }
}

// MARK: - Preview

#Preview("Three-Panel Layout") {
    SpectasiaLayout()
}
