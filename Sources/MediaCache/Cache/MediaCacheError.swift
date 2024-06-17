//
//  MediaCacheError.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/26.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

enum MediaCacheError: LocalizedError, CustomNSError {

    static let errorDomain: String = "com.video.cache.domain"

    case badUrl
    case dataRequestNull
    case notMedia
    
    case fileHandleWriting
    case cancelled
    
    var errorCode: Int {
        switch self {
        case .badUrl:               return NSURLErrorBadURL
        case .dataRequestNull:      return NSURLErrorUnknown
        case .notMedia:             return NSURLErrorResourceUnavailable
        case .fileHandleWriting:    return NSURLErrorCannotWriteToFile
        case .cancelled:            return NSURLErrorCancelled
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .badUrl:               return "bad url"
        case .dataRequestNull:      return "data request is null"
        case .notMedia:             return "resource is not media"
        case .fileHandleWriting:    return "file handle writing"
        case .cancelled:            return "cancelled"
        }
    }
}
