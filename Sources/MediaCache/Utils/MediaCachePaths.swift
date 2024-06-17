//
//  MediaCachePaths.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/11/26.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

struct MediaCachePaths {
    
    var directoryURL: URL
    var convertion: ((_ identifier: String) -> String)?
    
    init(directoryURL: URL, convertion: ((_ identifier: String) -> String)? = nil) {
        self.directoryURL = directoryURL
        self.convertion = convertion
    }
}

extension MediaCachePaths {
    
    func cacheFileNamePrefix(for url: MediaURLType) -> String {
        return convertion?(url.key) ?? url.key
    }
    
    func cacheFileNamePrefix(for cacheKey: MediaCacheKeyType) -> String {
        return convertion?(cacheKey) ?? cacheKey
    }
    
    func cacheFileName(for url: MediaURLType) -> String {
        return cacheFileNamePrefix(for: url).appending(".\(url.url.pathExtension)")
    }
    
    func configFileName(for url: MediaURLType) -> String {
        return cacheFileName(for: url).appending(".\(MediaCacheConfigFileExt)")
    }
    
    func contentFileName(for url: MediaURLType) -> String {
        return url.key.appending(".data")
    }
    
    func contentFileName(for cacheKey: MediaCacheKeyType) -> String {
        return cacheKey.appending(".data")
    }
}

extension MediaCachePaths {
    
    func lruFileURL() -> URL {
        return directoryURL.appendingPathComponent("\(lruFileName).\(MediaCacheConfigFileExt)")
    }
    
    func videoFileURL(for url: MediaURLType) -> URL {
        return directoryURL.appendingPathComponent(cacheFileName(for: url))
    }
    
    func configurationFileURL(for url: MediaURLType) -> URL {
        return directoryURL.appendingPathComponent(configFileName(for: url))
    }
    
    func contenInfoFileURL(for url: MediaURLType) -> URL {
        return directoryURL.appendingPathComponent(contentFileName(for: url))
    }
    
    public func cachedUrl(for cacheKey: MediaCacheKeyType) -> URL? {
        return configuration(for: cacheKey)?.url.includeMediaCacheSchemeUrl
    }
    
    func configuration(for url: MediaURLType) -> MediaConfiguration {
        if let config = NSKeyedUnarchiver.unarchiveObject(withFile: configurationFileURL(for: url).path) as? MediaConfiguration {
            return config
        }
        let newConfig = MediaConfiguration(url: url)
        if let ext = url.url.contentType {
            newConfig.contentInfo.type = ext
        }
        newConfig.synchronize(to: configurationFileURL(for: url))
        return newConfig
    }
    
    func contentInfoIsExists(for url: MediaURLType) -> Bool {
        let fileURL = contenInfoFileURL(for: url)
        return FileM.fileExists(atPath: fileURL.path)
    }
    
    func contentInfo(for url: MediaURLType) -> ContentInfo? {
        
        let fileURL = contenInfoFileURL(for: url)
        
        guard
            let jsonData = try? Data(contentsOf: fileURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: [.fragmentsAllowed, .mutableContainers, .mutableLeaves]),
            let jsonKeyValues = jsonObject as? Dictionary<String, Any>
            else { return nil }
        
        guard
            let type = jsonKeyValues["type"] as? String,
            let totalLength = jsonKeyValues["totalLength"] as? Int64
            else { return nil }
        
        let info = ContentInfo(type: type, byteRangeAccessSupported: true, totalLength: totalLength)
        
        return info
    }
}

extension MediaCachePaths {
    
    func configurationURL(for cacheKey: MediaCacheKeyType) -> URL? {
        guard let subpaths = FileM.subpaths(atPath: directoryURL.path) else { return nil }
        let filePrefix = cacheFileNamePrefix(for: cacheKey)
        guard let configFileName = subpaths.first(where: { $0.contains(filePrefix) && $0.hasSuffix("." + MediaCacheConfigFileExt) }) else { return nil }
        return directoryURL.appendingPathComponent(configFileName)
    }
    
    func configuration(for cacheKey: MediaCacheKeyType) -> MediaConfigurationType? {
        guard let url = configurationURL(for: cacheKey) else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? MediaConfigurationType
    }
}
