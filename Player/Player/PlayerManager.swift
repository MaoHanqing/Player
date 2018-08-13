//
//
//  Created by hanqing.mao on 2018/7/20.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import AVFoundation
import Foundation

struct PlayerError {
    enum PlayerErrorCode: Int {
        case loadingFail = 400
        case emptyURL = 401
    }
    static let PlayerErrorDomain = "playerDomain"
    static func getNetworkLoadFailError() -> Error {
        return self.setError(info: "loading fail,server error", errorCode: PlayerErrorCode.loadingFail)
    }
    static func getEmptyURLError() -> Error {
        return self.setError(info: "url is empty", errorCode: PlayerErrorCode.emptyURL)
    }
    static func setError(info: String, errorCode: PlayerErrorCode) -> Error {
        let errorInfo = ["errMsg": info]
        let error = NSError(domain: PlayerErrorDomain, code: errorCode.rawValue, userInfo: errorInfo)
        return error as Error
    }
}

public enum PlayerResult {
    case playResourceExist(Bool)
    case failure(Error)
    case playing(Double, Double)
    case playerStateChange(PlayerState)
    case playItemIndex(Int)
}

public enum PlayerState {
    case stop
    case play
    case wait
    case error
    case pause
    case unkonw
    case replay
    case finish
    case buffering
    case readyToPlay
    case topOfPlayList
    case trailOfPlayList
}

class PlayManager: NSObject {
    
    static var `default` = PlayManager()
    fileprivate var playItemList = [String]()
    fileprivate var playerResult: playerResultCallBack?
    fileprivate var timeObserver: Any?
    fileprivate var playItemURL: String?
    fileprivate var immediatelyPlay = false
    
    var player: AVPlayer? // player
    var duration = 0.0 //currentItem duration
    var autoPlayNextSong = true
    var periodicTime = 0.3
    var cyclePlay = false
    //player state
    var state = PlayerState.unkonw {
        didSet {
            invokeResultCallBack(.playerStateChange(state))
        }
    }
    
    var currentPlayItemIndex = 0  {
        didSet{
            invokeResultCallBack(.playItemIndex(currentPlayItemIndex))
        }
    }
    
    //public func
    static func prepare(_ url: String, playerResult: playerResultCallBack? = nil) {
        self.prepare([url], playerResult: playerResult)
    }
    static func prepare(_ urls: [String], playerResult: playerResultCallBack? = nil) {
        self.default.playerResult = playerResult
        self.default.playItemList = urls
        self.default.play(with: urls.first)
    }
    static func play() {
        //play the item
        switch self.default.state {
        case .pause, .readyToPlay, .replay:
            self.default.state = .play
            guard let player = self.default.player else {
                self.default.play(with: self.default.playItemURL)
                return
            }
            player.play()
        case .finish:
            self.replay()
        default:
            break
        }
    }
    
    static func pause() {
        //pause the item
        self.default.immediatelyPlay = false
        self.default.player?.pause()
        self.default.state = .pause
    }
    static func replay() {
        self.default.state = .replay
        self.default.play(with: self.default.playItemURL!, immediatelyPlay: true)
    }
    static func next() {
        let index = self.default.currentPlayItemIndex
        
        if index < self.default.playItemList.count - 1 {
            self.replacePlay( self.default.playItemList[index + 1])
            return
        }
        
        self.default.state = .trailOfPlayList
        
        if self.default.cyclePlay {
            self.replacePlay(self.default.playItemList.first, immediatelyPlay: true)
        }
    }
    
    static func previousTrack() {
        let index = self.default.currentPlayItemIndex
        if index > 0 {
            self.replacePlay(self.default.playItemList[index - 1])
            return
        }
        self.default.state = .topOfPlayList
        if self.default.cyclePlay {
            self.replacePlay(self.default.playItemList.last, immediatelyPlay: true)
        }
    }
    
    static func replacePlay(_ url: String?, immediatelyPlay: Bool = true) {
        self.stop()
        self.default.play(with: url, immediatelyPlay: immediatelyPlay)
    }
    static func stop() {
        if self.default.state == .stop {
            return
        }
        self.default.removeObserver()
        self.default.player = nil
        DownloadManager.cancelDownload(self.default.playItemURL ?? "")
        self.default.state = .stop
    }
    
