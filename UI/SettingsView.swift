import SwiftUI
import UniformTypeIdentifiers
import SpectasiaCore

/// Settings view for app configuration
public struct SettingsView: View {
    @EnvironmentObject private var appConfig: AppConfig
    @EnvironmentObject private var metadataStoreManager: MetadataStoreManager
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var repository: ObservableImageRepository
    @Environment(\.dismiss) private var dismiss

    @State private var isStorePickerPresented = false
    @State private var isProtectedDirectoryPickerPresented = false
    @State private var lastCleanupSummary: String? = nil

    @State private var draftMetadataStoreDirectory: String = ""
    @State private var draftLanguage: AppLanguage = .english
    @State private var draftAutoAI: Bool = false
    @State private var draftAutoCleanup: Bool = false
    @State private var draftRemoveMissing: Bool = false

    private var languageColumns: [GridItem] {
        Array(repeating: .init(.flexible(), spacing: 12), count: 2)
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GypsumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storage & Language")
                            .font(GypsumFont.title)
                            .foregroundColor(GypsumColor.text)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Metadata store")
                                    .font(GypsumFont.headline)
                                Text(draftMetadataStoreDirectory)
                                    .font(GypsumFont.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            GypsumButton(title: "Choose folder…", style: .secondary) {
                                isStorePickerPresented = true
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("App language")
                                .font(GypsumFont.headline)
                            LazyVGrid(columns: languageColumns, spacing: 8) {
                                LanguageButton(title: "English", language: .english, selected: draftLanguage == .english) {
                                    draftLanguage = .english
                                }
                                LanguageButton(title: "한국어", language: .korean, selected: draftLanguage == .korean) {
                                    draftLanguage = .korean
                                }
                            }
                        }
                    }
                }

                GypsumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI & Maintenance")
                            .font(GypsumFont.title)
                            .foregroundColor(GypsumColor.text)

                        Toggle("Enable AI analysis", isOn: $draftAutoAI)
                        Toggle("Auto cleanup missing metadata", isOn: $draftAutoCleanup)
                        Toggle("Remove missing originals", isOn: $draftRemoveMissing)

                        GypsumButton(title: "Run cleanup now") {
                            runCleanup()
                        }

                        if let summary = lastCleanupSummary {
                            Text(summary)
                                .font(GypsumFont.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                GypsumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cleanup safety")
                            .font(GypsumFont.title)
                            .foregroundColor(GypsumColor.text)

                        if appConfig.cleanupExcludedPathsPublished.isEmpty {
                            Text("No protected directories configured.")
                                .font(GypsumFont.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(appConfig.cleanupExcludedPathsPublished, id: \.self) { path in
                                HStack {
                                    Text(path)
                                        .font(GypsumFont.caption)
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

                        GypsumButton(title: "Protect directory…", style: .secondary) {
                            isProtectedDirectoryPickerPresented = true
                        }
                        Text("Cleanup will never delete metadata inside protected directories.")
                            .font(GypsumFont.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    GypsumButton(title: "Cancel", style: .secondary) {
                        resetDrafts()
                        dismiss()
                    }
                    GypsumButton(title: "Apply") {
                        commitChanges()
                    }
                    GypsumButton(title: "Save") {
                        commitChanges()
                        dismiss()
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 520, minHeight: 520)
        .onAppear {
            loadDrafts()
        }
        .fileImporter(
            isPresented: $isStorePickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    draftMetadataStoreDirectory = url.path
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

    private func loadDrafts() {
        draftMetadataStoreDirectory = appConfig.metadataStoreDirectoryPublished
        draftLanguage = appConfig.languagePublished
        draftAutoAI = appConfig.isAutoAIEnabledPublished
        draftAutoCleanup = appConfig.isAutoCleanupEnabledPublished
        draftRemoveMissing = appConfig.cleanupRemoveMissingOriginalsPublished
    }

    private func resetDrafts() {
        loadDrafts()
    }

    private func commitChanges() {
        appConfig.metadataStoreDirectoryPublished = draftMetadataStoreDirectory
        metadataStoreManager.rootDirectory = URL(fileURLWithPath: draftMetadataStoreDirectory)
        appConfig.languagePublished = draftLanguage
        appConfig.isAutoAIEnabledPublished = draftAutoAI
        appConfig.isAutoCleanupEnabledPublished = draftAutoCleanup
        appConfig.cleanupRemoveMissingOriginalsPublished = draftRemoveMissing
    }

    private func runCleanup() {
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
}

private struct LanguageButton: View {
    let title: String
    let language: AppLanguage
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(GypsumFont.body)
                .foregroundColor(selected ? .white : GypsumColor.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selected ? GypsumColor.primary : GypsumColor.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.clear : GypsumColor.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
