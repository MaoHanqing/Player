//
//  DownloadManager.swift
//  alo7-student
//
//  Created by ken.zhang on 2017/12/19.
//  Copyright © 2017年 alo7. All rights reserved.
//

import UIKit
import Alamofire

let maxCacheSize = 100 //MB
struct DownloadFileModel {
    var localSubtitleUrl: URL?
    var DownloadFileUrl: URL?
    var localBackgroundTrackUrl: URL?
    var localVoiceTrackUrl: URL?
    
    var dubbingVoiceTrackUrl: String? //work的人声
    var localDubbingVoiceTrackUrl: URL? //work的人声
    init(_ url:String) {
        self.DownloadFileUrl = URL(string: url)
    }
//
//    var video: Video
//    /// 配音资源
//    var dubRes: DubRes?
    
  
}
class DownloadManager: NSObject {
    static var `default` = DownloadManager()

    var bolSuccessful: Bool = true
    func downloadResource(resourcePath: String?,downloadCacheType:DirType = .video, completionHandler: @escaping (DownloadResult<URL>) -> (Void)) {
        DownloadCache.dirType = downloadCacheType
        guard let path = resourcePath, !path.isEmpty else {
            completionHandler(DownloadResult.failure(self.getUrlEmptyError()))
            return
        }

        if let localUrl = isFileExisted(url: path.url){
            print("播放本地文件")
            completionHandler(DownloadResult.success(localUrl))
        } else {
            downloadFile(resourceUrl: path, destination: getCacheDestination(url: path.url), completionHandler: {(result) -> (Void) in
                switch result{
                case .success(let cacheUrl):
                print("下载完成")
                completionHandler(DownloadResult.success(cacheUrl.url))
                case .failureUrl(let err, let path):
                    completionHandler(DownloadResult.failureUrl(err, path))
                default: break
                }
            })
        }
    }
    func downloadFile(resourceUrl: String, destination: DownloadRequest.DownloadFileDestination?, completionHandler: @escaping (DownloadResult<String>) -> (Void)) {
        Alamofire.download(resourceUrl, to: destination).validate(statusCode: 200..<400).response { (response) in
            if response.error == nil, let localPath = response.destinationURL?.path {
                completionHandler(DownloadResult.success(localPath))
            } else {
                completionHandler(DownloadResult.failureUrl(response.error!, response.destinationURL?.path))
            }
        }
    }
    func removeVideoResources(video: DownloadFileModel?) {
        guard let DownloadFileModel = video else { return }
        if let localSubtitlePath = DownloadFileModel.localSubtitleUrl?.path {
            DownloadCache.removeItem(atPath: localSubtitlePath)
        }
        if let DownloadFileModelPath = DownloadFileModel.DownloadFileUrl?.path {
            DownloadCache.removeItem(atPath: DownloadFileModelPath)
        }
        if let localVoiceTrackPath = DownloadFileModel.localVoiceTrackUrl?.path {
            DownloadCache.removeItem(atPath: localVoiceTrackPath)
        }
        if let localBackgroundTrackPath = DownloadFileModel.localBackgroundTrackUrl?.path {
            DownloadCache.removeItem(atPath: localBackgroundTrackPath)
        }
    }

    func reloadSingleFile(localPath: String, remotePath: String, dirType: DirType, completionHandler: @escaping (DownloadResult<URL>) -> (Void)) {
        DownloadCache.dirType = dirType
        //  先删除本地的
        DownloadCache.removeItem(atPath: localPath)
        // 再下载
        downloadResource(resourcePath: remotePath) { (result) -> (Void) in
            completionHandler(result)
        }
    }

    func isFileExisted(url: URL) -> URL? {
        if  DownloadCache.isFileExist(atPath: DownloadCache.cachePath(url: url)){
            return DownloadCache.cachePath(url: url).url
        }
        return nil
    }

    func isFileExisted(url: URL, prePath: String) -> URL? {
        if  DownloadCache.isFileExist(atPath: prePath + "/" + DownloadCache.cachePath(url: url)){
            return DownloadCache.cachePath(url: url).url
        }
        return nil
    }

    func getUrlEmptyError() -> Error {
        let errorInfo = ["errMsg": "urlEmpty"]
        let error = NSError(domain: FileErrorDomain, code: FileError.fileIsExist.rawValue, userInfo: errorInfo)
        return error as Error
    }

    func getCacheDestination(url: URL) -> DownloadRequest.DownloadFileDestination {
        return { _, _ in
            let fileURL = DownloadCache.cachePath(url: url)

            return (fileURL.url, [.removePreviousFile, .createIntermediateDirectories])
        }
    }

    func getCacheUrl(url: URL) -> URL {
        return DownloadCache.cachePath(url: url).url
    }

    func judgeIfClearCache() {
        if Int(DownloadCache.downloadedFilesSize() / 1000 / 1024) > maxCacheSize {
            DownloadCache.cleanDownloadFiles()
        }
    }
}
