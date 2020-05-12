//
//  CameraManager.swift
//  CameraApp
//
//  Created by Harendra Rana on 06/05/20.
//  Copyright © 2020 Harendra Rana. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import Photos

private enum CameraControllerError: Swift.Error {
    case captureSessionAlreadyRunning
    case captureSessionIsMissing
    case inputsAreInvalid
    case invalidOperation
    case noCamerasAvailable
    case unknown
}

public enum CameraPosition {
    case front
    case rear
}

class CameraManager: NSObject {
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var rearCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    var frontCameraInput: AVCaptureDeviceInput?
    var currentPosition: CameraPosition?
    
    var photoCapture: AVCapturePhotoOutput?
    var movieRecorder: AVCaptureMovieFileOutput?
    var requestedPhotoSettings: AVCapturePhotoSettings?
    
    var flashMode = AVCaptureDevice.FlashMode.off
    
    var photoData: Data?
    var isVideoMode: Bool = false
    
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var movieRecorderCompletionBlock: ((URL?,Error?)->())?
    
    
    func prepare(completion: @escaping (Error?)->()) {
        DispatchQueue(label: "prepare").async {
            do{
                self.configureCaptureSession()
                try self.configureCaptureDevice()
                try self.configureDeviceInput()
                try self.configurePhotoOutput()
                
            } catch {
                
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    private func configureCaptureSession() {
        captureSession = AVCaptureSession()
    }
    
    private func configureCaptureDevice() throws {
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera,.builtInDualCamera], mediaType: .video, position: .unspecified)
        
        let cameraDevices = discoverySession.devices.compactMap{ $0 }
        
        if cameraDevices.isEmpty {
            throw CameraControllerError.noCamerasAvailable
        }
        
        for camera in cameraDevices {
            
            if camera.position == .back {
                rearCamera = camera
                try camera.lockForConfiguration()
                camera.focusMode = .continuousAutoFocus
                camera.unlockForConfiguration()
            }else if camera.position == .front {
                frontCamera = camera
            }
            
            
        }
    }
    
    private func configureDeviceInput() throws {
        guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
        
        if let rearCamera = rearCamera {
            rearCameraInput = try AVCaptureDeviceInput.init(device: rearCamera)
            
            if captureSession.canAddInput(rearCameraInput!) {
                captureSession.addInput(rearCameraInput!)
            }
            
            currentPosition = .rear
            
        } else if let frontCamera = frontCamera {
            frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(frontCameraInput!) {
                captureSession.addInput(frontCameraInput!)
            } else {
                throw CameraControllerError.inputsAreInvalid
            }
            
            currentPosition = .front
            
        } else {
            throw CameraControllerError.noCamerasAvailable
        }
    }
    
    func configurePhotoOutput() throws {
        guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
        
        if movieRecorder != nil {
            captureSession.removeOutput(movieRecorder!)
        }
        
        photoCapture = AVCapturePhotoOutput()
        photoCapture?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
        
        if captureSession.canAddOutput(photoCapture!) {
            captureSession.addOutput(photoCapture!)
        }
        
        captureSession.startRunning()
    }
    
    func configureVideoOutput() throws {
        guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
        
        if photoCapture != nil {
            captureSession.removeOutput(photoCapture!)
        }
        
        let microphone = AVCaptureDevice.default(for: .audio)
        
        do {
            let micInput = try AVCaptureDeviceInput(device: microphone!)
            
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
            }
        } catch {
            throw CameraControllerError.inputsAreInvalid
        }
        
        movieRecorder = AVCaptureMovieFileOutput()
        
        if captureSession.canAddOutput(movieRecorder!) {
            captureSession.beginConfiguration()
            captureSession.addOutput(movieRecorder!)
            captureSession.sessionPreset = .high
            if let connection = movieRecorder?.connection(with: .video) {
                connection.preferredVideoStabilizationMode = .auto
            }
            
            captureSession.commitConfiguration()
            
        }
        
        captureSession.startRunning()
    }
    
    func displayPreviewLayer(on view: UIView) throws {
        guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(previewLayer!, at: 0)
        previewLayer?.frame = view.frame
    }
    
    //To Switch Cameras
    
