//
//  ContentView.swift
//  Tinifimg
//
//  Created by Logan Wang on 2023/5/30.
//

import SwiftUI
import QuickLook
import QuickLookThumbnailing

let allowedImages: [UTType] = [.png, .jpeg, .webP]
let allowedTypes: [UTType] = allowedImages + CollectionOfOne(.directory)

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: DataStore

    @State private var isDropTarget = false
    @State private var selections = Set<TinyImage.ID>()

    var importedURLs: Set<TinyImage.ID> {
        Set(store.images.map(\.id))
    }

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            if store.images.isEmpty {
                NoImageView(isDropTarget: $isDropTarget) { urls in
                    var imageURLs: [URL] = []
                    for url in urls {
                        if url.hasDirectoryPath {
                            imageURLs += enumerateFiles(for: url)
                        } else {
                            imageURLs.append(url)
                        }
                    }
                    let importedURLs = self.importedURLs
                    let tinyImages: [TinyImage] = imageURLs
                        .filter { !importedURLs.contains($0) }
                        .map(TinyImage.init(url:))
                    store.images += tinyImages
                    if settings.autoProcessing {
                        Task {
                            await store.processImages(tinyImages)
                        }
                    }
                }
            } else {
                TableView(selections: $selections)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .padding(store.images.isEmpty ? .all : [])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: allowedTypes, isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
        }
        .toolbar {
            buildToolBar()
        }
        .sheet(isPresented: Binding(get: {
            settings.token.isEmpty
        }, set: { _ = $0 })) {
            InputAPIView()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let total = providers.count
        var loadCount = 0
        let autoProcessIfNeeded = {
            if loadCount == total {
                let importedURLs = self.importedURLs
                let tinyImages = urls
                    .filter { !importedURLs.contains($0) }
                    .map(TinyImage.init(url:))
                store.images += tinyImages
                if settings.autoProcessing {
                    await store.processImages(tinyImages)
                }
            }
        }

        providers.forEach { provider in
            if provider.hasOpenInPlaceItemConfirmingToContentType(.image) {
                _ = provider.loadFileRepresentation(for: .image, openInPlace: true) { url, _, _ in
                    Task { @MainActor in
                        url.map {
                            urls.append($0)
                        }
                        loadCount += 1
                        await autoProcessIfNeeded()
                    }
                }
            } else {
                guard let type = provider.registeredContentTypesForOpenInPlace.first else {
                    loadCount += 1
                    Task {
                        await autoProcessIfNeeded()
                    }
                    return
                }
                _ = provider.loadInPlaceFileRepresentation(forTypeIdentifier: type.identifier, completionHandler: { url, _, _ in
                    loadCount += 1
                    guard let url, url.hasDirectoryPath else {
                        Task {
                            await autoProcessIfNeeded()
                        }
                        return
                    }
                    Task { @MainActor in
                        urls = enumerateFiles(for: url)
                        await autoProcessIfNeeded()
                    }
                })
            }
        }

        return true
    }

    private func enumerateFiles(for directoryURL: URL) -> [URL] {
        var urls: [URL] = []
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: directoryURL, includingPropertiesForKeys: [.contentTypeKey]) {
            for file in enumerator {
                guard let fileURL = file as? URL else {
                    continue
                }
                guard let values = try? fileURL.resourceValues(forKeys: [.contentTypeKey]) else {
                    continue
                }
                if allowedImages.contains(where: { type in
                    values.contentType?.conforms(to: type) ?? false
                }) {
                    urls.append(fileURL)
                }
            }
        }

        return urls
    }

    @ToolbarContentBuilder
    private func buildToolBar() -> some ToolbarContent {
        ToolbarItem {
            ControlGroup {
                Button {
                    store.images.removeAll()
                } label: {
                    Label("Clear", systemImage: "paintbrush")
                }
                .help("Clear the list")
                .disabled(store.images.isEmpty)

                Button {
                    Task {
                        if selections.isEmpty {
                            await store.processImages(
                                store.images.filter(\.needProcess)
                            )
                        } else {
                            await store.processImages(
                                store.images.filter { selections.contains($0.id) }
                            )
                        }
                    }
                } label: {
                    Label("Optimize", systemImage: "checkmark.seal")
                }
                .help("Optimize or reoptimize images via TinyPNG API")
                .disabled(
                    (!store.needProcessImages ||
                    settings.autoProcessing) &&
                    selections.isEmpty
                )

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open settings view")
            }
        }
    }
}

extension NSItemProvider {
    func hasOpenInPlaceItemConfirmingToContentType(_ type: UTType) -> Bool {
        hasRepresentationConforming(toTypeIdentifier: type.identifier, fileOptions: .openInPlace)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsStore.shared)
            .environmentObject(DataStore())
    }
}

extension View {
    func debug(_ action: () -> Void) -> some View {
        action()
        return self
    }
}
