//
// SpectasiaApp.swift
// Spectasia
//
// Created by kimjeongjin on 1/27/26.
//

import SwiftUI
import Combine
import SpectasiaCore

final class SelectionStore: ObservableObject {
    @Published var selectedImageID: String?

    init(selectedImageID: String? = nil) {
        self.selectedImageID = selectedImageID
    }
}

@main
struct SpectasiaApp: App {
    @StateObject private var appConfig: AppConfig
    @StateObject private var repository: ObservableImageRepository
    @StateObject private var permissionManager: PermissionManager
    @StateObject private var metadataStoreManager: MetadataStoreManager
    @StateObject private var directoryScanManager: DirectoryScanManager
    @StateObject private var albumManager: AlbumManager
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var selectionStore = SelectionStore()

    init() {
        let config = AppConfig()
        _appConfig = StateObject(wrappedValue: config)
        let metadataManager = MetadataStoreManager(rootDirectory: URL(fileURLWithPath: config.metadataStoreDirectory))
        _metadataStoreManager = StateObject(wrappedValue: metadataManager)
        _repository = StateObject(wrappedValue: ObservableImageRepository(metadataStore: metadataManager.store))
        let permissionMgr = PermissionManager()
        _permissionManager = StateObject(wrappedValue: permissionMgr)
        let albumMgr = AlbumManager(rootDirectory: metadataManager.rootDirectory)
        _albumManager = StateObject(wrappedValue: albumMgr)
        let scanManager = DirectoryScanManager(
            metadataStore: metadataManager.store,
            metadataStoreRoot: metadataManager.rootDirectory,
            appConfig: config,
            permissionManager: permissionMgr
        )
        _directoryScanManager = StateObject(wrappedValue: scanManager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(repository)
                .environmentObject(appConfig)
                .environmentObject(permissionManager)
                .environmentObject(metadataStoreManager)
                .environmentObject(directoryScanManager)
                .environmentObject(toastCenter)
                .environmentObject(albumManager)
                .environmentObject(selectionStore)
        }
        .commands {
            SpectasiaCommands(
                repository: repository,
                toastCenter: toastCenter,
                metadataStoreManager: metadataStoreManager,
                appConfig: appConfig,
                selectionStore: selectionStore
            )
        }
    }
}
