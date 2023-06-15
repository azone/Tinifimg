//
//  ImageUploader.swift
//  TinyPNG
//
//  Created by Logan Wang on 2023/5/30.
//

import Foundation
import Combine


final class ImageProcesser: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {
    private let settings: SettingsStore = .shared

    let baseURL: URL = URL(string: "https://api.tinify.com").unsafelyUnwrapped

    private var continuation: AsyncStream<TinyImageState>.Continuation?
    private var cancellables = Set<AnyCancellable>()
    private var downloadTask: URLSessionDownloadTask?
    private var responseData: Data = Data()

    private lazy var requestForUpload: URLRequest = {
        let uploadURL = baseURL.appending(path: "shrink")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        updateHeader(for: &request)

        return request
    }()

    private func updateHeader(for request: inout URLRequest) {
        let apiKey = "api:\(settings.token)"
        let base64Key = apiKey.data(using: .utf8)?.base64EncodedString() ?? ""
        request.setValue("Basic \(base64Key)", forHTTPHeaderField: "Authorization")
    }

    func process(_ tinyImage: TinyImage, with urlSession: URLSession) -> AsyncStream<TinyImageState> {
        var request = requestForUpload
        request.httpBodyStream = .init(url: tinyImage.localURL)
        let task = urlSession.dataTask(with: request)
        task.delegate = self
        task.progress.publisher(for: \.fractionCompleted)
            .sink { [weak self] in
                self?.continuation?.yield(.uploading($0))
            }
            .store(in: &self.cancellables)
        DispatchQueue.main.async {
            tinyImage.state = .waiting
        }

        return .init { continuation in
            guard FileManager.default.fileExists(atPath: tinyImage.localURL.path) else {
                let error = NSError(domain: "cn.firestudio.tinypng", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "\(tinyImage.localURL) does not exists"
                ])
                continuation.yield(.error(error))
                continuation.finish()
                return
            }
            self.continuation = continuation
            continuation.onTermination = { [weak self] in
                if case .cancelled = $0 {
                    task.cancel()
                    self?.downloadTask?.cancel()
                }
            }
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        if let response = response as? HTTPURLResponse {
            if let compressedCount = response.allHeaderFields["compression-count"] as? String,
               let count = Int(compressedCount) {
                DispatchQueue.main.async {
                    self.settings.compressedCount = count
                }
            }
            
            if 200..<300 ~= response.statusCode,
               let location = response.allHeaderFields["Location"] as? String,
               let url = URL(string: location) {
                downloadTask = session.downloadTask(with: .init(url: url))
                downloadTask?.delegate = self
                downloadTask?.progress.publisher(for: \.fractionCompleted)
                    .sink { [weak self] in
                        self?.continuation?.yield(.downloading($0))
                    }
                    .store(in: &cancellables)
                downloadTask?.resume()
            }
        }
        return .allow
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        continuation?.yield(.finished(location))
        Thread.sleep(forTimeInterval: 0.1) // fix downloaded file removed before moving
        continuation?.finish()
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        continuation?.yield(.error(error))
        continuation?.finish()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.yield(.error(error))
            continuation?.finish()
        } else {
            if task is URLSessionDataTask {
                let decoder = JSONDecoder()
                if let error = try? decoder.decode(TinyPNGError.self, from: responseData) {
                    downloadTask?.cancel()
                    continuation?.yield(.error(error))
                    continuation?.finish()
                }
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseData.append(data)
    }
}
