//
// SpectasiaApp.swift
// Spectasia
//
// Created by kimjeongjin on 1/27/26.
//

import SwiftUI

@main
struct SpectasiaApp: App {
    @StateObject private var appConfig = AppConfig()
    @StateObject private var repository = ObservableImageRepository()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(repository)
                .environmentObject(appConfig)
        }
    }
}
