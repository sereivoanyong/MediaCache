//
//  VideoResourceLoaderDelegate.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

extension VideoResourceLoaderDelegate {
    
    var manager: MediaCacheManager { return mgr ?? MediaCacheManager.default }
}

final class VideoResourceLoaderDelegate: NSObject {

    private weak var mgr: MediaCacheManager?
    
    var allowsCellularAccess: Bool = true
    
    var useChecksum: Bool = false
    
    let url: MediaURL
    
    let cacheFragments: [MediaCacheFragment]
    
    var loaders: [URL: MediaLoader] = [:]

    deinit {
        VLog(.info, "VideoResourceLoaderDelegate deinit\n")
        loaders.removeAll()
        manager.removeDownloading(url: url)
    }
    
    init(manager: MediaCacheManager, url: MediaURL, cacheFragments: [MediaCacheFragment]) {
        self.mgr = manager
        self.url = url
        self.cacheFragments = cacheFragments
        super.init()
        manager.addDownloading(url: url)
        checkConfigData()
    }
    
    func cancel() {
        VLog(.info, "VideoResourceLoaderDelegate cancel\n")
        loaders.values.forEach { $0.cancel() }
        loaders.removeAll()
    }
}

extension VideoResourceLoaderDelegate {
    
    private func checkConfigData() {
        
        let `url` = self.url
        let paths = manager.paths
        
        let configuration = paths.configuration(for: url)
        
        if configuration.fragments.isEmpty {
            checkAlreadyOverCache(url: url, paths: paths)
            return
        }
        
        let videoFileURL = paths.videoFileURL(for: url)
        let videoFileSize = (try? videoFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard let maxRange = configuration.fragments.sorted(by: { $0.upperBound > $1.upperBound }).first else { return }
        if videoFileSize != maxRange.upperBound {
            configuration.reset(fragment: MediaRange(0, videoFileSize))
            configuration.synchronize(to: paths.configurationFileURL(for: url))
        }
    }
    
    private func checkAlreadyOverCache(url: MediaURL, paths: MediaCachePaths) {
        
        VLog(.info, "Check already over cahce file")
        
        let configuration = paths.configuration(for: url)
        
        guard configuration.fragments.isEmpty else { return }
        
        VLog(.info, "Found already over content info: \(configuration.contentInfo)")
        
        let configurationPath = paths.configurationFileURL(for: url)

        guard let videoAtt = try? FileM.attributesOfItem(atPath: paths.videoFileURL(for: url).path) as NSDictionary else {
            configuration.synchronize(to: configurationPath)
            return
        }
        
        let videoFileSize = Int(videoAtt.fileSize())

        VLog(.data, "Found already over cache size: \(videoFileSize)")
        
        guard videoFileSize > 0 else {
            configuration.synchronize(to: configurationPath)
            return
        }
        
        configuration.reservedLength = videoFileSize
        configuration.add(fragment: MediaRange(0, videoFileSize))

        if !configuration.synchronize(to: configurationPath) {
            VLog(.error, "2 configuration synchronize failed, need delete its video file")
            do {
                try FileM.removeItem(atPath: paths.videoFileURL(for: url).path)
                VLog(.info, "2 delete video: \(url)")
            } catch {
                VLog(.error, "2 delete video: \(url) failure: \(error)")
            }
        }
    }
}

extension VideoResourceLoaderDelegate: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        VLog(.info, "VideoResourceLoaderDelegate shouldWaitForLoadingOfRequestedResource loadingRequest: \(loadingRequest)\n")
        guard let resourceURL = loadingRequest.request.url, resourceURL.isCacheScheme else { return false }
        if let loader = loaders[resourceURL] {
            loader.add(loadingRequest: loadingRequest)
        } else {
            let newLoader = MediaLoader(
                paths: manager.paths,
                url: url,
                cacheFragments: cacheFragments,
                allowsCellularAccess: allowsCellularAccess,
                useChecksum: useChecksum,
                delegate: self
            )
            loaders[resourceURL] = newLoader
            newLoader.add(loadingRequest: loadingRequest)
        }
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        VLog(.info, "VideoResourceLoaderDelegate didCancel loadingRequest: \(loadingRequest)\n")
        guard let resourceURL = loadingRequest.request.url, resourceURL.isCacheScheme else { return }
        loaders[resourceURL]?.remove(loadingRequest: loadingRequest)
    }
}

extension VideoResourceLoaderDelegate: MediaLoaderDelegate {
    
    func loaderAllowWriteData(_ loader: MediaLoader) -> Bool {
        return manager.allowWrite
    }
}
