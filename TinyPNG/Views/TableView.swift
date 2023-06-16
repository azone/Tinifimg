//
//  TableView.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/6/15.
//

import Foundation
import SwiftUI

let sizeStyle: ByteCountFormatStyle = .byteCount(style: .file)

struct TableView: View {
    @EnvironmentObject var store: DataStore

    @State private var sorter = [KeyPathComparator(\TinyImage.imageName)]
    @Binding private var selections: Set<TinyImage.ID>
    @State private var quickLookURL: URL?

    private var selectedItems: [TinyImage] {
        guard !selections.isEmpty else {
            return []
        }

        return store.images.filter {
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

    init(selections: Binding<Set<TinyImage.ID>>) {
        _selections = selections
    }

    var body: some View {
        Table(selection: $selections, sortOrder: $sorter) {
            TableColumn("Image Name", value: \.imageName) {
                NameColumn(item: $0)
            }

            TableColumn("Size", value: \.fileSize) { item in
                Text("\(item.fileSize.formatted(sizeStyle))")
            }

            TableColumn("Optimized Size", value: \.optimizedSize) { item in
                OptimizedSizeColumn(item: item)
            }

            TableColumn("State", value: \.state) { item in
                StateColumn(item: item)
            }
        } rows: {
            ForEach(store.images) { row in
                TableRow(row)
                    .itemProvider {
                        return row.targetURL.flatMap(NSItemProvider.init(contentsOf:))
                    }
            }
        }
        .onChange(of: sorter) {
            store.images.sort(using: $0)
        }
        .onDeleteCommand {
            store.images.removeAll { selections.contains($0.id) }
        }
        .onCopyCommand {
            selectedItems
                .compactMap(\.targetURL)
                .compactMap(NSItemProvider.init(contentsOf:))
        }
        .contextMenu(forSelectionType: TinyImage.ID.self) { _ in
            buildContextMenu()
        } primaryAction: { selections in
            let files = store.images.filter {
                selections.contains($0.id)
            }.map {
                $0.targetURL ?? $0.localURL
            }
            guard !files.isEmpty else { return }
            NSWorkspace.shared.activateFileViewerSelecting(files)
        }
        .quickLookPreview($quickLookURL, in: selectedURLs)
        .onAppear {
            sorter = []
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if !selections.isEmpty && event.keyCode == 49 {
                    quickLookURL = selectedURLs.first
                }
                return event
            }
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
                store.images.removeAll {
                    selections.contains($0.id)
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
}
