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
    
    func cacheFileNamePrefix(for cacheKey: MediaCacheKey) -> String {
        return convertion?(cacheKey) ?? cacheKey
    }
    
    func cacheFileName(for resource: MediaResource) -> String {
        return cacheFileNamePrefix(for: resource.cacheKey).appending(".\(resource.url.pathExtension)")
    }
    
    func configFileName(for resource: MediaResource) -> String {
        return cacheFileName(for: resource).appending(".\(MediaCacheConfigFileExt)")
    }
}

extension MediaCachePaths {
    
    func lruFileURL() -> URL {
        return directoryURL.appendingPathComponent("lru.\(MediaCacheConfigFileExt)")
    }
    
    func videoFileURL(for resource: MediaResource) -> URL {
        return directoryURL.appendingPathComponent(cacheFileName(for: resource))
    }
    
    func configurationFileURL(for resource: MediaResource) -> URL {
        return directoryURL.appendingPathComponent(configFileName(for: resource))
    }
    
    public func cachedUrl(for cacheKey: MediaCacheKey) -> URL? {
        return configuration(for: cacheKey)?.resource.includeMediaCacheSchemeUrl
    }
    
    func configuration(for resource: MediaResource) -> MediaConfiguration {
        let configurationFileURL = configurationFileURL(for: resource)
        if let data = try? Data(contentsOf: configurationFileURL) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let config = try decoder.decode(MediaConfiguration.self, from: data)
                return config
            } catch {
                print(error)
            }
        }
        let newConfig = MediaConfiguration(resource: resource)
        newConfig.synchronize(to: configurationFileURL)
        return newConfig
    }
}

extension MediaCachePaths {
    
    func configurationURL(for cacheKey: MediaCacheKey) -> URL? {
        guard let subpaths = FileM.subpaths(atPath: directoryURL.path) else { return nil }
        let filePrefix = cacheFileNamePrefix(for: cacheKey)
        guard let configFileName = subpaths.first(where: { $0.contains(filePrefix) && $0.hasSuffix(".\(MediaCacheConfigFileExt)") }) else { return nil }
        return directoryURL.appendingPathComponent(configFileName)
    }
    
    func configuration(for cacheKey: MediaCacheKey) -> MediaConfiguration? {
        guard let url = configurationURL(for: cacheKey), let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MediaConfiguration.self, from: data)
    }
}
