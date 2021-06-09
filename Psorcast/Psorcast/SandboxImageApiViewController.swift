//
//  SandboxImageApiViewController.swift
//  Psorcast
//
//  Created by Michael L DePhillips on 6/9/21.
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
//
// TODO: delete file after image api is validated

import UIKit

open class SandboxImageApiViewController: UIViewController {
    @IBOutlet weak var srcImageView: UIImageView!
    @IBOutlet weak var downloadedImageView: UIImageView!
    
    var srcImage: UIImage? {
        return UIImage(named: "ImageApiTest")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.srcImageView.image = self.srcImage
        
        // Check for when new videos are created
        NotificationCenter.default.addObserver(forName: .SBBParticipantFileUploaded, object: ParticipantFileUploadManager.shared, queue: OperationQueue.main) { (notification) in
            
            print("Image uploaded successfully with user info \(String(describing: notification.userInfo))")
        }
    }
    
    @IBAction func uploadTapped() {
        let fileId = "fileUploadTest"
        
        do {
            if let data = self.srcImage?.pngData() {
                let filepath = getDocumentsDirectory().appendingPathComponent("\(fileId).png")
                
                try data.write(to: filepath)
                
                ParticipantFileUploadManager.shared.upload(fileId: fileId, fileURL: filepath, contentType: PSRImageHelper.contentTypePng)
            }
        } catch {
            print("Error writing image to file")
        }
    }
    
    @IBAction func downloadTapped() {
        // TODO: load image url into image view using SDImage library
        // self.downloadedImageView?.sd_setImage(with: url, completed: nil)
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
