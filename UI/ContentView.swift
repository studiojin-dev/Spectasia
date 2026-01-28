//
//  ContentView.swift
//  Spectasia
//
//  Created by kimjeongjin on 1/27/26.
//

import SwiftUI

/// Main view for Spectasia image viewer
/// Connects Core services with UI components
struct ContentView: View {
    // MARK: - State
    @State private var images: [SpectasiaImage] = []
    @State private var selectedImage: SpectasiaImage? = nil
    @State private var selectedDirectory: URL? = nil
    @State private var backgroundTasks: Int = 0
    
    // MARK: - Core Services
    private let appConfig = AppConfig()
    private let permissionManager = PermissionManager()
    
    // MARK: - Body
    public var body: some View {
        SpectasiaLayout()
        .onAppear {
            requestInitialDirectoryAccess()
        }
    }
    
    // MARK: - Setup
    private func requestInitialDirectoryAccess() {
        if permissionManager.grantedDirectories.isEmpty {
            // Request initial directory access on first launch
            permissionManager.requestDirectoryAccess()
        }
    }
}

#Preview {
    ContentView()
}
