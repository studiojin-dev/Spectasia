import SwiftUI
import SpectasiaCore

/// Tree view that displays indexed directories, exposes scan controls, and allows loading a watched folder.
struct DirectoryTreeView: View {
    @EnvironmentObject private var directoryScanManager: DirectoryScanManager

    let selectedPath: String?
    let onSelectDirectory: ((AppConfig.DirectoryBookmark) -> Void)?

    init(
        selectedPath: String?,
        onSelectDirectory: ((AppConfig.DirectoryBookmark) -> Void)? = nil
    ) {
        self.selectedPath = selectedPath
        self.onSelectDirectory = onSelectDirectory
    }

    var body: some View {
        ScrollView {
            if directoryScanManager.directoryTree.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 32))
                        .foregroundColor(GypsumColor.textSecondary)
                    Text("No directories indexed yet.")
                        .font(GypsumFont.body)
                        .foregroundColor(GypsumColor.textSecondary)
                    Text("Add a folder to begin scanning and monitoring.")
                        .font(GypsumFont.caption)
                        .foregroundColor(GypsumColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(directoryScanManager.directoryTree) { node in
                        DirectoryTreeRow(
                            node: node,
                            level: 0,
                            selectedPath: selectedPath,
                            onSelectDirectory: onSelectDirectory
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DirectoryTreeRow: View {
    let node: DirectoryScanManager.DirectoryNode
    let level: Int
    let selectedPath: String?
    let onSelectDirectory: ((AppConfig.DirectoryBookmark) -> Void)?
    @EnvironmentObject private var directoryScanManager: DirectoryScanManager

    private var statusDescription: String {
        switch node.status {
        case .scanning:
            return "Indexing…"
        case .complete:
            if let date = node.lastScanDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "\(formatter.localizedString(for: date, relativeTo: Date())) • \(node.fileCount) files"
            }
            return "\(node.fileCount) files"
        case .idle:
            return "Idle • \(node.fileCount) files"
        }
    }

    private var indentation: CGFloat {
        CGFloat(level) * 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Button(action: {
                    directoryScanManager.toggleExpansion(for: node.id)
                }) {
                    Image(systemName: directoryScanManager.isExpanded(node.id) ? "chevron.down" : "chevron.right")
                        .opacity(node.children.isEmpty ? 0.2 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(node.children.isEmpty)

                VStack(alignment: .leading, spacing: 1) {
                    Text(node.url.lastPathComponent)
                        .font(.body)
                        .foregroundColor(selectedPath == node.id ? GypsumColor.accent : GypsumColor.text)
                    Text(statusDescription)
                        .font(GypsumFont.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if directoryScanManager.isIndexing(node.id) {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                if node.isRoot {
                    Button("Index") {
                        directoryScanManager.startIndexingRoot(at: node.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    Button(role: .destructive) {
                        Task {
                            await directoryScanManager.removeDirectory(at: node.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.leading, indentation)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedPath == node.id ? GypsumColor.surface.opacity(0.35) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isRoot,
                   let bookmark = directoryScanManager.bookmark(for: node.id) {
                    onSelectDirectory?(bookmark)
                }
            }
            if directoryScanManager.isExpanded(node.id) {
                ForEach(node.children) { child in
                    DirectoryTreeRow(
                        node: child,
                        level: level + 1,
                        selectedPath: selectedPath,
                        onSelectDirectory: onSelectDirectory
                    )
                }
            }
        }
    }
}
