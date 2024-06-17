//
//  VURL.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import UIKit

public typealias MediaCacheKey = String

let MediaCacheConfigFileExt = "json"

public struct MediaURL: Codable {

    public let cacheKey: MediaCacheKey

    public let url: URL

    public var includeMediaCacheSchemeUrl: URL {
        return URL(string: URL.MediaCacheScheme + url.absoluteString)!
    }
}
