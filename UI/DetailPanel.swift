//
//  DetailPanel.swift
//  Spectasia
//
//  Detail panel for displaying image metadata and properties
//

import SwiftUI
import SpectasiaCore

/// Detail panel for displaying image metadata when an image is selected
public struct DetailPanel: View {
    @Binding private var selectedImage: SpectasiaImage?
    
    public init(selectedImage: Binding<SpectasiaImage?>) {
        self._selectedImage = selectedImage
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if let image = selectedImage {
                // Image selected - show metadata
                ImageMetadataView(image: image)
            } else {
                // No image selected - show empty state
                EmptyStateView()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 300, maxHeight: .infinity)
    }
}

// MARK: - Image Metadata View

private struct ImageMetadataView: View {
    let image: SpectasiaImage
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.title2)
                    Text("Image Details")
                        .font(GypsumFont.headline)
                        .foregroundColor(GypsumColor.text)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Basic Properties Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Properties", icon: "doc.text")
                    
                    // Filename
                    MetadataRow(
                        icon: "doc",
                        title: "Filename",
                        value: image.url.lastPathComponent
                    )
                    
                    // File Size
                    MetadataRow(
                        icon: "harddrive",
                        title: "File Size",
                        value: formatFileSize(image.metadata.fileSize)
                    )
                    
                    // Dimensions
                    MetadataRow(
                        icon: "photo",
                        title: "Dimensions",
                        value: "Unknown" // Could be added to metadata if needed
                    )
                    
                    // Format
                    MetadataRow(
                        icon: "doc.plaintext",
                        title: "Format",
                        value: image.metadata.fileExtension.uppercased()
                    )
                    
                    // Modification Date
                    MetadataRow(
                        icon: "calendar",
                        title: "Modified",
                        value: formatDate(image.metadata.modificationDate)
                    )
                }
                .padding(.horizontal, 16)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Rating Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Rating", icon: "star")
                    
                    HStack {
                        ForEach(0..<5, id: \.self) { index in
                            Button(action: {
                                // Rating functionality would be implemented here
                            }) {
                                Image(systemName: index < image.metadata.rating ? "star.fill" : "star")
                                    .foregroundColor(index < image.metadata.rating ? .yellow : .secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                
                // Tags Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Tags", icon: "tag")
                    
                    if image.metadata.tags.isEmpty {
                        Text("No tags")
                            .foregroundColor(.secondary)
                            .font(GypsumFont.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(image.metadata.tags, id: \.self) { tag in
                                    TagView(tag: tag)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Metadata Row

private struct MetadataRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.caption)
                .frame(width: 16)
            
            Text(title)
                .font(GypsumFont.body)
                .foregroundColor(GypsumColor.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(GypsumFont.body)
                .foregroundColor(GypsumColor.text)
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.caption)
            Text(title)
                .font(GypsumFont.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Tag View

private struct TagView: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .font(GypsumFont.caption)
            .foregroundColor(GypsumColor.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(GypsumColor.border)
            .cornerRadius(8)
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .foregroundColor(.secondary)
                .font(.system(size: 48))
            
            Text("Select an Image")
                .font(GypsumFont.headline)
                .foregroundColor(GypsumColor.text)
            
            Text("Choose an image from the gallery to view its details")
                .font(GypsumFont.body)
                .foregroundColor(GypsumColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview("Detail Panel - Empty") {
    DetailPanel(selectedImage: .constant(nil))
}

#Preview("Detail Panel - With Image") {
    // Mock image for preview
    let mockImage = SpectasiaImage(
        url: URL(fileURLWithPath: "/Users/user/Pictures/test.jpg"),
        metadata: ImageMetadata(
            rating: 3,
            tags: ["landscape", "nature", "mountains"],
            fileSize: 2048576,
            modificationDate: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            fileExtension: "jpg"
        )
    )
    
    return DetailPanel(selectedImage: .constant(mockImage))
}
