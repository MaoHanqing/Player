//
//  DownloadCache.swift
//

import Foundation

public class DownloadCache {
    
    ///  In the sandbox cactes directory, custom your cache directory
    static var cachesDirectory :String = "default"{
        willSet
        {
            createDirectory(atPath: cachesDirectory)
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
    static func downloadedFilesSize() -> Int64{
        
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
    ///  delete all  temp files
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
    ///  delete all downloaded files
    public static func cleanDownloadFiles(){
        
        removeItem(atPath: cachesDirectory.cacheDir)
        createDirectory(atPath: cachesDirectory.cacheDir)
        
    }
    
    /// paths to the downloaded files
    static func pathsOfDownloadedfiles() -> [String]{
        
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
    public static func isFileExist(url:URL)->Bool{
        return self.isFileExist(atPath:DownloadCache.cachePath(url:url))
    }
    /// isFileExist
    static func isFileExist(atPath filePath : String ) -> Bool {
        
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    /// fileSize
    static func fileSize(filePath : String ) -> Int64 {
        
        guard isFileExist(atPath: filePath) else { return 0 }
        let fileInfo =   try! FileManager.default.attributesOfItem(atPath: filePath)
        return fileInfo[FileAttributeKey.size] as! Int64
        
    }
    
    /// move file
    static func moveItem(atPath: String, toPath: String) {
        
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
    static func createDirectory(atPath:String) {
        
        if !isFileExist(atPath: atPath)  {
            do {
                try FileManager.default.createDirectory(atPath: atPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                error.localizedDescription.debug()
            }
        }
    }
    
    
    /// systemFreeSize
    
    static func systemFreeSize() -> Int64{
        
        do {
            let attributes =  try FileManager.default.attributesOfFileSystem(forPath:  NSHomeDirectory())
            let freesize = attributes[FileAttributeKey.systemFreeSize] as? Int64
            
            return freesize ?? 0
            
        } catch  {
            error.localizedDescription.debug()
            return 0
            
        }
    }
    static func getDownloadedData(url:URL)->Data?{
        return FileManager.default.contents(atPath: DownloadCache.cachePath(url:url))
        
    }
}

// MARK:- SandboxPath

extension String{
    
    var md5 : String {
        return self.kf.md5
    }
    func debug(){
        print("\(self)")
    }
    var cacheDir:String {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last!
        return (path as NSString).appendingPathComponent((self as NSString).lastPathComponent)
    }
    
    var docDir:String {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask, true).last!
        return (path as NSString).appendingPathComponent((self as NSString).lastPathComponent)
    }
    var tmpDir:String {
        
        let path = NSTemporaryDirectory() as NSString
        return path.appendingPathComponent((self as NSString).lastPathComponent)
        
    }
}

