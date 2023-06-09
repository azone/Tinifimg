//
//  TinyPNGApp.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/5/30.
//

import SwiftUI

@main
struct TinyPNGApp: App {
    let store = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    // disable tabs
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .commandsRemoved()

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
