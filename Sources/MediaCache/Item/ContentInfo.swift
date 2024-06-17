//
//  ContentInfo.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import MobileCoreServices
import UniformTypeIdentifiers

struct ContentInfo {

    var contentType: String?
    let contentLength: Int
    let isByteRangeAccessSupported: Bool
}

extension ContentInfo {

    init(response: HTTPURLResponse) {
      let allHeaderFields = response.allHeaderFields
      // content-type field cannot be used.
      // See: https://stackoverflow.com/a/60298272/11235826
      if let mimeType = response.mimeType {
        if #available(iOS 14.0, *) {
            self.contentType = UTType(mimeType: mimeType)?.identifier
        } else {
            self.contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?.takeRetainedValue() as String?
        }
      } else {
          self.contentType = nil
      }
      self.contentLength = value(forHTTPHeaderField: "content-range", in: allHeaderFields)?.split(separator: "/").last.flatMap { Int($0) } ?? 0
      self.isByteRangeAccessSupported = value(forHTTPHeaderField: "accept-ranges", in: allHeaderFields)?.contains("bytes") ?? false
    }
}

extension ContentInfo: Codable {

    private enum CodingKeys: String, CodingKey {

        case contentType
        case contentLength
        case isByteRangeAccessSupported
    }
}

private func value(forHTTPHeaderField field: String, in allHeaderFields: [AnyHashable: Any]) -> String? {
    for (key, value) in allHeaderFields {
        if (key as? String)?.lowercased() == field {
          return value as? String
        }
    }
    return nil
}
