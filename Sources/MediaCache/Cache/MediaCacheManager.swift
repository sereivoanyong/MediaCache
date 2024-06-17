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

var temporaryDirectoryURL: URL {
    return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
}

let FileM = FileManager.default

public class MediaCacheManager: NSObject {
    
    /// shared instance, directory default NSTemporaryDirectory/MediaCache
    public static let `default` = MediaCacheManager(directoryURL: temporaryDirectoryURL.appendingPathComponent("/soso/MediaCache"))

    /// default NSTemporaryDirectory/MediaCache/
    public let directoryURL: URL

    /// default 1GB
    public var capacityLimit: Int64 = Int64(1).GB {
        didSet { checkAllow() }
    }
    
    /// default nil, fileName is original value
    public var fileNameConvertion: ((_ identifier: String) -> String)?
    
    /// default false
    public var isAutoCheckUsage: Bool = false
    
    /// default true
    public var allowWrite: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return allowWrite_.value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            allowWrite_ = .manual(newValue)
        }
    }
    
    private var allowWrite_: BoolValues = .default(true)
    
    /// default none
    public static var logLevel: MediaCacheLogLevel {
        get { return mediaCacheLogLevel }
        set { mediaCacheLogLevel = newValue }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: MediaFileHandle.didSynchronizeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    public init(directoryURL: URL) {

        self.directoryURL = directoryURL

        super.init()
        
        createCacheDirectory()
        
        checkAllow()
        
        NotificationCenter.default.addObserver(self, selector: #selector(autoCheckUsage), name: MediaFileHandle.didSynchronizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private lazy var lru: MediaLRUConfiguration = {
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
    
    private var downloadingUrls_: [MediaCacheKeyType: MediaURLType] = [:]
    
    private let lock = NSLock()
    
    private var reserveRequired = true
}

extension MediaCacheManager {
    
    public var lruConfig: MediaLRUConfigurationType { return lru }
}

extension MediaCacheManager {
    
    private func checkAllow() {
        
        guard isAutoCheckUsage else { return }
        
        VLog(.info, "allow write: \(allowWrite_)")
        
        switch allowWrite_ {
        case .default, .auto:
            if let availableCapacity = UIDevice.current.availableCapacity {
                allowWrite_ = .auto(availableCapacity > capacityLimit)
                VLog(.info, "Auto \(allowWrite ? "enabled" : "disabled") allow write")
            }
        case .manual: break
        }
    }
    
    @objc
    private func appDidBecomeActive() {
        checkAllow()
    }
    
    @objc
    private func autoCheckUsage() {
        
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
    
    public func calculateSize() throws -> UInt64 {
        let contents = try FileM.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.fileSizeKey], options: [])
        let calculateContent: (URL) -> Int = {
            guard let fileSize = try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return 0 }
            return fileSize
        }
        return UInt64(contents.reduce(0) { $0 + calculateContent($1) })
    }
    
    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public func clean(url: MediaURLType, reserve: Bool = true) throws {
        
        VLog(.info, "clean: \(url)")
        
        if let _ = downloadingUrls[url.key] {
            throw MediaCacheErrors.fileHandleWriting.error
        }
        
        let infoFileURL = paths.contenInfoFileURL(for: url)
        let configFileURL = paths.configurationFileURL(for: url)
        let videoFileURL = paths.videoFileURL(for: url)

        let cleanAllClosure = { [weak self] in
            try FileM.removeItem(atPath: infoFileURL.path)
            try FileM.removeItem(atPath: configFileURL.path)
            try FileM.removeItem(atPath: videoFileURL.path)
            self?.lru.delete(url: url)
        }
        
        guard let config = paths.configuration(for: infoFileURL.path) else {
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
        
        let urls = downloadingUrls
        
        guard urls.count > 0 else {
            try FileM.removeItem(at: directoryURL)
            createCacheDirectory()
            return
        }
        
        lru.deleteAll(without: urls)
        
        var downloadingURLs: [MediaCacheKeyType: MediaURLType] = [:]
        urls.forEach {
            downloadingURLs[paths.cacheFileName(for: $0.value)] = $0.value
            downloadingURLs[paths.configFileName(for: $0.value)] = $0.value
            downloadingURLs[paths.contenInfoFileURL(for: $0.value).path] = $0.value
        }
        
        let contentURLs = try FileM.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil).filter { downloadingURLs[$0.path] == nil }

        for contentURL in contentURLs {
            try FileM.removeItem(atPath: contentURL.path)
        }
    }
}

extension MediaCacheManager {
    
    func visit(url: MediaURLType) {
        lru.visit(url: url)
    }
    
    func checkUsage() {
        
        guard let size = try? calculateSize() else { return }
        
        VLog(.info, "cache total size: \(size)")
        
        guard size > capacityLimit else { return }
        
        let oldestUrls = lru.oldestURL(maxLength: 4, without: downloadingUrls)
        
        guard oldestUrls.count > 0 else { return }
        
        oldestUrls.forEach { try? clean(url: $0, reserve: reserveRequired) }
        
//        reserveRequired.toggle()
    }
}

extension MediaCacheManager {
    
    var paths: MediaCachePaths {
        return MediaCachePaths(directoryURL: directoryURL, convertion: fileNameConvertion)
    }
}

extension MediaCacheManager {
    
    func addDownloading(url: MediaURLType) {
        downloadingUrls[url.key] = url
    }
    
    func removeDownloading(url: MediaURLType) {
        downloadingUrls.removeValue(forKey: url.key)
    }
    
    public var downloadingUrls: [MediaCacheKeyType: MediaURLType] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return downloadingUrls_
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            downloadingUrls_ = newValue
        }
    }
}
