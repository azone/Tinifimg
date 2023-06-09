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
    @EnvironmentObject var store: SettingsStore
    @State private var showImporter: Bool = false
    var directoryName: String? {
        store.directoryToSave?.lastPathComponent
    }

    var body: some View {
        Form {
            TextField("API Key", text: store.$token)
            LabeledContent("Quota") {
                VStack(alignment: .leading) {
                    ProgressView(value: Float(store.compressedCount), total: totalCount)

                    Text("You need process the png(s) to fetch/refresh the\ncompression count.")
                        .font(.footnote)
                }
            }
            .help("\(store.compressedCount) / \(Int(totalCount))(for free account)")
            if !store.override {
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
            Toggle("Override original images", isOn: store.$override)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.directory], onCompletion: { result in
            if case let .success(url) = result {
                store.directoryToSave = url
            }
        })
        .fixedSize()
        .padding()
    }
}
