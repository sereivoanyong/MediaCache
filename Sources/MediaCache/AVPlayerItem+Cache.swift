//
//  AVPlayerItem+Cache.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation
import ObjectiveC.runtime

extension AVPlayerItem {

    private static var loaderDelegateKey: Void?
    var resourceLoaderDelegate: MediaResourceLoaderDelegate? {
        get { return objc_getAssociatedObject(self, &Self.loaderDelegateKey) as? MediaResourceLoaderDelegate }
        set { objc_setAssociatedObject(self, &Self.loaderDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }
}

extension NSObjectProtocol where Self: AVPlayerItem {

    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public static func caching(
        manager: MediaCacheManager = MediaCacheManager.default,
        url: URL,
        cacheKey: MediaCacheKey? = nil,
        cacheFragments: [MediaFragment] = [.prefix(.max)]
    ) -> Self {
        let cacheKey = cacheKey ?? url.absoluteString.md5

        let resource = MediaResource(cacheKey: cacheKey, url: url)
        manager.visit(resource)
        
        let resourceLoaderDelegate = MediaResourceLoaderDelegate(manager: manager, resource: resource, cacheFragments: cacheFragments)
        let urlAsset = AVURLAsset(url: resourceLoaderDelegate.resource.includeMediaCacheSchemeUrl, options: nil)
        urlAsset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: .main)
        
        let playerItem = Self.init(asset: urlAsset)
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        playerItem.resourceLoaderDelegate = resourceLoaderDelegate
        return playerItem
    }
    
    public func cacheCancel() {
        resourceLoaderDelegate?.cancel()
        resourceLoaderDelegate = nil
    }
    
    /// default is true
    public var allowsCellularAccess: Bool {
        get { return resourceLoaderDelegate?.allowsCellularAccess ?? true }
        set { resourceLoaderDelegate?.allowsCellularAccess = newValue }
    }
    
    /// default is false
    public var useChecksum: Bool {
        get { return resourceLoaderDelegate?.useChecksum ?? false }
        set { resourceLoaderDelegate?.useChecksum = newValue }
    }
}
