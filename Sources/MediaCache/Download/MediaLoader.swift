//
//  VideoLoader.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import AVFoundation

protocol MediaLoaderDelegate: AnyObject {
    
    func loaderAllowWriteData(_ loader: MediaLoader) -> Bool
}

extension MediaLoader {
    
    func add(loadingRequest: AVAssetResourceLoadingRequest) {
        let downloader = MediaDownloader(
            paths: paths,
            session: session,
            resource: resource,
            loadingRequest: loadingRequest,
            fileHandle: fileHandle,
            useChecksum: useChecksum
        )
        downloader.delegate = self
        downloaders.append(downloader)
        downloader.execute()
    }
    
    func remove(loadingRequest: AVAssetResourceLoadingRequest) {
        downloaders.removeAll {
            guard $0.loadingRequest == loadingRequest else { return false }
            $0.finish()
            return true
        }
    }
    
    func cancel() {
        VLog(.info, "VideoLoader cancel\n")
        downloaders.forEach { $0.cancel() }
        downloaders.removeAll()
    }
}

extension MediaLoader: MediaDownloaderDelegate {
    
    func downloaderAllowWriteData(_ downloader: MediaDownloader) -> Bool {
        return delegate?.loaderAllowWriteData(self) ?? false
    }
    
    func downloaderFinish(_ downloader: MediaDownloader) {
        downloader.finish()
        downloaders.removeAll { $0.loadingRequest == downloader.loadingRequest }
    }
    
    func downloader(_ downloader: MediaDownloader, finishWith error: Error?) {
        VLog(.error, "loader download failure: \(String(describing: error))")
        cancel()
    }
}

fileprivate struct DownloadQueue {
    
    static let shared = DownloadQueue()
    
    let queue: OperationQueue = OperationQueue()
    
    init() {
        queue.name = "com.video.cache.download.queue"
    }
}

final class MediaLoader: NSObject {

    weak var delegate: MediaLoaderDelegate?
    
    let paths: MediaCachePaths
    let resource: MediaResource
    let cacheFragments: [MediaFragment]
    let useChecksum: Bool
    
    var session: URLSession?
    
    init(
        paths: MediaCachePaths,
        resource: MediaResource,
        cacheFragments: [MediaFragment],
        allowsCellularAccess: Bool,
        useChecksum: Bool,
        delegate: MediaLoaderDelegate?
    ) {
        self.paths = paths
        self.resource = resource
        self.cacheFragments = cacheFragments
        self.useChecksum = useChecksum
        self.delegate = delegate
        super.init()
        
        let configuration = URLSessionConfiguration.default
//        configuration.timeoutIntervalForRequest = 30
//        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.networkServiceType = .video
        configuration.allowsCellularAccess = allowsCellularAccess
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: DownloadQueue.shared.queue)
    }
    
    deinit {
        VLog(.info, "VideoLoader deinit\n")
        cancel()
        session?.invalidateAndCancel()
        session = nil
    }

    lazy private var fileHandle: MediaFileHandle = MediaFileHandle(paths: paths, resource: resource, cacheFragments: cacheFragments)

    private var _downloaders: [MediaDownloader] = []
    private let lock = NSLock()
    private var downloaders: [MediaDownloader] {
        get {
            lock.sync {
                return _downloaders
            }
        }
        set { 
            lock.sync {
                _downloaders = newValue
            }
        }
    }
}

extension MediaLoader: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.useCredential, nil)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        downloaders.forEach {
            if $0.task == dataTask {
                $0.dataReceiver?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        downloaders.forEach {
            if $0.task == dataTask {
                $0.dataReceiver?.urlSession?(session, dataTask: dataTask, didReceive: data)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        downloaders.forEach {
            if $0.task == task {
                $0.dataReceiver?.urlSession?(session, task: task, didCompleteWithError: error)
            }
        }
    }
}
