//
//  InputAPIView.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/6/15.
//

import Foundation
import SwiftUI

struct InputAPIView: View {
    @EnvironmentObject var setting: SettingsStore

    @State private var token: String = ""

    var body: some View {
        Form {
            HStack(alignment: .center) {
                Spacer()
                HStack {
                    Text("Please input your API key")
                        .font(.headline)
                    Link(destination: URL(string: "https://tinypng.com/developers").unsafelyUnwrapped) {
                        Image(systemName: "questionmark.circle.fill")
                    }
                }
                Spacer()
            }

            TextField("API Key", text: $token)
                .onSubmit {
                    setting.token = token
                }

            HStack {
                Spacer()
                Button("Done") {
                    setting.token = token
                }
            }
        }
        .padding()
    }
}
