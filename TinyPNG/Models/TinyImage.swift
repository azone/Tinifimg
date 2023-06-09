//
//  TinyImage.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/6/7.
//

import Foundation

enum TinyImageState: Comparable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
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

    case waiting
    case uploading(Double)
    case downloading(Double)
    case finished(URL)
    case error(Error?)

    var orderValue: Int {
        switch self {
        case .waiting:
            return 0
        case .uploading:
            return 1
        case .downloading:
            return 2
        case .finished:
            return 3
        case .error:
            return 4
        }
    }
}

final class TinyImage: Identifiable, ObservableObject {
    let id = UUID()
    let localURL: URL
    let fileSize: UInt64
    @Published var optimizedSize: UInt64
    @Published var state: TinyImageState = .waiting
    var targetURL: URL?

    var imageName: String {
        localURL.lastPathComponent
    }

    var optimizedRate: Double {
        Double(fileSize - optimizedSize) / Double(fileSize)
    }

    init(localURL: URL, fileSize: UInt64, optimizedSize: UInt64 = 0, state: TinyImageState = .waiting) {
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
