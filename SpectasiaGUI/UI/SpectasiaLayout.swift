import SwiftUI

/// Three-panel layout for Spectasia: Sidebar, Content, Detail
public struct SpectasiaLayout: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Albums & Folders
            SidebarPanel()

            // Content: Image Grid
            ContentPanel()

            // Detail: Single Image View
            DetailPanel()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sidebar Panel

struct SidebarPanel: View {
    var body: some View {
        List {
            NavigationLink(value: "library") {
                Label("Library", systemImage: "photo.on.rectangle")
            }

            NavigationLink(value: "albums") {
                Label("Albums", systemImage: "folder")
            }

            NavigationLink(value: "favorites") {
                Label("Favorites", systemImage: "heart")
            }
        }
        .navigationTitle("Spectasia")
        .listStyle(.sidebar)
    }
}

// MARK: - Content Panel

struct ContentPanel: View {
    var body: some View {
        VStack {
            Text("Image Browser")
                .font(GypsumFont.title)
                .foregroundColor(GypsumColor.textSecondary)
                .padding()
        }
        .navigationTitle("Library")
        .background(GypsumColor.background)
    }
}

// MARK: - Detail Panel

struct DetailPanel: View {
    var body: some View {
        VStack {
            Text("Select an image to view")
                .font(GypsumFont.body)
                .foregroundColor(GypsumColor.textSecondary)
        }
        .navigationTitle("Detail")
        .background(GypsumColor.background)
    }
}

// MARK: - Preview

#Preview("Three-Panel Layout") {
    SpectasiaLayout()
}
