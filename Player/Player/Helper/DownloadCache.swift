//
//  DownloadCache.swift
//  alo7-student
//
//  Created by ken.zhang on 2017/12/19.
//  Copyright © 2017年 alo7. All rights reserved.
//

import Foundation

let directory = "Video"
let workDirectory = "Work"
let Audiodirectory = "Audio"

public enum DirType: String {
    case video = "Video"
    case work = "Work"
    case audio = "Audio"
}

class DownloadCache {
    static var dirType: DirType = .video {
        didSet {
            cachesDirectory = dirType.rawValue
        }
    }
    ///  In the sandbox cactes directory, custom your cache directory
    public static var cachesDirectory :String = dirType.rawValue{
        willSet
        {
            createDirectory(atPath: newValue.cacheDir)
        }
    }
    
    
    static func tempPath(url : URL ) -> String{
        
        return url.absoluteString.md5.tmpDir
    }
    
    static func cachePath(url : URL ) -> String{
        
        return  cachesDirectory.cacheDir + "/" + url.lastPathComponent
    }
    
    
    
    static func removeTempFile(with url:URL){
        let fileTempParh = tempPath(url: url)
        if isFileExist(atPath: fileTempParh) {
            removeItem(atPath: fileTempParh)
        }
    }
    static func removeCacheFile(with url:URL){
        let fileCachePath = cachePath(url: url)
        if isFileExist(atPath: fileCachePath) {
            removeItem(atPath: fileCachePath)
        }
    }
    
    
    /// The size of the downloaded files
    public static func downloadedFilesSize() -> Int64{
        
        if !isFileExist(atPath: cachesDirectory.cacheDir) {
            return 0
        }
        do {
            var filesSize : Int64 = 0
            
            let subpaths = try FileManager.default.subpathsOfDirectory(atPath: cachesDirectory.cacheDir)
            
            _ = subpaths.map{
                let filepath = cachesDirectory.cacheDir + "/" + $0
                filesSize += fileSize(filePath: filepath)
            }
            return filesSize
            
        } catch  {
            error.localizedDescription.debug()
            return 0
            
        }
        
        
    }
    /// delete all downloaded files
    public static func cleanDownloadTempFiles(){
        
        do {
            let subpaths = try FileManager.default.subpathsOfDirectory(atPath: "".tmpDir)
            _ = subpaths.map{
                let tempFilepath = "".tmpDir + "/" + $0
                
                removeItem(atPath: tempFilepath)
            }
        } catch  {
            error.localizedDescription.debug()
        }
        
    }
    /// delete all  temp files
    public static func cleanDownloadFiles(){
        
        removeItem(atPath: cachesDirectory.cacheDir)
        createDirectory(atPath: cachesDirectory.cacheDir)
        
    }
    
    /// paths to the downloaded files
    public static func pathsOfDownloadedfiles() -> [String]{
        
        var paths = [String]()
        do {
            let subpaths = try FileManager.default.subpathsOfDirectory(atPath: cachesDirectory.cacheDir)
            
            _ = subpaths.map{
                let filepath = cachesDirectory.cacheDir + "/" + $0
                paths.append(filepath)
            }
        }catch  {
            error.localizedDescription.debug()
        }
        
        return paths
    }
    
}

// MARK: - fileHelper
extension DownloadCache {
    
    /// isFileExist
    public static func isFileExist(atPath filePath : String ) -> Bool {
        
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    /// fileSize
    public static func fileSize(filePath : String ) -> Int64 {
        
        guard isFileExist(atPath: filePath) else { return 0 }
        let fileInfo =   try! FileManager.default.attributesOfItem(atPath: filePath)
        return fileInfo[FileAttributeKey.size] as! Int64
        
    }
    
    /// move file
    public static func moveItem(atPath: String, toPath: String) {
        
        do {
            try  FileManager.default.moveItem(atPath: atPath, toPath: toPath)
        } catch  {
            error.localizedDescription.debug()
        }
    }
    
    /// delete file
    public static func removeItem(atPath: String) {
        
        guard isFileExist(atPath: atPath) else {
            return
        }
        
        do {
            try  FileManager.default.removeItem(atPath:atPath )
        } catch  {
            error.localizedDescription.debug()
        }
    }
    
    /// createDirectory
    public static func createDirectory(atPath:String) {
        
        if !isFileExist(atPath: atPath)  {
            do {
                try FileManager.default.createDirectory(atPath: atPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                error.localizedDescription.debug()
            }
        }
    }
    
    
    /// systemFreeSize
    
    public static func systemFreeSize() -> Int64{
        
        do {
            let attributes =  try FileManager.default.attributesOfFileSystem(forPath:  NSHomeDirectory())
            let freesize = attributes[FileAttributeKey.systemFreeSize] as? Int64
            
            return freesize ?? 0
            
        } catch  {
            error.localizedDescription.debug()
            return 0
            
        }
    }
}

// MARK:- SandboxPath

extension String{
    
    public var md5 : String {
        return self.kf.md5
    }
    func debug(){
        print("\(self)")
    }
    public var length:Int{
        return characters.count
    }
    public var cacheDir:String {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last!
        return (path as NSString).appendingPathComponent((self as NSString).lastPathComponent)
    }
    
    public var docDir:String {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask, true).last!
        return (path as NSString).appendingPathComponent((self as NSString).lastPathComponent)
    }
    public var tmpDir:String {
        
        let path = NSTemporaryDirectory() as NSString
        return path.appendingPathComponent((self as NSString).lastPathComponent)
        
    }
}
