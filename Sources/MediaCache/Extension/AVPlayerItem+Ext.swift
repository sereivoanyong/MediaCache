//
//  AVPlayerItem+Ext.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

extension AVPlayerItem {
    
    private static var loaderDelegateKey: Void?
    var resourceLoaderDelegate: VideoResourceLoaderDelegate? {
        get { return objc_getAssociatedObject(self, &Self.loaderDelegateKey) as? VideoResourceLoaderDelegate }
        set { objc_setAssociatedObject(self, &Self.loaderDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }
}
