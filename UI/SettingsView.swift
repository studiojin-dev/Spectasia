import SwiftUI
import UniformTypeIdentifiers
import SpectasiaCore

/// Settings view for app configuration
public struct SettingsView: View {
    @EnvironmentObject private var appConfig: AppConfig
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var repository: ObservableImageRepository
    @State private var isStorePickerPresented = false
    @State private var isProtectedDirectoryPickerPresented = false
    @State private var lastCleanupSummary: String? = nil
    
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
                Toggle("Remove Missing Originals", isOn: $appConfig.cleanupRemoveMissingOriginalsPublished)
                Button("Run Cleanup Now") {
                    Task { [metadataStoreManager, toastCenter, repository] in
                        let excludedPaths = await MainActor.run { appConfig.cleanupExcludedPathsPublished }
                        let safeExcludedPaths = excludedPaths
                        let removeMissing = await MainActor.run { appConfig.cleanupRemoveMissingOriginalsPublished }
                        await repository.startActivity(message: NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))
                        toastCenter.setStatus(NSLocalizedString("Cleaning metadata…", comment: "Cleanup in progress"))
                        let result = await metadataStoreManager.store.cleanupMissingFiles(
                            removeMissingOriginals: removeMissing,
                            isOriginalSafeToRemove: { @Sendable (url: URL) -> Bool in
                                !safeExcludedPaths.contains(where: { url.path.hasPrefix($0) })
                            }
                        )
                        await repository.finishActivity()
                        toastCenter.setStatus(nil)
                        let message = String(
                            format: NSLocalizedString("Cleaned metadata: %lld records, %lld files", comment: "Cleanup summary"),
                            result.removedRecords,
                            result.removedFiles
                        )
                        toastCenter.show(message)
                        await MainActor.run {
                            lastCleanupSummary = message
                        }
                    }
                }
                if let summary = lastCleanupSummary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Cleanup Safety") {
                if appConfig.cleanupExcludedPathsPublished.isEmpty {
                    Text("No protected directories configured.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appConfig.cleanupExcludedPathsPublished, id: \.self) { path in
                        HStack {
                            Text(path)
                                .font(.footnote)
                                .lineLimit(1)
                                .textSelection(.enabled)
                            Spacer()
                            Button(role: .destructive) {
                                if let index = appConfig.cleanupExcludedPathsPublished.firstIndex(of: path) {
                                    appConfig.removeCleanupExcludedPaths(at: IndexSet(integer: index))
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Protect Directory…") {
                    isProtectedDirectoryPickerPresented = true
                }
                .buttonStyle(.bordered)
                Text("Cleanup will never delete metadata for files inside protected directories.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
        .fileImporter(
            isPresented: $isProtectedDirectoryPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    appConfig.addCleanupExcludedPath(url.path)
                }
            case .failure:
                break
            }
        }
    }
}