    static func seek(_ sec: Double, completion:(() -> Void)? = nil) {
        // seek to the increase second of the current time
        guard let player = self.default.player else {
            return
        }
        let finalTime = CMTimeAdd((player.currentTime()), CMTime(seconds: sec, preferredTimescale: 1))
        player.seek(to: finalTime, completionHandler: { (result) in
            if result {
                completion?()
            }
            
        })
    }
    static func seek(to time: CMTime, completion:(() -> Void)? = nil) {
        // seek to the specific time
        self.default.player?.seek(to: time, completionHandler: { (result) in
            if result {
                completion?()
            }
        })
    }
    static  func cleanCache() {
        DownloadCache.cleanDownloadFiles()
    }
    
}

extension PlayManager {
    
    typealias playerResultCallBack = (AVPlayer?, PlayerResult) -> Void
    
    fileprivate func play(with url: String?, immediatelyPlay: Bool = false) {
        self.state = .wait
        self.playItemURL = url
      
        guard let _url = url else {
            invokeResultCallBack(.failure(PlayerError.getEmptyURLError()))
            self.state = .error
            return
        }
        self.currentPlayItemIndex = self.playItemList.index(of: _url) ?? 0
        let exist = DownloadCache.isFileExist(atPath: DownloadCache.cachePath(url: URL(fileURLWithPath: _url)))
        invokeResultCallBack(.playResourceExist(exist))
        
        if self.player == nil {
            self.player = AVPlayer()
        }
        
        DownloadManager.default.downloadResource(resourcePath: url, cacheDirectoryName: "Audio") { [weak self] (downloadReuslt) -> Void in
            switch downloadReuslt {
            case.success(let url):
                let playerItem = AVPlayerItem(url: url)
                
                self?.player?.replaceCurrentItem(with: playerItem)
                self?.addObserver()
                self?.immediatelyPlay = immediatelyPlay
            case .failure(_):
                self?.invokeResultCallBack(.failure(PlayerError.getEmptyURLError()))
                
                self?.state = .error
            case .failureUrl( _):
                self?.invokeResultCallBack(.failure(PlayerError.getNetworkLoadFailError()))
                self?.state = .error
            }
        }
        
    }
    func invokeResultCallBack(_ result: PlayerResult) {
        
        self.playerResult?(self.player, result)
    }
    fileprivate func addObserver() {
        
        //播放完成
        NotificationCenter.default.addObserver(self, selector: #selector(self.playbackDidFinish), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        //打断处理
        NotificationCenter.default.addObserver(self, selector: #selector(self.audioSessionInterrupted), name: Notification.Name.AVAudioSessionInterruption, object: nil)
        //播放进度
        self.addPeriodicTimeObserver()
        //playerItem
        self.player?.currentItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
    }
    fileprivate func removeObserver() {
        NotificationCenter.default.removeObserver(self)
        if let timeObserver = self.timeObserver {
            self.player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        guard  let item = self.player?.currentItem else {
            return
        }
        item.removeObserver(self, forKeyPath: "status")
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            switch self.player!.status {
            case .unknown:
                self.state = .unkonw
            case .readyToPlay:
                self.duration = CMTimeGetSeconds(self.player!.currentItem!.duration)
                
                self.state = .readyToPlay
                if self.immediatelyPlay {
                    PlayManager.play()
                }
            case .failed:
                self.state = .error
                invokeResultCallBack(.failure(PlayerError.getNetworkLoadFailError()))
                
            }
        }
    }
    @objc
    fileprivate func playbackDidFinish() {
        PlayManager.stop()
        self.state = .finish
        if self.autoPlayNextSong {
            PlayManager.next()
        }
        
    }
    @objc
    fileprivate func audioSessionInterrupted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let interruptionTypeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSessionInterruptionType(rawValue: interruptionTypeRawValue) else {
                return
        }
        
        switch interruptionType {
        case .began:
            PlayManager.pause()
        case .ended:
            let option = userInfo[AVAudioSessionInterruptionOptionKey] as! Int
            if option == AVAudioSessionInterruptionOptions.shouldResume.rawValue.hashValue{
                PlayManager.play()
            }
        }
        
    }
    fileprivate  func addPeriodicTimeObserver() {
        // Invoke callback every half second
        let interval = CMTime(seconds: self.periodicTime,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Queue on which to invoke the callback
        
        let mainQueue = DispatchQueue.main
        // Add time observer
        
        self.timeObserver = self.player?.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue) { [weak self] time in
            // update player transport UI
            self?.invokeResultCallBack(.playing(CMTimeGetSeconds(time), (self?.duration)!))
        }
    }
}
