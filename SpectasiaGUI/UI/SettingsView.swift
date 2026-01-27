import SwiftUI
import AppKit

/// Settings view for app configuration
public struct SettingsView: View {
    @AppStorage("cacheDirectory") private var cacheDirectory: String = ""
    @AppStorage("appLanguage") private var languageRaw: String = "en"
    @AppStorage("autoAIEnabled") private var autoAIEnabled: Bool = false

    private var languages = ["English": "en", "Korean": "ko"]

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                // Folder settings
                Section("Folders") {
                    NavigationLink("Monitored Folders") {
                        FolderPreferencesView()
                    }
                }

                // Cache settings
                Section("Cache") {
                    HStack {
                        Text("Cache Directory")
                            .font(GypsumFont.body)
                        Spacer()
                        Text(cacheDirectory.isEmpty ? "Default" : cacheDirectory)
                            .font(GypsumFont.caption)
                            .foregroundColor(GypsumColor.textSecondary)
                        Button("Browse") {
                            selectCacheDirectory()
                        }
                        .font(GypsumFont.caption)
                    }
                }

                // Language settings
                Section("Language") {
                    Picker("Language", selection: $languageRaw) {
                        ForEach(Array(languages.keys.sorted()), id: \.self) { key in
                            Text(key).tag(languages[key]!)
                        }
                    }
                    .font(GypsumFont.body)
                }

                // AI settings
                Section("AI Analysis") {
                    Toggle("Auto-analyze new images", isOn: $autoAIEnabled)
                        .font(GypsumFont.body)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                            .font(GypsumFont.body)
                        Spacer()
                        Text("1.0.0")
                            .font(GypsumFont.caption)
                            .foregroundColor(GypsumColor.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Private Methods

    private func selectCacheDirectory() {
        let panel = NSOpenPanel()
        panel.prompt = "Select Cache Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            cacheDirectory = url.path
        }
    }
}

#Preview("Settings") {
    SettingsView()
}
