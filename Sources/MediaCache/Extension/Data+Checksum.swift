//
//  Data+CheckSum.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/12/10.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

extension Data {
    
    func checksum(split: Int = 1024 /* 1 KB */, vacuate: Int? = nil) -> Bool {
        return (self as NSData).checksum(split: split)
    }
}

extension NSData {
    
    func checksum(split: Int, vacuate: Int? = nil) -> Bool {

        if isEmpty {
            return false
        }
        
        let totalRange = MediaRange(0, count)

        var splitRanges = totalRange.split(limit: split).filter { $0.isValid }
        let vacuateCount = vacuate ?? Int(sqrt(Double(splitRanges.count)))

        let results: [MediaRange] = (0..<vacuateCount).compactMap { _ in
            let index = Int.random(in: splitRanges.indices)
            return splitRanges.remove(at: index)
        }
        
        for range in results {
            
            let r = NSRange(location: range.lowerBound, length: range.length)
            
            let data = subdata(with: r)
            
            guard data.count == r.length else {
                return false
            }
            
            let sum: Int64 = data.reduce(0) { $0 + Int64($1) }

            VLog(.data, "sub-range: \(r) checksum: \(sum) --> \(sum < r.length ? "invalid" : "valid")")
            
            if sum < r.length {
                return false
            }
        }
        
        return true
    }
}
