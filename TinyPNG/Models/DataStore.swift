//
//  DataStore.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/6/15.
//

import Foundation

final class DataStore: ObservableObject {
    @Published var pngs: [TinyImage] = []

    private let settings: SettingsStore = .shared

    func processPNGs(_ pngs: [TinyImage]) async {
        await withTaskGroup(of: Void.self) { group in
            let urlSession = URLSession.shared
            for png in pngs {
                group.addTask(priority: .background) {
                    for await state in ImageProcesser().process(png, with: urlSession) {
                        await self.handlePNGStateChange(png, state: state)
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