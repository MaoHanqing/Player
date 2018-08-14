//
//
//  Created by hanqing.mao on 2018/7/20.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import AVFoundation
import Foundation
import MediaPlayer

class PlayManager: NSObject {
    typealias playerResultCallBack = (AVPlayer?, PlayerResult) -> Void
    
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
    /// 是否正在seek中
    var seeking: Bool = false
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
   
    
}

//Player Command Func
extension PlayManager{
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
        if self.default.state == .finish {
            self.default.play(with: self.default.playItemURL!, immediatelyPlay: false)
        }
        self.default.seeking = true
        self.default.player?.seek(to: time, completionHandler: { (result) in
            if result {
                completion?()
                self.default.seeking = false
            }
        })
    }
    static  func cleanCache() {
        DownloadCache.cleanDownloadFiles()
    }
}

//Player Play Events
extension PlayManager {
    
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
            if self?.seeking != true {
                self?.invokeResultCallBack(.playing(CMTimeGetSeconds(time), (self?.duration)!))
            }
        }
    }
}
// BackPlayerInfo
extension PlayManager{
    // 设置后台播放显示信息
    func updatePlayingInfo() {
        let mpic = MPNowPlayingInfoCenter.default()
        
        //专辑封面
        let mySize = CGSize(width: 400, height: 400)
        let albumArt = MPMediaItemArtwork(boundsSize:mySize) { sz in
            return UIImage(named: "pic_popup_freetrail copy")!
        }
        
        //获取进度
        let postion = CMTimeGetSeconds(self.player!.currentTime())
        let duration = CMTimeGetSeconds(self.player!.currentItem!.duration)
        mpic.nowPlayingInfo = [MPMediaItemPropertyTitle: "我是歌曲标题",
                               MPMediaItemPropertyArtist: "hangge.com",
                               MPMediaItemPropertyArtwork: albumArt,
                               MPNowPlayingInfoPropertyElapsedPlaybackTime: postion,
                               MPMediaItemPropertyPlaybackDuration: duration]

    }
    
    func remoteFunc(){
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            PlayManager.next()
            return .success
        }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayManager.pause()
            return .success
        }
        MPRemoteCommandCenter.shared().playCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayManager.play()
            return .success
        }
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayManager.previousTrack()
            return .success
        }
    
        
    }
}
