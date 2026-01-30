import SwiftUI
import UniformTypeIdentifiers
import SpectasiaCore

/// Settings view for app configuration
public struct SettingsView: View {
    @EnvironmentObject private var appConfig: AppConfig
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var isStorePickerPresented = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Metadata Storage") {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Storage Directory")
                            .font(.headline)
                        Text(appConfig.metadataStoreDirectoryPublished)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button("Choose…") {
                        isStorePickerPresented = true
                    }
                }
            }

            Section("Language") {
                Picker("App Language", selection: $appConfig.languagePublished) {
                    Text("English").tag(AppLanguage.english)
                    Text("한국어").tag(AppLanguage.korean)
                }
                .pickerStyle(.segmented)
            }

            Section("AI") {
                Toggle("Enable AI Analysis", isOn: $appConfig.isAutoAIEnabledPublished)
            }

            Section("Maintenance") {
                Toggle("Auto Cleanup Missing Metadata", isOn: $appConfig.isAutoCleanupEnabledPublished)
                Button("Run Cleanup Now") {
                    Task { [metadataStoreManager, toastCenter] in
                        let result = await metadataStoreManager.store.cleanupMissingFiles(removeMissingOriginals: true)
                        toastCenter.show("Cleaned metadata: \(result.removedRecords) records, \(result.removedFiles) files")
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
        .fileImporter(
            isPresented: $isStorePickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    appConfig.metadataStoreDirectoryPublished = url.path
                    metadataStoreManager.rootDirectory = url
                }
            case .failure:
                break
            }
        }
    }
}
