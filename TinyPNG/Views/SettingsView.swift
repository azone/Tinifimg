//
//  SettingsView.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/5/30.
//

import Foundation
import SwiftUI

let totalCount: Float = 500

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var showImporter: Bool = false
    var directoryName: String? {
        settings.directoryToSave?.lastPathComponent
    }

    var body: some View {
        Form {
            TextField("API Key", text: settings.$token)
            LabeledContent("Quota") {
                VStack(alignment: .leading) {
                    ProgressView(value: Float(settings.compressedCount), total: totalCount)

                    Text("You need process the png(s) to fetch/refresh the\ncompression count.")
                        .font(.footnote)
                }
            }
            .help("\(settings.compressedCount) / \(Int(totalCount))(for free account)")
            Toggle("Auto-processing pngs", isOn: settings.$autoProcessing)
            if !settings.override {
                Group {
                    LabeledContent("Directory to save") {
                        Button {
                            showImporter = true
                        } label: {
                            Label(directoryName ?? "Select directory to save", systemImage: "folder")
                        }
                    }
                    Text("Will save the optimized PNGs to this directory.")
                        .font(.footnote)
                }
            }
            Toggle("Override original images", isOn: settings.$override)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.directory], onCompletion: { result in
            if case let .success(url) = result {
                settings.directoryToSave = url
            }
        })
        .fixedSize()
        .padding()
    }
}
