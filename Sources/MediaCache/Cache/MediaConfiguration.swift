//
//  Configuration.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/21.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

final class MediaConfiguration: CustomStringConvertible {

    let url: MediaURL

    var contentInfo: ContentInfo

    var reservedLength: Int = 0

    var fragments: [MediaRange] = []

    var lastTimeInterval: Date = Date()

    init(url: MediaURL) {
        self.url = MediaURL(cacheKey: url.cacheKey, url: url.url)
        self.contentInfo = ContentInfo(contentType: nil, contentLength: 0, isByteRangeAccessSupported: false)
    }
    
    private let lock = NSLock()
    
    var description: String {
        return ["url": url, "contentInfo": contentInfo, "reservedLength": reservedLength, "lastTimeInterval": lastTimeInterval, "fragments": fragments].description
    }
}

extension MediaConfiguration: Codable {

    private enum CodingKeys: String, CodingKey {

        case url
        case contentInfo
        case reservedLength
        case lastTimeInterval
        case fragments
    }
}

extension MediaConfiguration {
    
    @discardableResult
    func synchronize(to fileURL: URL) -> Bool {
        lock.sync {
            lastTimeInterval = Date()
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
    }
    
    func overlaps(_ range: MediaRange) -> [MediaRange] {
        lock.sync {
            return fragments.overlaps(range)
        }
    }
    
    func reset(fragment: MediaRange) {
        VLog(.data, "reset fragment: \(fragment)")
        lock.sync {
            fragments = [fragment]
        }
    }
    
    func add(fragment: MediaRange) {
        VLog(.data, "add fragment: \(fragment)")
        lock.sync {
            guard fragment.isValid else { return }
            fragments = fragments.union(fragment)
        }
    }
}
