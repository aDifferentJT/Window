//
//  FaceTracker.swift
//  Window
//
//  Created by Jonathan Tanner on 05/09/2017.
//  Copyright © 2017 Jonathan Tanner. All rights reserved.
//

import Vision
import AVFoundation

struct Location {
    var x: Double
    var y: Double
    var z: Double

    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(point: CGPoint, depth: Double) {
        self.x = Double(point.x)
        self.y = Double(point.y)
        self.z = depth
    }
}

typealias FaceTrackerCallback = (Location) -> Void

extension CGRect {
    var area: CGFloat {
        return width * height
    }
}

extension AVCaptureDevice.Format {
    var noPixels: Int {
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        return Int(dimensions.width) * Int(dimensions.height)
    }
}

class FaceTracker: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let callback: FaceTrackerCallback

    let captureSession: AVCaptureSession
    let captureDevice: AVCaptureDevice!
    let videoInput: AVCaptureDeviceInput
    let videoDispatchQueue: DispatchQueue

    let metadataOutput: AVCaptureMetadataOutput

    var xyScale: Double = 1
    var zoom: Double = 1
    var zoomCalibrate: Double = 50

    init(callback callbackTMP: @escaping FaceTrackerCallback) {
        callback = callbackTMP

        captureSession = AVCaptureSession()
        captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        do {try videoInput = AVCaptureDeviceInput(device: captureDevice)} catch {fatalError("No Video Input")}
        videoDispatchQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive, autoreleaseFrequency: .workItem)
        metadataOutput = AVCaptureMetadataOutput()

        super.init()

        guard captureDevice != nil else {fatalError("No Capture Device")}

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .low
        captureSession.addInput(videoInput)
        captureSession.addOutput(metadataOutput)
        do {
            try captureDevice.lockForConfiguration()
            if let format = (captureDevice.formats.filter{$0.mediaType == .video}.min{$0.noPixels < $1.noPixels}) {
                captureDevice.activeFormat = format
            }
            captureDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
        captureDevice.unlockForConfiguration()
        captureSession.commitConfiguration()
        captureSession.startRunning()

        metadataOutput.metadataObjectTypes = [.face]
        metadataOutput.setMetadataObjectsDelegate(self, queue: videoDispatchQueue)
    }

    deinit {
        captureSession.stopRunning()
    }

    func metadataOutput(_ metadataOutput: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let face = (objects.filter{$0.type == .face}.map{$0.bounds}.max{$0.area < $1.area}) {
            callback(Location(x: xyScale * (Double(face.midY) - 0.5), y: xyScale * (0.5 - Double(face.midX)), z: zoom * 180 / .pi * atan(zoomCalibrate * sqrt(Double(face.area)))))
        }
    }

    func findFace(in image: CVImageBuffer) {
    }
}
