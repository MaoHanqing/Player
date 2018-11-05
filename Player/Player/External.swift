//
//  External.swift
//  Player
//
//  Created by hanqing.mao on 2018/11/5.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import UIKit
import Kingfisher
//下载图片
extension DownloadManager {
    typealias  ImageOperationHandler = ((UIImage) -> UIImage)
    static func downloadImage(with url: String?, timeOut: Double = 3, imageOperationHandler: ImageOperationHandler? = nil, completionHandler:@escaping (UIImage?, NSError?) -> Void) {
        guard let urlString = url, let imageURL = URL(string: urlString) else {
            completionHandler(nil, NSError(domain: "url is empty", code: 500, userInfo: nil))
            return
        }
        let key = imageOperationHandler == nil ? urlString : urlString + "_operation"
        ImageCache.default.retrieveImage(forKey: key, options: nil) { (image, _) in
            if let image = image {
                completionHandler(image, nil)
                return
            }
            let downLoader = ImageDownloader(name: "alo7IconDownloader")
            downLoader.downloadTimeout = 3
            downLoader.downloadImage(with: imageURL, retrieveImageTask: nil, options: nil, progressBlock: nil, completionHandler: { (image, error, _, _) in
                if var image = image {
                    if imageOperationHandler != nil {
                        image = imageOperationHandler!(image)
                    }
                    ImageCache.default.store(image, forKey: key)
                }
                completionHandler(image, error)
            })
        }
    }
    static func downloadImage(with url: String?, blendMode: CGBlendMode, backgroundColor: UIColor = UIColor.white, completionHandler:@escaping (UIImage?) -> Void) {
        self.downloadImage(with: url,
                           imageOperationHandler: { (image) -> UIImage in
                            return image.kf.image(withBlendMode: blendMode, backgroundColor: backgroundColor)
        }, completionHandler: { (image, _) in
            completionHandler(image)
        })
    }
}
