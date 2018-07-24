//
//  DownloadHelper.swift
//  alo7-student
//
//  Created by ken.zhang on 2017/12/19.
//  Copyright © 2017年 alo7. All rights reserved.
//

import UIKit

/// MARK:- url helper

public let FileErrorDomain = "FileErrorDomain"

// MARK:-  result help

public enum DownloadResult<T> {
    case failure(Error)
    case success(T)
    case failureUrl(Error, String?)
}

public enum FileError: Int {
    
    case badURL = 9981
    case fileIsExist = 9982
    case fileInfoError = 9983
    case invalidStatusCode = 9984
    case diskOutOfSpace = 9985
    case downloadCanceled = -999
    
}

public protocol FileURL {
    
    func asURL() throws -> URL
}

extension String: FileURL {
    
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else { throw    NSError(domain: FileErrorDomain, code: FileError.badURL.rawValue, userInfo: ["url":self]) }
        return url
    }
    
    
    var url: URL {
        
        return URL(fileURLWithPath: self)
    }
}

extension URL: FileURL {
    public func asURL() throws -> URL {
        
        return self
        
    }
}

extension DispatchQueue {
    
    static let downloadQueue = DispatchQueue(label: "DownloadFileQueue",attributes: .concurrent)
    
}
