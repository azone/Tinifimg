//
//  SettingsStore.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/5/30.
//

import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    @AppStorage("API_TOKEN") var token: String = ""
    @AppStorage("OVERRIDE_ORIGINAL") var override: Bool = true
    @AppStorage("DIRECTORY_TO_SAVE") var directoryToSave: URL?
    @AppStorage("COMPRESSED_COUNT") var compressedCount: Int = 0
}
