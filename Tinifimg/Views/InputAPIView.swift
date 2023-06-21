//
//  InputAPIView.swift
//  Tinifimg
//
//  Created by Logan Wang on 2023/6/15.
//

import Foundation
import SwiftUI

struct InputAPIView: View {
    @EnvironmentObject var settings: SettingsStore

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
                    settings.token = token
                }

            HStack {
                Spacer()
                Button("Done") {
                    settings.token = token
                }
            }
        }
        .padding()
    }
}
