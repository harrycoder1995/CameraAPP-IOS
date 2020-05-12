//
//  ViewController.swift
//  CameraApp
//
//  Created by Harendra Rana on 05/05/20.
//  Copyright © 2020 Harendra Rana. All rights reserved.
//

import UIKit

class CameraViewController: UIViewController {
    
    
    @IBOutlet weak var currentCaptured: UIImageView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var flashModeButton: UIButton!
    
    lazy var cameraManager = CameraManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        customizeUI()
        cameraManager.prepare { (error) in
            if error != nil {
                print("Error while configure capture session")
            }
            
            try? self.cameraManager.displayPreviewLayer(on: self.view)
        }
    }
    
    func customizeUI() {
        currentCaptured.contentMode = UIView.ContentMode.scaleAspectFill
        currentCaptured.layer.cornerRadius = currentCaptured.frame.height / 2
        currentCaptured.layer.masksToBounds = false
        currentCaptured.clipsToBounds = true
        captureButton.layer.borderColor = UIColor.black.cgColor
        captureButton.layer.borderWidth = 2
        captureButton.layer.cornerRadius = captureButton.frame.width/2
    }
    
    @IBAction func captureButtonPressed(_ sender: UIButton) {
        if cameraManager.isVideoMode == true {
            recordVideo()
        } else {
            captureImage()
        }
        
    }
    
    @IBAction func rotateCameraButtonPressed(_ sender: UIButton) {
        try? cameraManager.switchCamera()
    }
    
    @IBAction func flashButtonPressed(_ sender: UIButton) {
        if cameraManager.flashMode == .on {
            cameraManager.flashMode = .off
            flashModeButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        }else {
            cameraManager.flashMode = .on
            flashModeButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        }
    }
    
    @IBAction func switchMode(_ sender: UISegmentedControl) {
        
        if sender.selectedSegmentIndex == 0 {
            cameraManager.isVideoMode = false
            try? cameraManager.configurePhotoOutput()
        }else {
            cameraManager.isVideoMode = true
            try? cameraManager.configureVideoOutput()
        }
    }
    
    func captureImage() {
        cameraManager.captureImage { (image, error) in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            
            if image != nil {
                DispatchQueue.main.async {
                    self.currentCaptured.image = image
                }
            }
        }
    }
    
    func recordVideo() {
        cameraManager.recordVideo { (outputFileUrl, error) in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            
            if outputFileUrl != nil {
                //                DispatchQueue.main.async {
                //                    self.currentCaptured
                //                }
            }
        }
    }
}

