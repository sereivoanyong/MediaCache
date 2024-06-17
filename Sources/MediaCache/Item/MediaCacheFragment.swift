//
//  MediaFragment.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/12/13.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

public enum MediaFragment {
    
    case prefix(Int)
    case suffix(Int)
    case range(MediaRange)
}

extension MediaFragment {
    
    func ranges(for totalLength: Int) -> MediaRange {
        switch self {
        case .prefix(let bounds):  
            return 0...bounds
        case .suffix(let bounds):   
            return max(0, totalLength - bounds)...totalLength
        case .range(let range):     
            return range
        }
    }
}
