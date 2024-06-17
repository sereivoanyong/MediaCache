//
//  VideoLRUConfiguration.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

extension MediaLRUConfiguration {
    
    /// visitTimes timesWeigth default 1, accessTime timeWeight default 2
    public func update(visitTimes timesWeigth: Int, accessTime timeWeight: Int) {
        self.useWeight = timesWeigth
        self.timeWeight = timeWeight
        synchronize()
    }
    
    @discardableResult
    public func visit(_ resource: MediaResource) -> Bool {
        VLog(.info, "use resource: \(resource)")
        return lock.sync {
            if let content = contents[resource.cacheKey] {
                content.use()
            } else {
                let content = LRUContent(resource: resource)
                contents[resource.cacheKey] = content
            }
            return synchronize()
        }
    }
    
    @discardableResult
    public func delete(_ resource: MediaResource) -> Bool {
        VLog(.info, "delete resource: \(resource)")
        return lock.sync {
            contents.removeValue(forKey: resource.cacheKey)
            return synchronize()
        }
    }
    
    @discardableResult
    public func deleteAll(without downloading: [MediaCacheKey: MediaResource]) -> Bool {
        lock.sync {
            contents = contents.filter { downloading[$0.key] != nil }
            return synchronize()
        }
    }
    
    @discardableResult
    public func synchronize() -> Bool {
        guard let fileURL else { return false }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            try data.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }
    
    // If accessTime weight is 1, visitTimes weight is 2
    // accessTime sorted:   [A, B, C, D, E, F]
    // accessTime weight:   [A(1), B(2), C(3), D(4), E(5), F(6)]
    // visitTimes sorted:   [C, E, D, F, A, B]
    // visitTimes weight:   [C(1), E(2), D(3), F(4), A(5), B(6)]
    // combine:             [A(1 + 5 * 2), B(2 + 6 * 2), C(3 + 1 * 2), D(4 + 3 * 2), E(5 + 2 * 2), F(6 + 4 * 2)]
    // result:              [A(11), B(14), C(5), D(10), E(9), F(14)]
    // result sorted:       [C(5), E(9), D(10), A(11), B(14), F(14)]
    // oldest:              C(5)
    
    public func oldestResources(maxLength: Int = 1, without downloading: [MediaCacheKey: MediaResource]) -> [MediaResource] {
        lock.sync {
            let urls = contents.filter { downloading[$0.key] == nil }.values

            VLog(.info, "urls: \(urls)")

            guard urls.count > maxLength else { return urls.compactMap { $0.resource } }

            urls.sorted { $0.playedAt < $1.playedAt }.enumerated().forEach { $0.element.weight += ($0.offset + 1) * timeWeight }
            urls.sorted { $0.count < $1.count }.enumerated().forEach { $0.element.weight += ($0.offset + 1) * useWeight }

            return urls.sorted(by: { $0.weight < $1.weight }).prefix(maxLength).compactMap { $0.resource }
        }
    }
}

final public class MediaLRUConfiguration {

    var timeWeight: Int = 2
    var useWeight: Int = 1
    
    var fileURL: URL?

    private var contents: [MediaCacheKey: LRUContent] = [:]

    static func read(from fileURL: URL) -> MediaLRUConfiguration? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(MediaLRUConfiguration.self, from: data)
            config.fileURL = fileURL
            return config
        } catch {
            print(error)
            return nil
        }
    }
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    private let lock = NSLock()
}

extension MediaLRUConfiguration: Codable {
  
    private enum CodingKeys: String, CodingKey {

        case timeWeight
        case useWeight
        case contents
    }
}

extension LRUContent {
    
    func use() {
        playedAt = Date()
        count += 1
    }
}

final class LRUContent {

    let resource: MediaResource

    var playedAt: Date

    var count: Int
    
    var weight: Int = 0
    
    init(resource: MediaResource) {
        self.resource = resource
        self.playedAt = Date()
        self.count = 1
    }
}

extension LRUContent: Codable {

    private enum CodingKeys: String, CodingKey {

        case resource
        case playedAt
        case count
    }
}
