//
//  MediaResource.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import UIKit

let MediaCacheConfigFileExt = "json"

public typealias MediaRange = ClosedRange<Int>

public typealias MediaCacheKey = String

public struct MediaResource: Codable {

    public let cacheKey: MediaCacheKey

    public let url: URL

    public var includeMediaCacheSchemeUrl: URL {
        return URL(string: URL.MediaCacheScheme + url.absoluteString)!
    }
}
