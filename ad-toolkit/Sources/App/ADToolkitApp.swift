//
//  ADToolkitApp.swift
//  AD Toolkit
//
//  Entry point for the macOS application.
//  Tab-based UI with three sections:
//    1. Cambiar Contraseña
//    2. Unir al Dominio
//    3. Diagnóstico
//

import SwiftUI
import ServiceManagement
import OSLog

@main
struct ADToolkitApp: App {
    @State private var selectedTab = 0

    init() {
        do {
            try SMAppService.daemon(plistName: "com.cisa.ad-toolkit.helper").register()
        } catch {
            os_log(.error, "Failed to register helper daemon: %{public}@", error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .frame(minWidth: 600, minHeight: 500)
        }
        .windowResizability(.contentSize)
    }
}
