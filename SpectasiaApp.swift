//
// SpectasiaApp.swift
// Spectasia
//
// Created by kimjeongjin on 1/27/26.
//

import SwiftUI
import SpectasiaCore

@main
struct SpectasiaApp: App {
    @StateObject private var appConfig: AppConfig
    @StateObject private var repository: ObservableImageRepository
    @StateObject private var permissionManager: PermissionManager

    init() {
        let config = AppConfig()
        _appConfig = StateObject(wrappedValue: config)
        _repository = StateObject(wrappedValue: ObservableImageRepository(cacheDirectory: config.cacheDirectory))
        _permissionManager = StateObject(wrappedValue: PermissionManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(repository)
                .environmentObject(appConfig)
                .environmentObject(permissionManager)
        }
    }
}
