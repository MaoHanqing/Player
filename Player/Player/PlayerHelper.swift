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
    case listFinish
    case readyToPlay
   
}
public struct PlayerAsset {
    let url :String?
    let title:String?
    let cover:UIImage?
    let artist:String?
    public init(url:String?,title:String? = nil,artist:String? =  nil,cover:UIImage? = nil) {
        self.url = url
        self.cover = cover
        self.artist = artist
        self.title = title
    }
}


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
