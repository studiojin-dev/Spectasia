import SwiftUI
import SpectasiaCore

/// Displays albums derived from metadata and user-defined definitions.
struct AlbumListView: View {
    @EnvironmentObject private var albumManager: AlbumManager
    @EnvironmentObject private var repository: ObservableImageRepository

    let onAlbumSelect: (AlbumManager.AlbumDefinition, [SpectasiaImage]) -> Void

    @State private var showingCreationSheet = false
    @State private var creationName = ""
    @State private var creationTag = ""
    @State private var renameTarget: AlbumManager.AlbumDefinition? = nil
    @State private var renameText = ""

    private var allAlbums: [AlbumManager.AlbumDefinition] {
        albumManager.albums + albumManager.derivedAlbums(from: repository.images)
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            if allAlbums.isEmpty {
                Text("No albums yet. Create one from a tag to get started.")
                    .font(GypsumFont.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(allAlbums) { album in
                            albumRow(album)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreationSheet) {
            AlbumCreationSheet(
                name: $creationName,
                tag: $creationTag,
                onCreate: { name, tag in
                    albumManager.createAlbum(
                        name: name,
                        category: .tag,
                        filter: .tags([tag])
                    )
                    creationName = ""
                    creationTag = ""
                },
                onCancel: {
                    showingCreationSheet = false
                }
            )
        }
        .sheet(item: $renameTarget) { album in
            AlbumRenameSheet(
                albumName: $renameText,
                title: album.name,
                onSave: {
                    albumManager.renameAlbum(id: album.id, to: renameText)
                    renameTarget = nil
                },
                onCancel: {
                    renameTarget = nil
                }
            )
        }
        .onChange(of: renameTarget) { _, target in
            renameText = target?.name ?? ""
        }
    }

    private var header: some View {
        HStack {
            Text("Albums")
                .font(GypsumFont.body)
                .foregroundColor(GypsumColor.text)
            Spacer()
            Button(action: {
                showingCreationSheet = true
            }) {
                Label("New album", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
    }

    private func albumRow(_ album: AlbumManager.AlbumDefinition) -> some View {
        let matches = albumManager.matchingImages(for: album, from: repository.images)
        return Button(action: {
            onAlbumSelect(album, matches)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(GypsumFont.body)
                        .foregroundColor(.primary)
                    Text("\(album.category.rawValue.capitalized) • \(matches.count) image\(matches.count == 1 ? "" : "s")")
                        .font(GypsumFont.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if album.isDerived {
                    Image(systemName: "bolt.horizontal")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(8)
            .background(GypsumColor.surface)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !album.isDerived {
                Button("Rename") {
                    renameTarget = album
                }
                Button(role: .destructive) {
                    albumManager.deleteAlbum(id: album.id)
                } label: {
                    Text("Delete")
                }
                Menu("Merge into...") {
                    ForEach(albumManager.albums.filter { $0.id != album.id }) { target in
                        Button(target.name) {
                            albumManager.mergeAlbums(into: target.id, sources: [album.id])
                        }
                    }
                }
            }
        }
    }
}

private struct AlbumCreationSheet: View {
    @Binding var name: String
    @Binding var tag: String

    let onCreate: (String, String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("New Tag Album")
                .font(GypsumFont.headline)
            TextField("Album name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Tag (e.g. travel)", text: $tag)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                Spacer()
                Button("Create") {
                    guard !name.isEmpty, !tag.isEmpty else { return }
                    onCreate(name, tag)
                    onCancel()
                }
            }
        }
        .padding()
        .frame(width: 360)
    }
}

private struct AlbumRenameSheet: View {
    @Binding var albumName: String
    let title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Rename Album")
                .font(GypsumFont.headline)
            Text(title)
                .font(GypsumFont.caption)
                .foregroundColor(.secondary)
            TextField("New name", text: $albumName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                Spacer()
                Button("Save") {
                    guard !albumName.isEmpty else { return }
                    onSave()
                }
            }
        }
        .padding()
        .frame(width: 360)
    }
}