    func switchCamera() throws {
        
        guard let cameraCurrentPosition = currentPosition, let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
        
        captureSession.beginConfiguration()
        
        if cameraCurrentPosition == .front {
            try switchToRearCameras(captureSession)
        }else if cameraCurrentPosition == .rear {
            try switchToFrontCameras(captureSession)
        }
        
        captureSession.commitConfiguration()
        
    }
    
    private func switchToFrontCameras(_ captureSession: AVCaptureSession) throws {
        let inputs = captureSession.inputs
        guard let rearCameraInput = rearCameraInput, inputs.contains(rearCameraInput), let frontCamera = frontCamera else {throw CameraControllerError.invalidOperation}
        
        frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
        captureSession.removeInput(rearCameraInput)
        
        if captureSession.canAddInput(frontCameraInput!) {
            captureSession.addInput(frontCameraInput!)
            self.currentPosition = .front
        }else {
            throw CameraControllerError.invalidOperation
        }
    }
    
    private func switchToRearCameras(_ captureSession: AVCaptureSession) throws {
        let inputs = captureSession.inputs
        guard let frontCameraInput = frontCameraInput, inputs.contains(frontCameraInput), let rearCamera = rearCamera else {throw CameraControllerError.invalidOperation}
        
        rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
        captureSession.removeInput(frontCameraInput)
        
        if captureSession.canAddInput(rearCameraInput!) {
            captureSession.addInput(rearCameraInput!)
            self.currentPosition = .rear
        }else {
            throw CameraControllerError.invalidOperation
        }
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?)->()) {
        guard let captureSession = captureSession, captureSession.isRunning else {
            completion(nil, CameraControllerError.captureSessionIsMissing )
            return
        }
        
        requestedPhotoSettings = AVCapturePhotoSettings()
        requestedPhotoSettings?.flashMode = self.flashMode
        photoCapture?.capturePhoto(with: requestedPhotoSettings!, delegate: self)
        photoCaptureCompletionBlock = completion
    }
    
    func recordVideo(completion: @escaping(URL?,Error?)->()) {
        
        if movieRecorder?.isRecording == true {
            movieRecorder?.stopRecording()
        } else {
            let movieFileOutputConnection = movieRecorder?.connection(with: .video)
            movieFileOutputConnection?.videoOrientation = .portrait
            
            let availableVideoCodecTypes = movieRecorder?.availableVideoCodecTypes
            
            if availableVideoCodecTypes?.contains(.hevc) == true {
                movieRecorder?.setOutputSettings([AVVideoCodecKey : AVVideoCodecType.hevc], for: movieFileOutputConnection!)
            }
            
            let outputFileName = NSUUID().uuidString
            let outputPath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
            movieRecorder?.startRecording(to: URL(fileURLWithPath: outputPath), recordingDelegate: self)
            
            movieRecorderCompletionBlock = completion
        }
    }
}


extension CameraManager: AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            photoCaptureCompletionBlock?(nil,error)
        }else if let data = photo.fileDataRepresentation() {
            photoData = data
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            photoCaptureCompletionBlock?(nil,error)
        }else if let photoData = photoData {
            PHPhotoLibrary.requestAuthorization { (status) in
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        options.uniformTypeIdentifier = self.requestedPhotoSettings?.processedFileType.map { $0.rawValue }
                        creationRequest.addResource(with: .photo, data: photoData, options: options)
                    }) { (_, error) in
                        self.photoCaptureCompletionBlock?(nil,error)
                    }
                }
                let image = UIImage(data: photoData)
                self.photoCaptureCompletionBlock?(image,nil)
            }
        }else {
            photoCaptureCompletionBlock?(nil,CameraControllerError.unknown)
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        if error != nil {
            print("Movie file finishing error: \(String(describing: error))")
            movieRecorderCompletionBlock?(nil,error)
        }else {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    // Save the movie file to the photo library and cleanup.
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                        self.movieRecorderCompletionBlock?(outputFileURL,nil)
                    }, completionHandler: { success, error in
                        if !success {
                            print("CameraApp couldn't save the movie to your photo library: \(String(describing: error))")
                        }
                        self.clean(outputFileURL)
                    }
                    )
                } else {
                    self.clean(outputFileURL)
                }
            }
        }
    }
    
    func clean(_ outputFileURL: URL) {
        let path = outputFileURL.path
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                print("Could not remove file at url: \(outputFileURL)")
            }
        }
    }
    
}
