//
//  TinifimgApp.swift
//  Tinifimg
//
//  Created by Logan Wang on 2023/5/30.
//

import SwiftUI

@main
struct TinifimgApp: App {
    private let store = DataStore()
    private let settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .onAppear {
                    // disable tabs
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .commandsRemoved()

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(store)
        }
    }
}
