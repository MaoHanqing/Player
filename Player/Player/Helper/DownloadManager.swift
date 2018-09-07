//
//  DownloadManager.swift
//
import UIKit
import Alamofire
public enum DownloadResourceStatus{
    case downloading
    case downloaded
    case cancel
    case failure
    case unknow
    case beginDownload
}

public class DownloadResource {
    public var status : DownloadResourceStatus = .unknow
    public var url:String = ""
    var requestTask:DownloadRequest?
    var cacheDirectory :String? = nil
    convenience init(status: DownloadResourceStatus = .beginDownload, url: String, requestTask: DownloadRequest? = nil, cacheDirectory: String) {
        self.init()
        self.status = status
        self.url = url
        self.requestTask = requestTask
        self.cacheDirectory = cacheDirectory
    }
}
public class DownloadManager: NSObject {
    public typealias ProgressHandler = (DownloadResource,Progress) -> Void
    
    public var maxCacheSize = 100 //MB
    public var cacheDicName :String = DownloadCache.defaultCachesDirectory {
        didSet{
            if oldValue == cacheDicName{
                return
            }
            DownloadCache.cachesDirectory = cacheDicName
        }
    }
    public static var `default` = DownloadManager()
    private var downloadResources  = [String:DownloadResource]()
    private var syncdownloadingURLs = [String:URL]()
    public static func resourceDownloadStatus(url:String)->DownloadResourceStatus{
        if let resource = self.default.downloadResources[url]{
            return resource.status
        }
        return .unknow
    }
    public func syncDownloadResources(urls:[String?],cacheDirectoryName:String? = nil,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<[String:URL]>) -> (Void)){
        self.syncdownloadingURLs.removeAll()
        let dispatchGroup = DispatchGroup()
        for url in urls{
            dispatchGroup.enter()
            self.downloadResource(resourcePath: url,cacheDirectoryName: cacheDirectoryName,progress: progress, completionHandler: { (result) -> (Void) in
                switch result{
                case .success(let resourceURL):
                    self.syncdownloadingURLs[url!] = resourceURL
                case .failure(let error): completionHandler(DownloadResult.failure(error))
                case .failureUrl(let error, let path):
                    completionHandler(DownloadResult.failureUrl(error, path))
                }
                dispatchGroup.leave()
            })
        }
        dispatchGroup.notify(queue: .downloadQueue) { [weak self] in
            
            if self?.syncdownloadingURLs.count != urls.count {
                return
            }
            DispatchQueue.main.async {
                completionHandler(DownloadResult.success(self!.syncdownloadingURLs))
            }
        }
    }
    public func asyncDownloadResources(urls:[String?],cacheDirectoryName:String? = nil,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<(String,URL)>) -> (Void)){
        for url in urls{
            downloadResource(resourcePath: url,cacheDirectoryName: cacheDirectoryName,progress: progress){ (result) -> (Void) in
                switch result{
                case .success(let resourceURL):
                    completionHandler(DownloadResult.success((url!,resourceURL)))
                case .failure(let error): completionHandler(DownloadResult.failure(error))
                case .failureUrl(let error, let path):
                    completionHandler(DownloadResult.failureUrl(error, path))
                }
            }
        }
    }
    public static func cancelDownload(_ url:String){
        if let resource = self.default.downloadResources[url] {
            resource.requestTask?.cancel()
            resource.status = .cancel
        }
    }
    public static func cleanAllDownloadFiles(){
        DownloadCache.cleanDownloadFiles()
        for resource in self.default.downloadResources {
            resource.value.status = .cancel
            resource.value.requestTask?.cancel()
        }
    }
    public func resumeDownload(_ resource:String?,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<URL>) -> (Void)){
        
        downloadResource(resourcePath: resource, cacheDirectoryName: nil, progress: progress, completionHandler: completionHandler)
    }
    
    public  func downloadResource(resourcePath: String?,cacheDirectoryName:String? = nil,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<URL>) -> (Void)) {
        
        guard let path = resourcePath, !path.isEmpty else {
            completionHandler(DownloadResult.failure(self.getUrlEmptyError()))
            return
        }
        self.cacheDicName = self.getCacheDirectoryName(resourcePath: path, cacheDirectoryName: cacheDirectoryName)
        if let localUrl = isFileExisted(url: path.url){
            print("播放本地文件")
            completionHandler(DownloadResult.success(localUrl))
            return
        }
        downloadFile(resourceUrl: path, destination: getCacheDestination(url: path.url),progress:progress, completionHandler: {(result) -> (Void) in
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
    func getCacheDirectoryName(resourcePath:String? = nil,cacheDirectoryName:String?)->String{
        if let cacheDirectoryName = cacheDirectoryName{
            return cacheDirectoryName
        }
        if let resource = resourcePath, let cacheDirectoryName = self.downloadResources[resource]?.cacheDirectory{
            return cacheDirectoryName
        }
        return DownloadCache.defaultCachesDirectory
    }
    public func reloadSingleFile(localPath: String, remotePath: String, cacheDirectoryName:String, progress:ProgressHandler? = nil ,completionHandler: @escaping (DownloadResult<URL>) -> (Void)) {
        //  先删除本地的
        DownloadCache.removeItem(atPath: localPath)
        // 再下载
        downloadResource(resourcePath: remotePath, cacheDirectoryName: cacheDirectoryName,progress: progress) { (result) -> (Void) in
            completionHandler(result)
        }
    }
    
    func downloadFile(resourceUrl: String, destination: DownloadRequest.DownloadFileDestination?,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<String>) -> (Void)) {
        
        let downloadResources = self.downloadResources[resourceUrl] ?? DownloadResource(url: resourceUrl,cacheDirectory: DownloadCache.cachesDirectory)
        
        if let data = downloadResources.requestTask?.resumeData{
            downloadResources.requestTask = Alamofire.download(resumingWith: data, to: destination)
            downloadResources.status = .downloading
        }else {
            let downloadRequst = Alamofire.download(resourceUrl, to: destination).validate(statusCode: 200..<400).response { (response) in
                DispatchQueue.main.async {
                    if response.error == nil, let localPath = response.destinationURL?.path {
                        downloadResources.status = .downloaded
                        completionHandler(DownloadResult.success(localPath))
                        return
                    }
                    completionHandler(DownloadResult.failureUrl(response.error!, response.destinationURL?.path))
                }
            }
            downloadResources.status = .downloading
            downloadResources.requestTask = downloadRequst
            self.downloadResources[resourceUrl] = downloadResources
        }
        guard let progress = progress   else {
            return
        }
        downloadResources.requestTask?.downloadProgress(queue: DispatchQueue.main, closure: { (_progress) in
            progress(downloadResources,_progress)
        })
    }
    func isFileExisted(url: URL, prePath: String? = nil) -> URL? {
        var path = self.getCacheUrl(url: url)
        
        if let prePath = prePath{
            path = prePath + path
        }
        
        if  DownloadCache.isFileExist(atPath: path){
            return self.getCacheUrl(url: url).url
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
            let fileURL = self.getCacheUrl(url: url).url
            
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
    }
    
    func getCacheUrl(url: URL) -> String {
        return DownloadCache.cachePath(url: url)
    }
    
    func judgeIfClearCache() {
        if Int(DownloadCache.downloadedFilesSize() / 1000 / 1024) > maxCacheSize {
            DownloadManager.cleanAllDownloadFiles()
        }
    }
}

