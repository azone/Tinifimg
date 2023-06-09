//
//  ContentView.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/5/30.
//

import SwiftUI
import QuickLook

struct ContentView: View {
    @EnvironmentObject var store: SettingsStore

    @State private var hideDashBorder: Bool = false
    @State private var pngs: [TinyImage] = [] {
        didSet {
            hideDashBorder = true
        }
    }
    @State private var isDropTarget = false
    @State private var sorter = [KeyPathComparator(\TinyImage.imageName)]
    @State private var showPngsPicker: Bool = false
    @State private var isProcessing: Bool = false
    @State private var selections = Set<TinyImage.ID>()
    @State private var quickLookURL: URL?
    @FocusState private var focused: Bool

    private var selectedItems: [TinyImage] {
        guard !selections.isEmpty else {
            return []
        }

        return pngs.filter {
            selections.contains($0.id)
        }
    }

    private var selectedURLs: [URL] {
        selectedItems.map(\.localURL)
    }

    private var optimizedURLs: [URL] {
        selectedItems
            .compactMap(\.targetURL)
    }
    
    var body: some View {
        ZStack {
            if pngs.isEmpty {
                emptyView()
            } else {
                tableView()
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .disabled(isProcessing)
        .padding($pngs.isEmpty ? .all : [])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: isProcessing ? [] : [.png], isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
        }
        .background {
            if !hideDashBorder {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isDropTarget ? Color.accentColor : Color.gray,
                        style: .init(lineWidth: 4, dash: [6], dashPhase: 0)
                    )
            }
        }
        .toolbar {
            buildToolBar()
        }
        .sheet(isPresented: Binding(get: {
            store.token.isEmpty
        }, set: { _ = $0 })) {
            InputAPIView()
        }
        .focused($focused)
        .onAppear {
            sorter = []
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if focused && !selections.isEmpty && event.keyCode == 49 {
                    quickLookURL = selectedURLs.first
                }
                return event
            }
        }
        .quickLookPreview($quickLookURL, in: selectedURLs)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !focused else { return false }

        pngs.removeAll()
        providers.forEach { provider in
            _ = provider.loadFileRepresentation(for: .png, openInPlace: true) { url, _, _ in
                Task { @MainActor in
                    url.map {
                        pngs.append(.init(url: $0))
                    }
                }
            }
        }
        return true
    }

    @ToolbarContentBuilder
    private func buildToolBar() -> some ToolbarContent {
        ToolbarItem {
            ControlGroup {
                Button {
                    pngs.removeAll()
                    hideDashBorder = false
                } label: {
                    Label("Clear", systemImage: "paintbrush")
                }
                .help("Clear the list")
                .disabled(pngs.isEmpty)

                Button {
                    Task {
                        await processPNGs()
                    }
                } label: {
                    Label("Optimize", systemImage: "checkmark.seal")
                }
                .help("Optimize pngs via TinyPNG")
                .disabled(pngs.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func emptyView() -> some View {
        ZStack {
            VStack(spacing: 20) {
                Image(systemName: "photo")
                    .imageScale(.large)
                Text("Please drag PNGs here!")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .font(.title)
        .fileImporter(isPresented: $showPngsPicker, allowedContentTypes: [.png], allowsMultipleSelection: true) { results in
            do {
                pngs = try results.get()
                    .map(TinyImage.init(url:))
            } catch {}
        }
        .onTapGesture {
            showPngsPicker = true
        }
    }

    @ViewBuilder
    private func buildContextMenu() -> some View {
        if selections.isEmpty {
            EmptyView()
        } else {
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects(selectedURLs as [NSURL])
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c")

            Button {
                pngs.removeAll {
                    selections.contains($0.id)
                }
                if pngs.isEmpty {
                    hideDashBorder = false
                }
            } label: {
                Label("Clear", systemImage: "paintbrush")
            }
            .keyboardShortcut(.delete)

            Button {
                if !selectedURLs.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(selectedURLs)
                }
            } label: {
                Text("Reveal in Finder")
            }

            if !optimizedURLs.isEmpty {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(optimizedURLs)
                } label: {
                    Text("Reveal optimized images in Finder")
                }
            }
        }
    }

    @ViewBuilder
    private func tableView() -> some View {
        Table(selection: $selections, sortOrder: $sorter) {
            TableColumn("Image Name", value: \.imageName)

            TableColumn("Size", value: \.fileSize) { item in
                Text("\(item.fileSize.formatted(.byteCount(style: .file)))")
            }

            TableColumn("Optimized Size", value: \.optimizedSize) { item in
                Text("\(item.optimizedSize.formatted(.byteCount(style: .file)))")
            }

            TableColumn("State", value: \.state) { item in
                StateColumn(item: item)
            }
        } rows: {
            ForEach(pngs) { row in
                TableRow(row)
                    .itemProvider {
                        return row.targetURL.flatMap(NSItemProvider.init(contentsOf:))
                    }
            }
        }
        .onChange(of: sorter) {
            pngs.sort(using: $0)
        }
        .onDeleteCommand {
            pngs.removeAll { selections.contains($0.id) }
            if pngs.isEmpty {
                hideDashBorder = false
            }
        }
        .onCopyCommand {
            selectedItems
                .compactMap(\.targetURL)
                .compactMap(NSItemProvider.init(contentsOf:))
        }
        .contextMenu(forSelectionType: TinyImage.ID.self) { _ in
            buildContextMenu()
        } primaryAction: { selections in
            let files = pngs.filter {
                selections.contains($0.id)
            }.map {
                $0.targetURL ?? $0.localURL
            }
            guard !files.isEmpty else { return }
            NSWorkspace.shared.activateFileViewerSelecting(files)
        }
    }

    private func processPNGs() async {
        isProcessing = true
        await withTaskGroup(of: Void.self) { group in
            let urlSession = URLSession.shared
            for png in pngs {
                group.addTask(priority: .background) {
                    for await state in await ImageProcesser(store: store).process(png, with: urlSession) {
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
                }
            }
        }
        isProcessing = false
    }

    private func moveDownloadedImage(_ location: URL, for item: TinyImage) async throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: location.path) else {
            let error = NSError(domain: "cn.firestudio.tinypng", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "\(location) does not exists"
            ])
            throw error
        }

        guard !store.override else {
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

        guard let url = store.directoryToSave else {
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

struct StateColumn: View {
    @StateObject var item: TinyImage

    @State private var popoverErrorItem: TinyImage?

    var body: some View {
        ZStack {
            switch item.state {
            case .waiting:
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
                    Text("Optimized \(item.optimizedRate.formatted(.percent.precision(.fractionLength(2))))")
                }
                .foregroundColor(.green)
            case .error:
                Button {
                    popoverErrorItem = item
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                .popover(item: $popoverErrorItem) { item in
                    if case .error(let error) = item.state {
                        Text("Error occurred: \(error?.localizedDescription ?? "Unknown")")
                            .padding()
                    } else {
                        Text("Unknown error occurred")
                            .padding()
                    }
                }
            }
        }
    }
}

struct InputAPIView: View {
    @EnvironmentObject var store: SettingsStore

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
                    store.token = token
                }

            HStack {
                Spacer()
                Button("Done") {
                    store.token = token
                }
            }
        }
        .padding()
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
