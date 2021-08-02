//
//  SandboxImageApiViewController.swift
//  Psorcast
//
//  Created by Michael L DePhillips on 6/9/21.
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
//
// TODO: delete file after image api is validated

import UIKit
import SDWebImage
import BridgeSDK

open class SandboxImageApiViewController: UIViewController {
    
    @IBOutlet weak var srcImageView: UIImageView!
    @IBOutlet weak var downloadedImageView: UIImageView!
    
    @IBOutlet weak var uploadIndicator: UIActivityIndicatorView!
    @IBOutlet weak var downloadIndicator: UIActivityIndicatorView!
    
    var fileDownloadUrl: URL? = URL(string: "https://webservices.sagebridge.org/v3/participants/self/files/fileUploadTest")
    
    var srcImage: UIImage? {
        return UIImage(named: "ImageApiTest")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.srcImageView.image = self.srcImage
        
        // Check for when new videos are created
        NotificationCenter.default.addObserver(forName: .SBBParticipantFileUploaded, object: nil, queue: OperationQueue.main) { notification in
            
            self.uploadIndicator.isHidden = true
            print("Image uploaded successfully with user info \(String(describing: notification.userInfo))")
            let requestUrlKey = ParticipantFileUploadManager.shared.requestUrlKey
            self.fileDownloadUrl = notification.userInfo?[requestUrlKey] as? URL
        }
        
        NotificationCenter.default.addObserver(forName: .SBBParticipantFileUploadRequestFailed, object: nil, queue: OperationQueue.main) { notification in
            self.uploadIndicator.isHidden = true
            print("Image upload request failed: \(String(describing: notification.userInfo))")
        }
        
        NotificationCenter.default.addObserver(forName: .SBBParticipantFileUploadToS3Failed, object: nil, queue: OperationQueue.main) { notification in
            self.uploadIndicator.isHidden = true
            print("Image upload to S3 failed: \(String(describing: notification.userInfo))")
        }
    }
    
    @IBAction func uploadTapped() {
        let fileId = "fileUploadTest"
        
        do {
            if let data = self.srcImage?.jpegData(compressionQuality: 0.5) {
                let filepath = getDocumentsDirectory().appendingPathComponent("\(fileId).jpg")
                
                try data.write(to: filepath)
                
                self.uploadIndicator.isHidden = false
                
                ParticipantFileUploadManager.shared.upload(fileId: fileId, fileUrl: filepath, contentType: PSRImageHelper.contentTypePng)
            }
        } catch {
            print("Error writing image to file")
        }
    }
    
    @IBAction func downloadTapped() {
        // TODO: load image url into image view using SDImage library
        // NOTE: To download the file, we need to do a GET to self.fileDownloadUrl with
        // the Bridge-Session header set (following the resulting redirect).
        // I don't know how to set session headers with this library. ~emm 2021-07-20
        //self.downloadedImageView?.sd_setImage(with: self.fileDownloadUrl, completed: nil)
        
        var header: NSMutableDictionary = [:]
        let imageDownloader = SDWebImageDownloader.shared
        BridgeSDK.authManager.addAuthHeader(toHeaders: header)
        header.keyEnumerator().forEach { (key) in
            if let keyStr = key as? String,
               let valStr = header[keyStr] as? String {
                imageDownloader.setValue(valStr, forHTTPHeaderField: keyStr)
            }
        }
        
        self.downloadIndicator.isHidden = false
        imageDownloader.downloadImage(with: self.fileDownloadUrl) { (image, data, error, success) in
            self.downloadIndicator.isHidden = true
            self.downloadedImageView?.image = image
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
