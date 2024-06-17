//
//  ViewController.swift
//  MediaCacheDemo
//
//  Created by SoalHunag on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import MediaCache

private let MediaCacheVersionKey = "MediaCacheVersionKey"

class ViewController: UIViewController {
    
    func setupMediaCache() {
        
        MediaCacheManager.logLevel = .request
        
        MediaCacheManager.default.capacityLimit = 1024 * 1024 * 1024 // 1 GB
        
        let version = 1
        
        let savedVersion = UserDefaults.standard.integer(forKey: MediaCacheVersionKey)
        if savedVersion < version {
            try? MediaCacheManager.default.cleanAll()
            UserDefaults.standard.set(version, forKey: MediaCacheVersionKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMediaCache()
        
        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        
//        let url = URL(string: "https://vod.putaocdn.com/IMG_4449.MOV?auth_key=1579155925-3012-0-36f3aa6455033a9b078ad93eef7dcdea")!
//        let url = URL(string: "https://druryunb3e1cw.cloudfront.net/kilo-travel/files/2024/06/07/65e6ef7f21c1060d49c19571/71abefc3-b4b4-4e3f-8309-a0149507a414.mov")!
//        let url = URL(string: "https://druryunb3e1cw.cloudfront.net/kilo-travel/files/2024/06/11/65e6ef7f21c1060d49c19571/b8fd661b-8ec1-481e-8290-1cacac94f97e.mov")!
//        let url = URL(string: "https://files.testfile.org/Video%20MP4%2FRiver%20-%20testfile.org.mp4")!
        let url = URL(string: "https://files.testfile.org/Video%20MP4%2FInk%20-%20testfile.org.mp4")!
        let cacheItem = AVPlayerItem.caching(url: url)
        
        playerViewController.player = AVPlayer(playerItem: cacheItem)
        playerViewController.player?.play()

//      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//        try? MediaCacheManager.default.cleanAll()
//      }
    }
    
    lazy var playerViewController: AVPlayerViewController = AVPlayerViewController()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerViewController.view.frame = view.bounds
    }
}

