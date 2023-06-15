//
//  TinyImage.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/6/7.
//

import Foundation
import AppKit

enum TinyImageState: Comparable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.waiting, .waiting):
            return true
        case let (.uploading(p1), .uploading(p2)):
            return p1 == p2
        case let (.downloading(p1), .downloading(p2)):
            return p1 == p2
        case let (.finished(u1), .finished(u2)):
            return u1 == u2
        default:
            return false
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.orderValue < rhs.orderValue
    }

    case none
    case waiting
    case uploading(Double)
    case downloading(Double)
    case finished(URL)
    case error(Error?)

    var orderValue: Int {
        switch self {
        case .none:
            return 0
        case .waiting:
            return 1
        case .uploading:
            return 2
        case .downloading:
            return 3
        case .finished:
            return 4
        case .error:
            return 5
        }
    }

    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }
}

final class TinyImage: Identifiable, ObservableObject {
    var id: URL { localURL }
    let localURL: URL
    let fileSize: UInt64
    @Published var thumbnail: NSImage?
    @Published var optimizedSize: UInt64
    @Published var state: TinyImageState
    var targetURL: URL?

    var needProcess: Bool {
        switch state {
        case .none, .error:
            return true
        default:
            return false
        }
    }

    var imageName: String {
        localURL.lastPathComponent
    }

    var optimizedRate: Double {
        Double(fileSize - optimizedSize) / Double(fileSize)
    }

    init(localURL: URL, fileSize: UInt64, optimizedSize: UInt64 = 0, state: TinyImageState = .none) {
        self.localURL = localURL
        self.fileSize = fileSize
        self.optimizedSize = optimizedSize
        self.state = state
    }

    convenience init(url: URL) {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        self.init(localURL: url, fileSize: UInt64(values?.fileSize ?? 0))
    }
}

struct TinyPNGError: Decodable, LocalizedError {
    let error: String
    let message: String

    var failureReason: String { error }

    var errorDescription: String { message }
}
