//
//
//  Created by hanqing.mao on 2018/7/20.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import AVFoundation
import Foundation
import MediaPlayer
    // 多个页面持有播放器 如何调用 duoge yemian bofang block huidiao?notification
class PlayManager: NSObject {
    typealias playerResultCallBack = (AVPlayer?, PlayerResult) -> Void
    
    static var `default`:PlayManager = {
        let manager = PlayManager()
        manager.isBackgroundPlay = true
        let audioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
        try! audioSession.setActive(true)
        
        return manager
    }()
    fileprivate var playAssets = [PlayerAsset]()
    fileprivate var playingAsset: PlayerAsset?
    fileprivate var playItemList = [String]()
    fileprivate var playerResult: playerResultCallBack?
    fileprivate var timeObserver: Any?
//    fileprivate var playItemURL: String?
    fileprivate var immediatelyPlay = false
    var defaultCover :UIImage?
    var player: AVPlayer? // player
    var duration = 0.0 //currentItem duration
    var autoPlayNextSong = true
    var periodicTime = 0.3
    var cyclePlay = false
    var isBackgroundPlay = false{
        didSet{
            if isBackgroundPlay{
                self.backgroundPlayRemoteFuncRegister()
            }
        }
    }
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
        let assets = urls.map { (url) -> PlayerAsset in
            return PlayerAsset(url: url)
        }
        self.prepare(assets,playerResult:playerResult)
    }
    static func prepare(_ assets: [PlayerAsset], playerResult: playerResultCallBack? = nil) {
        self.default.playerResult = playerResult
        self.default.playAssets = assets
        self.default.play(with: assets.first)
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
                self.default.play(with: self.default.playingAsset)
                return
            }
            player.play()
            self.default.updatePlayingInfo()
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
        self.default.play(with: self.default.playingAsset, immediatelyPlay: true)
    }
    static func next() {
        let index = self.default.currentPlayItemIndex
        
        if index < self.default.playAssets.count - 1 {
            self.replacePlay( self.default.playAssets[index + 1])
            return
        }
        
//        self.default.state = .trailOfPlayList
        
        if self.default.cyclePlay {
            self.replacePlay(self.default.playAssets.first, immediatelyPlay: true)
        }
    }
    
    static func previousTrack() {
        let index = self.default.currentPlayItemIndex
        if index > 0 {
            self.replacePlay(self.default.playAssets[index - 1])
            return
        }
//        self.default.state = .topOfPlayList
        if self.default.cyclePlay {
            self.replacePlay(self.default.playAssets.last, immediatelyPlay: true)
        }
    }
    
    static func replacePlay(_ asset: PlayerAsset?, immediatelyPlay: Bool = true) {
        self.stop()
        self.default.play(with: asset, immediatelyPlay: immediatelyPlay)
    }
    static func stop() {
        if self.default.state == .stop {
            return
        }
        self.default.removeObserver()
        self.default.player = nil
        DownloadManager.cancelDownload(self.default.playingAsset?.url ?? "")
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
            self.default.play(with: self.default.playingAsset, immediatelyPlay: false)
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
    
    fileprivate func play(with asset: PlayerAsset?, immediatelyPlay: Bool = false) {
        self.state = .wait
        self.playingAsset = asset
      
        guard let asset = asset , let _url = asset.url else {
            invokeResultCallBack(.failure(PlayerError.getEmptyURLError()))
            self.state = .error
            return
        }
        
        
        
        
        self.currentPlayItemIndex =  self.playAssets.index{ $0.url == asset.url} ?? 0
        let exist = DownloadCache.isFileExist(url: URL(fileURLWithPath: _url))
        invokeResultCallBack(.playResourceExist(exist))
        
        if self.player == nil {
            self.player = AVPlayer()
        }
        
        DownloadManager.default.downloadResource(resourcePath: _url, cacheDirectoryName: "Audio") { [weak self] (downloadReuslt) -> Void in
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.playDidFinish), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
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
    fileprivate func playDidFinish() {
        PlayManager.stop()
        self.state = .finish
        if self.currentPlayItemIndex == self.playItemList.count - 1 {
            self.state = .listFinish
        }
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
        guard let player = self.player else {
            return
        }
        
        let mpic = MPNowPlayingInfoCenter.default()
        let cover = self.playingAsset?.cover ?? self.defaultCover
        let postion = CMTimeGetSeconds(player.currentTime())
        var info :[String:Any] = [MPNowPlayingInfoPropertyElapsedPlaybackTime:postion,
                    MPMediaItemPropertyPlaybackDuration: self.duration]
        
        if let cover = cover{
            //专辑封面
            let mySize = CGSize(width: 400, height: 400)
            
            let albumArt = MPMediaItemArtwork(boundsSize:mySize) { sz in
                return cover
            }
            info[MPMediaItemPropertyArtwork] = albumArt
        }
        if let title = self.playingAsset?.title{
            info[MPMediaItemPropertyTitle] = title
        }
        if let artist = self.playingAsset?.artist{
            info[MPMediaItemPropertyArtist] = artist
        }
        
        mpic.nowPlayingInfo = info

    }
    
    func backgroundPlayRemoteFuncRegister(){
       
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
