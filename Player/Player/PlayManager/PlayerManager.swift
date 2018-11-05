//
//
//  Created by hanqing.mao on 2018/7/20.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import AVFoundation
import Foundation
import Kingfisher
import MediaPlayer
import MediaPlayer
class PlayManager: NSObject {
    typealias playerResultCallBack = (AVPlayer?, PlayerResult) -> Void
    static var `default`:PlayManager = {
        let manager = PlayManager()
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return manager
        }
        manager.isBackgroundPlay = true
        manager.cachePath = "Audio"
        return manager
    }()
    fileprivate var playAssets = [PlayerAsset]()
    var currentPlayingAsset: PlayerAsset? {
        get {
            guard self.currentPlayItemIndex < self.playAssets.count else {
                return nil
            }
            return self.playAssets[self.currentPlayItemIndex]
        }
    }
    fileprivate var playItemList = [String]()
    fileprivate var playerResult: playerResultCallBack?
    fileprivate var timeObserver: Any?
    var isImmediatelyPlay = true
    // 多个页面持有播放器 如何调用 duoge yemian bofang block huidiao?notification
    var defaultCover: UIImage? {
        return #imageLiteral(resourceName: "img_earth")
    }
    var player: AVPlayer? // player
    var duration = 0.0 //currentItem duration
    var autoPlayNextSong = true
    var periodicTime = 0.3
    var cyclePlay = true
    var cachePath = "Audio"
    var isImmediatelyDownload = true
    var isBackgroundPlay = false {
        didSet {
            if isBackgroundPlay {
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
    
    var currentPlayItemIndex = 0 {
        didSet {
            invokeResultCallBack(.playItemIndex(currentPlayItemIndex))
        }
    }
    
    //public func
    static func prepare(_ url: String, playerResult: playerResultCallBack? = nil) {
        self.prepare([url], playerResult: playerResult)
    }
    static func prepare(_ urls: [String], playerResult: playerResultCallBack? = nil) {
        let assets = urls.map { (url) -> PlayerAsset in
            PlayerAsset(url: url)
        }
        self.prepare(assets, playerResult: playerResult)
    }
    static func prepare(_ assets: [PlayerAsset], willPlayIndex: Int = 0, playerResult: playerResultCallBack? = nil) {
        self.default.playerResult = playerResult
        
        self.default.readyToPlay(with: assets, willPlayIndex: willPlayIndex)
        
    }
}

//Player Command Func
extension PlayManager {
    static func play() {
        //play the item
        
        switch self.default.state {
        case .pause, .readyToPlay, .replay:
            self.default.state = .play
            guard let player = self.default.player else {
                self.default.readyToPlay(with: self.default.currentPlayingAsset)
                return
            }
            
            player.play()
            self.default.updatePlayingInfo()
        case .finish:
            self.replay()
        case .wait:
            self.default.download(with: self.default.currentPlayingAsset!)
        default:
            break
        }
    }
    static func play(at index: Int) {
        
        self.replacePlay(self.default.playAssets[index])
    }
    static func pause() {
        //pause the item
        self.default.player?.pause()
        self.default.state = .pause
        
    }
    static func replay() {
        self.default.state = .replay
        self.default.readyToPlay(with: self.default.currentPlayingAsset)
    }
    static func next() {
        let index = self.default.currentPlayItemIndex
        
        if index < self.default.playAssets.count - 1 {
            self.replacePlay( self.default.playAssets[index + 1])
            return
        }
        
        if self.default.cyclePlay {
            self.replacePlay(self.default.playAssets.first)
            return
        }
        
        self.default.state = .trailOfPlayList
    }
    
    static func previousTrack() {
        let index = self.default.currentPlayItemIndex
        if index > 0 {
            self.replacePlay(self.default.playAssets[index - 1])
            return
        }
        
        if self.default.cyclePlay {
            self.replacePlay(self.default.playAssets.last)
            return
        }
        self.default.state = .topOfPlayList
    }
    
    static func replacePlay(_ asset: PlayerAsset?) {
        self.default.readyToPlay(with: asset)
    }
    static func replacePlay(_ assets: [PlayerAsset], willPlayIndex: Int = 0) {
        self.default.readyToPlay(with: assets, willPlayIndex: willPlayIndex)
    }
    static func stop() {
        if self.default.state == .stop {
            return
        }
        self.default.playerReset()
        self.default.player = nil
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
            self.default.readyToPlay(with: self.default.currentPlayingAsset)
        }
        self.default.seeking = true
        self.default.player?.seek(to: time, completionHandler: { (result) in
            if result {
                completion?()
                self.default.seeking = false
                self.default.updatePlayingInfo()
            }
        })
    }
    static  func cleanCache() {
        //delete current
        DownloadManager.cleanAllDownloadFiles()
    }
}

//Player Play Events
extension PlayManager {
    
    fileprivate func readyToPlay(with asset: PlayerAsset?) {
        
        self.playerReset()
        
        guard let asset = asset, let _url = asset.url else {
            
            invokeResultCallBack(.failure(PlayerError.getEmptyURLError()))
            self.state = .error
            return
        }
        
        self.currentPlayItemIndex = self.playAssets.index { $0.url == _url } ?? 0
        self.state = .wait
        self.updatePlayingInfo()
        self.download(with: asset)
        self.downloadImage(with: asset)
    }
    fileprivate func readyToPlay(with assets: [PlayerAsset], willPlayIndex: Int) {
        self.playAssets = assets
        var asset: PlayerAsset? = nil
        if willPlayIndex < assets.count {
            asset = assets[willPlayIndex]
        } else {
            asset = assets.first
        }
        self.readyToPlay(with: asset)
    }
    fileprivate func downloadImage(with asset: PlayerAsset) {
        guard asset.cover == nil, let coverUrl = asset.coverUrl else {
            return
        }
        
        DownloadManager.downloadImage(with: coverUrl) { [weak self] (image, error) in
            guard let image = image, error == nil else {
                return
            }
            for  (index, value) in self!.playAssets.enumerated() {
                if value.url != asset.url {
                    continue
                }
                
                self?.playAssets[index].cover = image
                if self?.state == .play || self?.state == .pause {
                    self?.updatePlayingInfo()
                }
            }
        }
    }
    fileprivate func download(with asset: PlayerAsset) {
        let _url = asset.url!
        
        let exist = DownloadCache.isFileExist(url: URL(fileURLWithPath: _url))
        invokeResultCallBack(.playResourceExist(exist))
        if !self.isImmediatelyDownload {
            return
        }
        
        if self.player == nil {
            self.player = AVPlayer()
        }
        
        invokeResultCallBack(.prepareToPlay(asset))
        DownloadManager.default.downloadResource(resourcePath: _url, cacheDirectoryName: self.cachePath) { [weak self] (downloadReuslt) -> Void in
            switch downloadReuslt {
            case.success(let url):
                let playerItem = AVPlayerItem(url: url)
                self?.player?.replaceCurrentItem(with: playerItem)
                self?.invokeResultCallBack(.readyToPlay(asset))
                self?.addObserver()
            case .failure(_):
                self?.invokeResultCallBack(.failure(PlayerError.getEmptyURLError()))
                self?.state = .error
            case .failureUrl( _):
                self?.invokeResultCallBack(.failure(PlayerError.getNetworkLoadFailError()))
                self?.state = .error
            }
        }
    }
    fileprivate func playerReset() {
        self.player?.pause()
        self.removeObserver()
        DownloadManager.cancelDownload(self.currentPlayingAsset?.url ?? "")
    }
    func invokeResultCallBack(_ result: PlayerResult) {
        
        self.playerResult?(self.player, result)
    }
    fileprivate func addObserver() {
        
        //播放完成
        NotificationCenter.default.addObserver(self, selector: #selector(self.playbackDidFinish), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        //打断处理
        NotificationCenter.default.addObserver(self, selector: #selector(self.audioSessionInterrupted), name: Notification.Name.AVAudioSessionInterruption, object: nil)
        //输出端变化
        NotificationCenter.default.addObserver(self, selector: #selector(routeChange(noti:)), name: Notification.Name.AVAudioSessionRouteChange, object: AVAudioSession.sharedInstance())
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
        self.player?.replaceCurrentItem(with: nil)
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            switch self.player!.status {
            case .unknown:
                self.state = .unkonw
            case .readyToPlay:
                self.duration = CMTimeGetSeconds(self.player!.currentItem!.duration)
                self.state = .readyToPlay
                if self.isImmediatelyPlay {
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
        self.playerReset()
        self.state = .finish
        self.duration = 0
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
            if option == AVAudioSessionInterruptionOptions.shouldResume.rawValue.hashValue {
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
    @objc func routeChange(noti: Notification) {
        guard let userInfo = noti.userInfo else {
            return
        }
        
        let changeResonInt = userInfo[AVAudioSessionRouteChangeReasonKey] as! Int
        
        let changeReson = AVAudioSessionRouteChangeReason(rawValue: UInt(changeResonInt))
        
        if changeReson != .oldDeviceUnavailable {
            return
        }
        
        let routeDes = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as! AVAudioSessionRouteDescription
        let portDes = routeDes.outputs.first
        
        if portDes?.portType == AVAudioSessionPortHeadphones {
            let audioRouteOveeride = kAudioSessionOverrideAudioRoute_Speaker
            let session = AVAudioSession.sharedInstance()
            try? session.setPreferredIOBufferDuration(Double(audioRouteOveeride))
            
            if self.state == .play {
                DispatchQueue.main.async {
                    PlayManager.pause()
                }
            }
            
        }
        
    }
}
// BackPlayerInfo
extension PlayManager {
    // 设置后台播放显示信息
    func updatePlayingInfo() {
        
        if !self.isBackgroundPlay {
            
            return
        }
        
        let playerAsset = self.currentPlayingAsset
        
        var postion = 0.0
        if let player = player {
            postion = CMTimeGetSeconds(player.currentTime())
        }
        
        var info: [String: Any] = [MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: postion),
                                   MPMediaItemPropertyPlaybackDuration: NSNumber(value: self.duration)]
        
        info[MPNowPlayingInfoPropertyPlaybackRate] = self.state == .play ? NSNumber(value: 1) : NSNumber(value: 0)
        let cover = playerAsset?.cover ?? self.defaultCover
        if let cover = cover {
            //专辑封面
            let rect = cover.size.width > cover.size.height ? cover.size.height : cover.size.width
            let cover = cover.kf.resize(to: CGSize(width: rect, height: rect))
            var albumArt: MPMediaItemArtwork? = nil
            if #available(iOS 10.0, *) {
                let offset: CGFloat =  65.0
                let rect = UIScreen.main.bounds.width - offset * 2
                let mySize = CGSize(width: rect, height: rect)
                albumArt = MPMediaItemArtwork(boundsSize: mySize) { _ in cover }
                
            } else {
                
                albumArt = MPMediaItemArtwork(image: cover)
                
            }
            info[MPMediaItemPropertyArtwork] = albumArt!
        }
        if let subname = playerAsset?.subname {
            info[MPMediaItemPropertyTitle] = subname
        }
        if let contentName = playerAsset?.contentName {
            info[MPMediaItemPropertyArtist] = contentName
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
    }
    
    func backgroundPlayRemoteFuncRegister() {
        
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayManager.pause()
            self.updatePlayingInfo()
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
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayManager.next()
            return .success
        }
    }
}
