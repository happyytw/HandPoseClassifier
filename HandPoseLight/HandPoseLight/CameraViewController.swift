//
//  ViewController.swift
//  HandPoseLight
//
//  Created by Taewon Yoon on 2023/07/18.
//

import UIKit
import AVFoundation
import Vision
import CoreML

class CameraViewController: UIViewController {
//    private var cameraView = CameraView() //{ view as! CameraView }
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    @IBOutlet var preview: UIView!
    
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil

    private let session = AVCaptureSession()
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    let model = HandClassifier()

    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()

    
    // Vision parts
    private var requests = [VNRequest]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // This sample app detects one hand only.
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.revision = VNDetectHumanRectanglesRequestRevision1
        
        // setting camera
        setupAVCapture()
        
        
        // start the capture
        startCaptureSession()
        
        let S = URLSession(configuration: .default)
        let req = URLRequest(url: URL(string: "http://172.30.1.70:3000/gpio/setup")!)
        S.dataTask(with: req)

    }
    
 
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!

        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = preview.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }

    
    func startCaptureSession(){
        DispatchQueue.global().async {
            self.session.startRunning()
        }
    }
    
    func sendToRas(value: String) async {
        let ses = URLSession(configuration: .default)
        if(value == "paper") {
            ses.dataTask(with: URLRequest(url: URL(string: "http://172.30.1.70:3000/gpio/on")!)) { data, response, error in
                if let error = error {
                    print("Error in URL: \(error)")
                    return
                }
                print("켜기")
            }.resume()
            
        } else if(value == "rock") {
            ses.dataTask(with: URLRequest(url: URL(string: "http://172.30.1.70:3000/gpio/off")!)) { data, response, error in
                if let error = error {
                    print("Error in URL: \(error)")
                    return
                }
                print("켜기")
            }.resume()
        }
    }
    
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, options: [:])
        do {
            try handler.perform([handPoseRequest])
        } catch {
            assertionFailure("Human Pose Request failed: \(error)")
        }
        
        do {
            if let handKeypoints = try handPoseRequest.results?.first?.keypointsMultiArray(),
               let prediction = try? model.prediction(poses: handKeypoints) {
                print(prediction.label)
                Task {
                    await sendToRas(value: prediction.label)
                }
                } else {
                    print("손 없다")
                }
            
        } catch {
            print("crash1")
        }

    }
}
