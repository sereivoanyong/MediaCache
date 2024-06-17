//
//  MediaCacheManager.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/21.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import UIKit

enum BoolValues {
    
    case `default`(Bool)    /// 默认
    case auto(Bool)         /// 自动
    case manual(Bool)       /// 手动
    
    var value: Bool {
        switch self {
        case .default(let b):   return b
        case .auto(let b):      return b
        case .manual(let b):    return b
        }
    }
}

let FileM = FileManager.default

final public class MediaCacheManager {

    /// shared instance, directory default NSTemporaryDirectory/MediaCache
    public static let `default` = MediaCacheManager(directoryURL: temporaryDirectoryURL.appendingPathComponent("SYMediaCache"))

    /// default NSTemporaryDirectory/SYMediaCache/
    public let directoryURL: URL

    /// default 1GB
    public var capacityLimit: Int = 1024 * 1024 * 1024 {
        didSet {
            checkAllow()
        }
    }
    
    /// default nil, fileName is original value
    public var fileNameConvertion: ((_ identifier: String) -> String)?
    
    /// default false
    public var isAutoCheckUsage: Bool = false
    
    /// default true
    public var allowWrite: Bool {
        get {
            lock.sync {
                return _allowWrite.value
            }
        }
        set {
            lock.sync {
                _allowWrite = .manual(newValue)
            }
        }
    }
    
    private var _allowWrite: BoolValues = .default(true)
    
    /// default none
    public static var logLevel: MediaCacheLogLevel {
        get { return mediaCacheLogLevel }
        set { mediaCacheLogLevel = newValue }
    }
    
    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        
        createCacheDirectory()
        
        checkAllow()
        
        NotificationCenter.default.addObserver(self, selector: #selector(autoCheckUsage), name: MediaFileHandle.didSynchronizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: MediaFileHandle.didSynchronizeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    lazy public private(set) var lru: MediaLRUConfiguration = {
        let fileURL = paths.lruFileURL()
        if let lruConfig = MediaLRUConfiguration.read(from: fileURL) {
            lruConfig.fileURL = fileURL
            return lruConfig
        }
        let lruConfig = MediaLRUConfiguration(fileURL: fileURL)
        lruConfig.synchronize()
        return lruConfig
    }()
    
    private var lastCheckTimeInterval: TimeInterval = Date().timeIntervalSince1970
    
    private var _downloadingURLs: [MediaCacheKey: MediaResource] = [:]

    private let lock = NSLock()
    
    private var reserveRequired = true
}

extension MediaCacheManager {
    
    private func checkAllow() {
        
        guard isAutoCheckUsage else { return }
        
        VLog(.info, "allow write: \(_allowWrite)")
        
        switch _allowWrite {
        case .default, .auto:
            if let availableCapacity = UIDevice.current.availableCapacity {
                _allowWrite = .auto(availableCapacity > capacityLimit)
                VLog(.info, "Auto \(allowWrite ? "enabled" : "disabled") allow write")
            }
        case .manual: 
            break
        }
    }
    
    @objc private func appDidBecomeActive() {
        checkAllow()
    }
    
    @objc private func autoCheckUsage() {
        guard isAutoCheckUsage else { return }
        
        let now = Date().timeIntervalSince1970
        guard now - lastCheckTimeInterval > 10 else { return }
        lastCheckTimeInterval = now
        
        checkUsage()
        checkAllow()
    }
}

extension MediaCacheManager {
    
    private func createCacheDirectory() {
        if !FileM.fileExists(atPath: directoryURL.path) {
            do {
                try FileM.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                VLog(.info, "Video Cache directory path: \(directoryURL.path)")
            } catch {
                VLog(.error, "create cache directory error: \(error)")
            }
        }
    }
    
    public func calculateSize() throws -> Int {
        let contents = try FileM.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.fileSizeKey], options: [])
        let calculateContent: (URL) -> Int = {
            guard let fileSize = try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return 0 }
            return fileSize
        }
        return contents.reduce(0) { $0 + calculateContent($1) }
    }
    
    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public func clean(_ resource: MediaResource, reserve: Bool = true) throws {
        VLog(.info, "clean: \(resource)")
        
        if let _ = downloadingResources[resource.cacheKey] {
            throw MediaCacheError.fileHandleWriting
        }
        
        let configFileURL = paths.configurationFileURL(for: resource)
        let videoFileURL = paths.videoFileURL(for: resource)

        let cleanAllClosure = { [weak self] in
            try FileM.removeItem(atPath: configFileURL.path)
            try FileM.removeItem(atPath: videoFileURL.path)
            self?.lru.delete(resource)
        }
        
        guard let config = paths.configuration(for: resource.cacheKey) else {
            try cleanAllClosure()
            return
        }
        
        let reservedLength = config.reservedLength
        
        guard reservedLength > 0
            else {
            try cleanAllClosure()
            return
        }
        
        guard reserve else {
            try cleanAllClosure()
            return
        }
        
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forUpdating: videoFileURL)
        } catch {
            try cleanAllClosure()
            return
        }
        
        do {
            try FileM.removeItem(atPath: configFileURL.path)
            if #available(iOS 13.0, *) {
                try fileHandle.truncate(atOffset: UInt64(reservedLength))
                try fileHandle.synchronize()
                try fileHandle.close()
            } else {
                fileHandle.truncateFile(atOffset: UInt64(reservedLength))
                fileHandle.synchronizeFile()
                fileHandle.closeFile()
            }
        } catch {
            try cleanAllClosure()
        }
    }
    
    /// clean all cache
    public func cleanAll() throws {
        reserveRequired = true
        
        let resources = downloadingResources

        guard resources.count > 0 else {
            try FileM.removeItem(at: directoryURL)
            createCacheDirectory()
            return
        }
        
        lru.deleteAll(without: resources)
        
        var downloadingResourcesByFileName: [String: MediaResource] = [:]
        for resource in resources.values {
            downloadingResourcesByFileName[paths.cacheFileName(for: resource)] = resource
            downloadingResourcesByFileName[paths.configFileName(for: resource)] = resource
        }
        
        let fileURLs = try FileM.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: []).filter { downloadingResourcesByFileName[$0.lastPathComponent] == nil }

        for fileURL in fileURLs {
            try FileM.removeItem(atPath: fileURL.path)
        }
    }
}

extension MediaCacheManager {
    
    func visit(_ resource: MediaResource) {
        lru.visit(resource)
    }
    
    func checkUsage() {
        
        guard let size = try? calculateSize() else { return }
        
        VLog(.info, "cache total size: \(size)")
        
        guard size > capacityLimit else { return }
        
        let oldestResources = lru.oldestResources(maxLength: 4, without: downloadingResources)
        
        guard oldestResources.count > 0 else { return }
        
        oldestResources.forEach { try? clean($0, reserve: reserveRequired) }

//        reserveRequired.toggle()
    }
}

extension MediaCacheManager {
    
    var paths: MediaCachePaths {
        return MediaCachePaths(directoryURL: directoryURL, convertion: fileNameConvertion)
    }
}

extension MediaCacheManager {
    
    func addDownloading(_ resource: MediaResource) {
        downloadingResources[resource.cacheKey] = resource
    }
    
    func removeDownloading(_ resource: MediaResource) {
        downloadingResources.removeValue(forKey: resource.cacheKey)
    }
    
    public var downloadingResources: [MediaCacheKey: MediaResource] {
        get {
            lock.sync {
                return _downloadingURLs
            }
        }
        set {
            lock.sync {
                _downloadingURLs = newValue
            }
        }
    }
}
