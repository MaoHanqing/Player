//
//  PlayerRequestTask.swift
//  dddd
//
//  Created by hanqing.mao on 2018/7/23.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import Foundation
import AVFoundation
class PlayerRequestTask {
    func ddd() {
        let fileUrl = URL(fileURLWithPath: "ddd")
        let asset = AVURLAsset(url: fileUrl)
        let reader = try! AVAssetReader(asset: asset)
        let audioTracks = asset.tracks(withMediaType: .audio)
        let audioTrack = audioTracks.first!
        let videoReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        reader.add(videoReaderOutput)
        reader.startReading()
        
        
    }
    
    
    
}
