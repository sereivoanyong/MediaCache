//
//  String+Ext.swift
//  MediaCache
//
//  Created by SoalHuang on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import CryptoKit
import CommonCrypto

extension String {

    var md5: String {
        let data = Data(utf8)
        let hashData: any Sequence<UInt8>
        if #available(iOS 13.0, *) {
            hashData = Insecure.MD5.hash(data: data)
        } else {
            hashData = data.withUnsafeBytes { bytes -> [UInt8] in
                var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
                CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
                return hash
            }
        }
        return hashData.map { String(format: "%02x", $0) }.joined()
    }
}
