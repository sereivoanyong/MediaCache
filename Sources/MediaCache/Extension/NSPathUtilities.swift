//
//  NSPathUtilities.swift
//
//  Created by Sereivoan Yong on 6/18/24.
//

import Foundation

var homeDirectoryURL: URL {
    return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
}

var temporaryDirectoryURL: URL {
    return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
}
