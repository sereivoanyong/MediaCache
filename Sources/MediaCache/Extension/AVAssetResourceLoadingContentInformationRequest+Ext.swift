//
//  AVAssetResourceLoadingContentInformationRequest+Ext.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/26.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

extension AVAssetResourceLoadingContentInformationRequest {
    
    func update(contentInfo: ContentInfo) {
        guard contentType == nil && contentInfo.contentLength > 0 else { return }
        contentType = contentInfo.contentType
        contentLength = Int64(contentInfo.contentLength)
        isByteRangeAccessSupported = contentInfo.isByteRangeAccessSupported
        VLog(.info, "content info: \(contentInfo)")
    }
}
