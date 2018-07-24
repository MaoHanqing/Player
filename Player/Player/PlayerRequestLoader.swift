//
//  PlayerRequestLoader.swift
//  dddd
//
//  Created by hanqing.mao on 2018/7/23.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import Foundation
class PlayerRequestLoader:NSObject,URLSessionDownloadDelegate {
    
    enum AssetType {
        case mp3
        case unknow
       static func getAssetType(_ url:String) -> AssetType {
            if url.hasSuffix(".mp3") {
                return .mp3
            }
            return .unknow
        }
    }
    
    private lazy var session:URLSession = {
        //只执行一次
        let config = URLSessionConfiguration.default
        let currentSession = URLSession(configuration: config, delegate: self,delegateQueue: nil)
        return currentSession
        
    }()
    private lazy var locationPath :String = {
        return ""
    }()
    func download(_ urlString:String,complete:((Any)->Void)){
   
        //请求
        let url = URL(string: urlString)!
        let assetType = AssetType.getAssetType(urlString)
        let request = URLRequest(url: url)
        //下载任务
        let downloadTask = session.downloadTask(with: request)
        //使用resume方法启动任务
        downloadTask.resume()
    }
    
  
  
    
    
    //下载代理方法，下载结束
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        //下载结束
        print("下载结束")
        
        //输出下载文件原来的存放目录
        print("location:\(location)")
        //location位置转换
        let locationPath = location.path
        //拷贝到用户目录
        let documnets:String = NSHomeDirectory() + "/Documents/2.png"
        
        //创建文件管理器
        let fileManager = FileManager.default
        
        try! fileManager.moveItem(atPath: locationPath, toPath: documnets)
        print("new location:\(documnets)")
    }
    
    //下载代理方法，监听下载进度
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        //获取进度
        let written = Double(totalBytesWritten)
        let total = Double(totalBytesExpectedToWrite)
        let pro = written/total
        print("下载进度：\(pro)")
    }
    
    //下载代理方法，下载偏移
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        //下载偏移，主要用于暂停续传
    }
}
