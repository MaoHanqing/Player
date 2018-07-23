//
//  Player.swift
//  dddd
//
//  Created by hanqing.mao on 2018/7/20.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import Foundation
import AVFoundation
typealias periodicTimeCallback = (Double,Double) -> Void
typealias playerDidFinishedPlayCallback = (AVPlayerItem)->Void
class PlayManager :NSObject{
   static var `default` = PlayManager()
    
   var periodicTime:periodicTimeCallback?
   var playerDidFinishedPlay:playerDidFinishedPlayCallback?
    private var timeOberver : Any?
    private var playItemURL :String?{
        didSet{
            if let url = playItemURL {
                self.play(with: url)
            }
        }
    }
   lazy var player : AVPlayer = {
        let player = AVPlayer()
    return player
    }()
   
    static func preparePlayer(_ url:String, periodicTime:periodicTimeCallback? = nil,playerDidFinishedPlay:playerDidFinishedPlayCallback? = nil){
        self.default.playItemURL = url
        self.default.addPeriodicTimeObserver()
        self.default.periodicTime = periodicTime
        self.default.playerDidFinishedPlay = playerDidFinishedPlay
        NotificationCenter.default.addObserver(self.default, selector: #selector(self.default.playbackDidFinish), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    static func invalidatePlayer(){
        self.default.player.pause()
        if let timeOberver = self.default.timeOberver  {
            self.default.player.removeTimeObserver(timeOberver)
        }
        NotificationCenter.default.removeObserver(self.default)
        self.default.invalidatePlayerItme()
    }
    static func play() {
        self.default.player.play()
    }
    
    static func pause()  {
        self.default.player.pause()
    }
    static func seek(_ sec:Double,completion:@escaping ((Bool)->Void)){
       let finalTime = CMTimeAdd(self.default.player.currentTime(), CMTime(seconds: sec, preferredTimescale: 1))
        self.default.player.seek(to: finalTime,completionHandler: completion)
    }
    static func seek(to time:CMTime,completion:@escaping ((Bool)->Void)){
        self.default.player.seek(to: time,completionHandler: completion)
    }
    static func replay(){
        self.default.play(with: self.default.playItemURL!)
    }
}
extension PlayManager{
    func play(with url:String){
        let playerItem = AVPlayerItem(url: URL(string: url)!)
        self.player.replaceCurrentItem(with: playerItem)
        playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
    }
    func invalidatePlayerItme(){
           self.player.currentItem?.removeObserver(self, forKeyPath: "status")
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            switch self.player.status{
            case .unknown:
                print("未知状态")
            case .readyToPlay:
                print("可以播放")
            case .failed:
                print("加载失败 网络或者服务器出现问题")
            }
        }
    }
    @objc func playbackDidFinish()  {
        invalidatePlayerItme()
        self.playerDidFinishedPlay?(self.player.currentItem!)
        print("播放完成")
    }
   
    func addPeriodicTimeObserver() {
        // Invoke callback every half second
        
        let interval = CMTime(seconds: 0.5,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Queue on which to invoke the callback
        
        let mainQueue = DispatchQueue.main
        // Add time observer
        guard let currentItem = self.player.currentItem else {
            return
        }
       self.timeOberver =  self.player.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue) {
            [weak self] time in
            // update player transport UI
            print("time === \(CMTimeGetSeconds(time))")
            self?.periodicTime?(CMTimeGetSeconds(time),CMTimeGetSeconds(currentItem.duration))
        }
    }
}
extension AVPlayer{
    
    
}
