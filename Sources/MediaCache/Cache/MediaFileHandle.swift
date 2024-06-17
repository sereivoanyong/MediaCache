//
//  VideoFileHandle.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import UIKit

internal let PacketLimit: Int64 = Int64(1).MB

protocol MediaFileHandleType {
    
    var configuration: MediaConfiguration { get }
    
    func actions(for range: MediaRange) -> [Action]
    
    func readData(for range: MediaRange) throws -> Data
    
    func writeData(data: Data, for range: MediaRange) throws
    
    @discardableResult
    func synchronize(notify: Bool) throws -> Bool
    
    func close() throws
}

extension MediaFileHandleType {
    
    var isNeedUpdateContentInfo: Bool { return configuration.contentInfo.totalLength <= 0 }
}

class MediaFileHandle {
    
    let url: MediaURLType
    
    let paths: MediaCachePaths
    
    let cacheFragments: [MediaCacheFragment]
    
    let fileURL: URL

    let configuration: MediaConfiguration
    
    deinit {
        do {
            try synchronize(notify: false)
            try close()
        } catch {
            VLog(.error, "fileHandle synchronize and close failure: \(error)")
        }
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    init(paths: MediaCachePaths, url: MediaURLType, cacheFragments: [MediaCacheFragment]) {
        
        self.paths = paths
        self.url = url
        self.cacheFragments = cacheFragments
        
        fileURL = paths.videoFileURL(for: url)

        VLog(.info, "Video path: \(fileURL)")
        
        if !FileM.fileExists(atPath: fileURL.path) {
            FileM.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        configuration = paths.configuration(for: url)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    private lazy var readHandle = try? FileHandle(forReadingFrom: fileURL)
    private lazy var writeHandle = try? FileHandle(forWritingTo: fileURL)

    private var isWriting: Bool = false
    
    private let lock = NSLock()
}

extension MediaFileHandle {
    
    static let VideoURLKey: String = "VideoURLKey"
    
    static let didSynchronizeNotification: NSNotification.Name = NSNotification.Name("VideoFileHandle.didSynchronizeNotification")
}

extension MediaFileHandle: MediaFileHandleType {
    
    var contentInfo: ContentInfo {
        get { return configuration.contentInfo }
        set {
            configuration.contentInfo = newValue
            configuration.synchronize(to: paths.configurationFileURL(for: url))
        }
    }
    
    func actions(for range: MediaRange) -> [Action] {
        
        guard range.isValid else { return [] }
        
        let localRanges = configuration.overlaps(range).compactMap { $0.clamped(to: range) }.split(limit: PacketLimit).filter { $0.isValid }
        
        var actions: [Action] = []
        
        let localActions: [Action] = localRanges.compactMap { .local($0) }
        actions.append(contentsOf: localActions)
        
        guard actions.count > 0 else {
            actions.append(.remote(range))
            return actions
        }
        
        let remoteActions: [Action] = range.subtracting(ranges: localRanges).compactMap { .remote($0) }
        actions.append(contentsOf: remoteActions)
        
        return actions.sorted(by: { $0 < $1 })
    }
    
    func readData(for range: MediaRange) throws -> Data {
        
        lock.lock()
        defer { lock.unlock() }
        
        let data: Data
        if #available(iOS 13.0, *) {
            try readHandle?.seek(toOffset: UInt64(range.lowerBound))
            if #available(iOS 13.4, *) {
                data = try readHandle?.read(upToCount: Int(range.length)) ?? Data()
            } else {
                data = readHandle?.readData(ofLength: Int(range.length)) ?? Data()
            }
        } else {
            readHandle?.seek(toFileOffset: UInt64(range.lowerBound))
            data = readHandle?.readData(ofLength: Int(range.length)) ?? Data()
        }
        return data
    }
    
    func writeData(data: Data, for range: MediaRange) throws {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let handle = writeHandle else { return }
        
        let containsRanges = cacheFragments.compactMap { $0.ranges(for: contentInfo.totalLength) }
        
        guard containsRanges.overlaps(range) else { return }
        
        isWriting = true
        
        VLog(.data, "write data: \(data), for: \(range)")
        
        if #available(iOS 13.0, *) {
            try handle.seek(toOffset: UInt64(range.lowerBound))
            if #available(iOS 13.4, *) {
                try handle.write(contentsOf: data)
            } else {
                handle.write(data)
            }
        } else {
            handle.seek(toFileOffset: UInt64(range.lowerBound))
            handle.write(data)
        }
        
        configuration.add(fragment: range)
    }
    
    @discardableResult
    func synchronize(notify: Bool = true) throws -> Bool {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let handle = writeHandle else { return false }
        
        if #available(iOS 13.0, *) {
            try handle.synchronize()
        } else {
            handle.synchronizeFile()
        }
        
        let configSyncResult = configuration.synchronize(to: paths.configurationFileURL(for: url))

        if notify {
            NotificationCenter.default.post(name: MediaFileHandle.didSynchronizeNotification,
                                            object: nil,
                                            userInfo: [MediaFileHandle.VideoURLKey: self.url])
        }
        
        return configSyncResult
    }
    
    func close() throws {
        if #available(iOS 13.4, *) {
            try readHandle?.close()
            try writeHandle?.close()
        } else {
            readHandle?.closeFile()
            writeHandle?.closeFile()
        }
    }
}

extension MediaFileHandle {
    
    @objc
    func applicationDidEnterBackground() {
        guard isWriting else { return }
        do {
            try synchronize()
        } catch {
            VLog(.error, "fileHandel did enter background synchronize failure: \(error)")
        }
    }
}
