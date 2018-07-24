//
//  Player.swift
//  dddd
//
//  Created by hanqing.mao on 2018/7/20.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import Foundation
import AVFoundation



struct PlayerError{
    enum PlayerErrorCode :Int {
        case loadingFail =  400
        case emptyURL = 401
    }
    static let PlayerErrorDomain = "playerDomain"
    static func getNetworkLoadFailError() -> Error {
        return self.setError(info: "loading fail,server error", errorCode: PlayerErrorCode.loadingFail)
    }
    static func getEmptyURLError()->Error{
        return self.setError(info: "url is empty", errorCode: PlayerErrorCode.emptyURL)
    }
    static func setError(info:String,errorCode:PlayerErrorCode) ->Error{
        let errorInfo = ["errMsg": info]
        let error = NSError(domain: PlayerErrorDomain, code: errorCode.rawValue, userInfo: errorInfo)
        return error as Error
    }
}

public enum PlayerResult {
    case failure(Error)
    case readyToPlay()
    case finish()
    case playing(Double,Double)
}

public enum PlayerState{
    case readyToPlay
    case stop
    case play
    case pause
    case wait
    case error
    case buffering
    case unkonw
    case replay
}

class PlayManager :NSObject{
    
   static var `default` = PlayManager()
    
   private var playerResult:playerResultCallBack?
   private var timeObserver : Any?
   private var playItemURL :String?{
        didSet{
            self.state = .wait
            self.play(with: playItemURL, result: self.playerResult)
        }
    }
   var state  = PlayerState.unkonw
   var player : AVPlayer?
   var duration = 0.0
    static func prepare(_ url:String,playerResult:playerResultCallBack? = nil){
        self.default.playerResult = playerResult
        self.default.playItemURL = url
    }
    static func play() {
        switch self.default.state {
        case .pause,.readyToPlay,.replay:
            self.default.player?.play()
            self.default.state = .play
        default:
            break
        }
    }
    
    static func pause()  {
        self.default.player?.pause()
        self.default.state = .pause
    }
    static func replay(){
        self.default.state = .replay
        self.default.play(with: self.default.playItemURL!,immediatelyPlay: true, result: self.default.playerResult)
    }
    static func stop(){
        if self.default.state == .stop{
            return
        }
        self.default.state = .stop
        self.default.removeObserver()
        self.default.player = nil
    }
    static func seek(_ sec:Double,completion:(()->Void)? = nil){
        guard let player = self.default.player else {
            return
        }
        let finalTime = CMTimeAdd((player.currentTime()), CMTime(seconds: sec, preferredTimescale: 1))
        player.seek(to: finalTime,completionHandler: { (result) in
            if result{
                completion?()
            }
            
        })
    }
    static func seek(to time:CMTime,completion:(()->Void)? = nil){
        self.default.player?.seek(to: time,completionHandler:{ (result) in
            if result{
                completion?()
            }
            
        })
    }
   
}

extension PlayManager{
    
   typealias playerResultCallBack = (AVPlayer?,PlayerResult) -> (Void)
    
   private func play(with url:String?,immediatelyPlay:Bool = false,result:playerResultCallBack?){
        guard let url = url else {
        
            invokeResultCallBack(result,.failure(PlayerError.getEmptyURLError()))
          
            self.state = .error
            return
        }
        if self.player == nil{
            self.player = AVPlayer()
        }
        DownloadManager.default.downloadResource(resourcePath: url,downloadCacheType: .audio) { [weak self] (downloadReuslt) -> (Void) in
            switch downloadReuslt{
            case.success(let url):
                let playerItem = AVPlayerItem(url: url)
                self?.player?.replaceCurrentItem(with: playerItem)
                self?.addObserver()
                if immediatelyPlay{
                    PlayManager.play()
                }
            case .failure(_):
                self?.invokeResultCallBack(result,.failure(PlayerError.getEmptyURLError()))
            
                self?.state = .error
            case .failureUrl( _):
                self?.invokeResultCallBack(result,.failure(PlayerError.getNetworkLoadFailError()))
                self?.state = .error
            }
        }
     
    }
    func invokeResultCallBack(_ callBack:playerResultCallBack?,_ result:PlayerResult){
        callBack?(self.player,result)
    }
   private func addObserver(){
        //播放完成
        NotificationCenter.default.addObserver(self, selector: #selector(self.playbackDidFinish), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        //打断处理
        NotificationCenter.default.addObserver(self, selector: #selector(self.audioSessionInterrupted), name: Notification.Name.AVAudioSessionInterruption, object: nil)
        //播放进度
            self.addPeriodicTimeObserver()
        //playerItem
           self.player?.currentItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
    }
   private func removeObserver() {
        NotificationCenter.default.removeObserver(self)
        if let timeObserver = self.timeObserver{
            self.player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        guard  let item = self.player?.currentItem else {
            return
        }
        item.removeObserver(self, forKeyPath: "status")
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            switch self.player!.status{
            case .unknown:
                self.state = .unkonw
            case .readyToPlay:
                self.state = .readyToPlay
                invokeResultCallBack(self.playerResult, .readyToPlay())
                self.duration = CMTimeGetSeconds(self.player!.currentItem!.duration)
            case .failed:
                self.state = .error
                
                invokeResultCallBack(self.playerResult, .failure(PlayerError.getNetworkLoadFailError()))
          
            }
        }
    }
    @objc private func playbackDidFinish()  {
        invokeResultCallBack(self.playerResult, .finish())
        PlayManager.stop()
        print("播放完成")
    }
    @objc private func audioSessionInterrupted(_ notification:Notification) {
        guard let userInfo = notification.userInfo,
            let interruptionTypeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSessionInterruptionType(rawValue: interruptionTypeRawValue) else {
                return
        }
        
        switch interruptionType {
        case .began:
            PlayManager.pause()
        case .ended:
            PlayManager.play()
        }
            
    }
  private  func addPeriodicTimeObserver() {
        // Invoke callback every half second
        
        let interval = CMTime(seconds: 0.5,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Queue on which to invoke the callback
        
        let mainQueue = DispatchQueue.main
        // Add time observer
        guard let currentItem = self.player?.currentItem else {
            return
        }
       self.timeObserver =  self.player?.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue) {
            [weak self] time in
            // update player transport UI
            print("time === \(CMTimeGetSeconds(time))\n======\(CMTimeGetSeconds(currentItem.duration))")
        self?.invokeResultCallBack(self?.playerResult, .playing(CMTimeGetSeconds(time), (self?.duration)!))
        }
    }
}

