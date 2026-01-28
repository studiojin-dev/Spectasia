import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Directory picker for selecting folders to monitor
public struct DirectoryPicker: View {
    @Binding var selectedURL: URL?
    let prompt: String
    @State private var isPresented = false

    public init(prompt: String = "Select a folder", selectedURL: Binding<URL?>) {
        self.prompt = prompt
        self._selectedURL = selectedURL
    }

    public var body: some View {
        Button(action: {
            isPresented = true
        }) {
            Image(systemName: "folder")
                .font(.title)
                .padding()
        }
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedURL = url
                    url.startAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("Directory selection failed: \(error)")
            }
        }
    }
}

/// SwiftUI view wrapper for directory selection
public struct DirectoryPickerButton: View {
    @State private var isPresented = false
    @Binding var selectedDirectory: String
    let prompt: String

    public init(prompt: String = "Select Folder", selectedDirectory: Binding<String>) {
        self.prompt = prompt
        self._selectedDirectory = selectedDirectory
    }

    public var body: some View {
        Button(action: {
            isPresented = true
        }) {
            HStack {
                Image(systemName: "folder")
                Text(selectedDirectory.isEmpty ? "Select Folder" : selectedDirectory)
            }
            .font(GypsumFont.body)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(GypsumColor.primary)
            .cornerRadius(8)
        }
        .sheet(isPresented: $isPresented) {
            DirectoryPickerSheet(
                isPresented: $isPresented,
                prompt: prompt,
                selectedDirectory: $selectedDirectory
            )
        }
    }
}

struct DirectoryPickerSheet: View {
    @Binding var isPresented: Bool
    let prompt: String
    @Binding var selectedDirectory: String

    @State private var selectedURL: URL?

    var body: some View {
        DirectoryPicker(
            prompt: prompt,
            selectedURL: Binding(
                get: { selectedURL },
                set: { url in
                    if let url = url {
                        selectedDirectory = url.path
                        isPresented = false
                    }
                }
            )
        )
        .frame(width: 600, height: 400)
    }
}

#Preview("Directory Picker") {
    DirectoryPickerButton(
        prompt: "Select Image Folder",
        selectedDirectory: .constant("")
    )
    .padding()
}
