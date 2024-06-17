//
//  CodingRange.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/3/15.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

public typealias MediaRange = ClosedRange<Int64>

class CodingRange: NSObject, NSCoding {
    
    var lowerBound: Int64
    var upperBound: Int64

    init(lowerBound: Int64, upperBound: Int64) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
    
    required init?(coder aDecoder: NSCoder) {
        lowerBound = aDecoder.decodeInt64(forKey: "lowerBound")
        upperBound = aDecoder.decodeInt64(forKey: "upperBound")
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(lowerBound, forKey: "lowerBound")
        aCoder.encode(upperBound, forKey: "upperBound")
    }
    
    override var description: String {
        return "(\(lowerBound)...\(upperBound))"
    }
}
