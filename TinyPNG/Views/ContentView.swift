//
//  ContentView.swift
//  TinyPNG
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

    var importedURLs: Set<TinyImage.ID> {
        Set(store.pngs.map(\.id))
    }

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            if store.pngs.isEmpty {
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
                    store.pngs += tinyImages
                    if settings.autoProcessing {
                        Task {
                            await processPNGs(tinyImages)
                        }
                    }
                }
            } else {
                TableView()
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .padding(store.pngs.isEmpty ? .all : [])
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
                store.pngs += tinyImages
                if settings.autoProcessing {
                    await processPNGs(tinyImages)
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
                    store.pngs.removeAll()
                } label: {
                    Label("Clear", systemImage: "paintbrush")
                }
                .help("Clear the list")
                .disabled(store.pngs.isEmpty)

                if !settings.autoProcessing {
                    Button {
                        Task {
                            await processPNGs(
                                store.pngs.filter(\.needProcess)
                            )
                        }
                    } label: {
                        Label("Optimize", systemImage: "checkmark.seal")
                    }
                    .help("Optimize pngs via TinyPNG")
                    .disabled(store.pngs.isEmpty)
                }

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open settings view")
            }
        }
    }

    private func processPNGs(_ pngs: [TinyImage]) async {
        await withTaskGroup(of: Void.self) { group in
            let urlSession = URLSession.shared
            for png in pngs {
                group.addTask(priority: .background) {
                    for await state in await ImageProcesser(store: settings).process(png, with: urlSession) {
                        await handlePNGStateChange(png, state: state)
                    }
                }
            }
        }
    }

    private func handlePNGStateChange(_ png: TinyImage, state: TinyImageState) async {
        let optimizedSize: UInt64?
        let moveFileError: Error?
        let targetURL: URL?
        if case .finished(let location) = state {
            let values = try? location.resourceValues(forKeys: [.fileSizeKey])
            optimizedSize = UInt64(values?.fileSize ?? 0)
            do {
                targetURL = try await moveDownloadedImage(location, for: png)
                moveFileError = nil
            } catch {
                moveFileError = error
                targetURL = nil
            }
        } else {
            optimizedSize = nil
            moveFileError = nil
            targetURL = nil
        }

        await MainActor.run {
            if let moveFileError {
                png.state = .error(moveFileError)
            } else {
                if let optimizedSize {
                    png.targetURL = targetURL
                    png.optimizedSize = optimizedSize
                }
                png.state = state
            }
        }
    }

    private func moveDownloadedImage(_ location: URL, for item: TinyImage) async throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: location.path) else {
            let error = NSError(domain: "cn.firestudio.tinypng", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "\(location) does not exists"
            ])
            throw error
        }

        guard !settings.override else {
            let backupURL = item.localURL.appendingPathExtension("bak")
            try fm.moveItem(at: item.localURL, to: backupURL)
            do {
                try fm.moveItem(at: location, to: item.localURL)
                try fm.removeItem(at: backupURL)
            } catch {
                if fm.fileExists(atPath: backupURL.path) {
                    try fm.moveItem(at: backupURL, to: item.localURL)
                }
                throw error
            }
            return item.localURL
        }

        guard let url = settings.directoryToSave else {
            let error = NSError(domain: "cn.firestudio.tinypng", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Directory not spcefied."
            ])
            throw error
        }

        var isDir = ObjCBool(false)
        if !fm.fileExists(atPath: url.path, isDirectory: &isDir) || !isDir.boolValue {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let ext = item.localURL.pathExtension
        let name = item.localURL.deletingPathExtension().lastPathComponent
        var index = 0
        repeat {
            var isDir = ObjCBool(false)
            let target = url
                .appendingPathComponent("\(name)\(index > 0 ? "(\(index))" : "")")
                .appendingPathExtension(ext)
            if !fm.fileExists(atPath: target.path, isDirectory: &isDir) || isDir.boolValue {
                try fm.moveItem(at: location, to: target)
                return target
            }
            index += 1
        } while true
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
            .environmentObject(SettingsStore())
    }
}

extension View {
    func debug(_ action: () -> Void) -> some View {
        action()
        return self
    }
}
