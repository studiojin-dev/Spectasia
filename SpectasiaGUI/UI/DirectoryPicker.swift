import SwiftUI
import AppKit

/// Directory picker for selecting folders to monitor
public struct DirectoryPicker: NSViewRepresentable {
    @Binding var selectedURL: URL?
    let prompt: String

    public init(prompt: String = "Select a folder", selectedURL: Binding<URL?>) {
        self.prompt = prompt
        self._selectedURL = selectedURL
    }

    public func makeNSView(context: Context) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        return panel
    }

    public func updateNSView(_ nsView: NSOpenPanel, context: Context) {
        // Update panel if needed
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator($selectedURL)
    }

    public class Coordinator: NSObject, NSOpenPanelDelegate {
        @Binding var selectedURL: URL?

        init(_ selectedURL: Binding<URL?>) {
            self._selectedURL = selectedURL
        }

        func panel(_ panel: NSOpenPanel, didUpdateTo url: URL?) {
            DispatchQueue.main.async {
                self.selectedURL = url
            }
        }

        func panel(_ panel: NSOpenPanel, shouldEnable url: URL) -> Bool {
            return url.hasDirectoryPath
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
