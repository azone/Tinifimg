//
//  SettingsStore.swift
//  Tinifimg
//
//  Created by Logan Wang on 2023/5/30.
//

import Foundation
import SwiftUI
import ServiceManagement

final class SettingsStore: ObservableObject {
    @AppStorage("API_TOKEN") var token: String = ""
    @AppStorage("OVERRIDE_ORIGINAL") var override: Bool = true
    @AppStorage("DIRECTORY_TO_SAVE") var directoryToSave: URL?
    @AppStorage("COMPRESSED_COUNT") var compressedCount: Int = 0
    @AppStorage("AUTO_PROCESSING") var autoProcessing: Bool = true
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    static let shared = SettingsStore()

    private init() {}
}
