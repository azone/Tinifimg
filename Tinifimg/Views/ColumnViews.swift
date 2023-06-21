//
//  ColumnViews.swift
//  Tinifimg
//
//  Created by Logan Wang on 2023/6/15.
//

import Foundation
import SwiftUI
import QuickLookThumbnailing

struct NameColumn: View {
    @StateObject var item: TinyImage

    @Environment(\.displayScale) var displayScale

    var body: some View {
        HStack {
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            }
            Text(verbatim: item.imageName)
        }
        .task(priority: .background) {
            if item.thumbnail == nil {
                await loadThumbnail(for: item)
            }
        }
    }

    private func loadThumbnail(for image: TinyImage) async {
        let request = QLThumbnailGenerator.Request(
            fileAt: image.localURL,
            size: .init(width: 32, height: 32),
            scale: displayScale,
            representationTypes: [.thumbnail]
        )
        let generator = QLThumbnailGenerator.shared
        let thumbnail = try? await generator.generateBestRepresentation(for: request)
        image.thumbnail = thumbnail?.nsImage
    }
}

struct StateColumn: View {
    @StateObject var item: TinyImage

    @EnvironmentObject var store: DataStore

    let percentStyle: FloatingPointFormatStyle<Double>.Percent = .percent
        .precision(.fractionLength(2))

    @State private var popoverErrorItem: TinyImage?

    var body: some View {
        ZStack {
            switch item.state {
            case .none, .waiting:
                Image(systemName: "clock")
            case .uploading(let progress):
                LabeledContent {
                    ProgressView(value: progress)
                } label: {
                    Image(systemName: "arrow.up")
                }
            case .downloading(let progress):
                LabeledContent {
                    ProgressView(value: progress)
                } label: {
                    Image(systemName: "arrow.down")
                }
            case .finished:
                HStack {
                    Image(systemName: "checkmark")
                    Text("Optimized \(item.optimizedRate.formatted(percentStyle))")
                }
                .foregroundColor(.green)
            case .error:
                HStack {
                    Button {
                        popoverErrorItem = item
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                    .help("Error occured")
                    .popover(item: $popoverErrorItem) { item in
                        if case .error(let error) = item.state {
                            Text("Error occurred: \(error?.localizedDescription ?? "Unknown")")
                                .padding()
                        } else {
                            Text("Unknown error occurred")
                                .padding()
                        }
                    }

                    Button {
                        Task {
                            await store.processImages([item])
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                    }
                    .help("Re-process this image")
                }
            }
        }
    }
}

struct OptimizedSizeColumn: View {
    @StateObject var item: TinyImage

    var body: some View {
        Text("\(item.optimizedSize.formatted(sizeStyle))")
    }
}
