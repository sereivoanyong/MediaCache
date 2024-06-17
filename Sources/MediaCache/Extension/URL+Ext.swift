//
//  URL+Ext.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

extension URL {
    
    static let MediaCacheScheme = "MediaCache:"
    
    var isCacheScheme: Bool {
        return absoluteString.hasPrefix(URL.MediaCacheScheme)
    }
    
    var originUrl: URL {
        return URL(string: absoluteString.replacingOccurrences(of: URL.MediaCacheScheme, with: "")) ?? self
    }
}
