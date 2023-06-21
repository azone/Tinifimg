//
//  NoImageView.swift
//  Tinifimg
//
//  Created by Logan Wang on 2023/6/15.
//

import Foundation
import SwiftUI

struct NoImageView: View {
    @Binding private var isDropTarget: Bool
    private var onFileSelection: ([URL]) -> Void
    @State private var showImagesPicker: Bool = false

    init(isDropTarget: Binding<Bool>, onFileSelection: @escaping ([URL]) -> Void) {
        self._isDropTarget = isDropTarget
        self.onFileSelection = onFileSelection
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Image(systemName: "photo")
                    .imageScale(.large)
                Text("Please drag images(png, jpeg or png) here!")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .font(.title)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDropTarget ? Color.accentColor : Color.gray,
                    style: .init(lineWidth: 4, dash: [6], dashPhase: 0)
                )
        }
        .fileImporter(isPresented: $showImagesPicker, allowedContentTypes: allowedTypes, allowsMultipleSelection: true) { results in
            do {
                onFileSelection(try results.get())
            } catch {}
        }
        .onTapGesture {
            showImagesPicker = true
        }
    }
}
