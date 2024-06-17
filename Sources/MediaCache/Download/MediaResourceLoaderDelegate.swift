//
//  MediaResourceLoaderDelegate.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

extension MediaResourceLoaderDelegate {

    var manager: MediaCacheManager { return mgr ?? MediaCacheManager.default }
}

final class MediaResourceLoaderDelegate: NSObject {

    private weak var mgr: MediaCacheManager?
    
    var allowsCellularAccess: Bool = true
    
    var useChecksum: Bool = false
    
    let resource: MediaResource

    let cacheFragments: [MediaFragment]

    var loaders: [URL: MediaLoader] = [:]
    
    init(manager: MediaCacheManager, resource: MediaResource, cacheFragments: [MediaFragment]) {
        self.mgr = manager
        self.resource = resource
        self.cacheFragments = cacheFragments
        super.init()
        manager.addDownloading(resource)
        checkConfigData()
    }

    deinit {
        VLog(.info, "VideoResourceLoaderDelegate deinit\n")
        loaders.removeAll()
        manager.removeDownloading(resource)
    }

    func cancel() {
        VLog(.info, "VideoResourceLoaderDelegate cancel\n")
        loaders.values.forEach { $0.cancel() }
        loaders.removeAll()
    }
}

extension MediaResourceLoaderDelegate {

    private func checkConfigData() {
        let paths = manager.paths
        
        let configuration = paths.configuration(for: resource)
        
        if configuration.fragments.isEmpty {
            checkAlreadyOverCache(resource: resource, paths: paths)
            return
        }
        
        let videoFileURL = paths.videoFileURL(for: resource)
        guard let videoResourceValues = try? videoFileURL.resourceValues(forKeys: [.fileSizeKey]) else { return }
        let videoFileSize = videoResourceValues.fileSize ?? 0
        guard let maxRange = configuration.fragments.sorted(by: { $0.upperBound > $1.upperBound }).first else { return }
        if videoFileSize != maxRange.upperBound {
            configuration.reset(fragment: MediaRange(0, videoFileSize))
            configuration.synchronize(to: paths.configurationFileURL(for: resource))
        }
    }
    
    private func checkAlreadyOverCache(resource: MediaResource, paths: MediaCachePaths) {
        VLog(.info, "Check already over cahce file")
        
        let configuration = paths.configuration(for: resource)
        
        guard configuration.fragments.isEmpty else { return }
        
        VLog(.info, "Found already over content info: \(configuration.contentInfo)")
        
        let videoFileURL = paths.videoFileURL(for: resource)
        let configurationFileURL = paths.configurationFileURL(for: resource)

        guard let videoResourceValues = try? videoFileURL.resourceValues(forKeys: [.fileSizeKey]) else {
            configuration.synchronize(to: configurationFileURL)
            return
        }

        let videoFileSize = videoResourceValues.fileSize ?? 0

        VLog(.data, "Found already over cache size: \(videoFileSize)")
        
        guard videoFileSize > 0 else {
            configuration.synchronize(to: configurationFileURL)
            return
        }
        
        configuration.reservedLength = videoFileSize
        configuration.add(fragment: MediaRange(0, videoFileSize))

        if !configuration.synchronize(to: configurationFileURL) {
            VLog(.error, "2 configuration synchronize failed, need delete its video file")
            do {
                try FileM.removeItem(atPath: videoFileURL.path)
                VLog(.info, "2 delete video: \(resource)")
            } catch {
                VLog(.error, "2 delete video: \(resource) failure: \(error)")
            }
        }
    }
}

extension MediaResourceLoaderDelegate: AVAssetResourceLoaderDelegate {

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        VLog(.info, "VideoResourceLoaderDelegate shouldWaitForLoadingOfRequestedResource loadingRequest: \(loadingRequest)\n")
        guard let resourceURL = loadingRequest.request.url, resourceURL.isCacheScheme else { return false }
        if let loader = loaders[resourceURL] {
            loader.add(loadingRequest: loadingRequest)
        } else {
            let newLoader = MediaLoader(
                paths: manager.paths,
                resource: resource,
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

extension MediaResourceLoaderDelegate: MediaLoaderDelegate {
    
    func loaderAllowWriteData(_ loader: MediaLoader) -> Bool {
        return manager.allowWrite
    }
}
