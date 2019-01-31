//
//  PlayerHelper.swift
//  Player
//
//  Created by hanqing.mao on 2018/8/14.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import Foundation
import UIKit

public enum PlayerResult {
    case playResourceExist(Bool)
    case failure(PlayerError)
    case playing(Double, Double)
    case playerStateChange(PlayerState)
    case playItemIndex(Int)
    case prepareToPlay(PlayerAsset)
    case readyToPlay(PlayerAsset)

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

public struct PlayerAsset {
    let url: String?
    let name: String?
    let subname: String?
    let contentName: String?
    var cover: UIImage?
    let coverUrl: String?
    let albumID: String?
    let lyricUrl: String?

    public init(url: String?, name: String? = nil, subname: String? =  nil, contentName: String? = nil, cover: UIImage? = nil, coverUrl: String? = nil, albumID: String? = nil, lyricUrl: String? = nil) {
        self.url = url
        self.cover = cover
        self.coverUrl = coverUrl
        self.name = name
        self.subname = subname
        self.contentName = contentName
        self.albumID = albumID
        self.lyricUrl = lyricUrl
    }
}

public enum PlayerError: Error {
    case emptyURL
    case loadingFail
    case downloadCancel
    case downloadFail
}
