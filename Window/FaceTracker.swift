//
//  FaceTracker.swift
//  Window
//
//  Created by Jonathan Tanner on 05/09/2017.
//  Copyright © 2017 Jonathan Tanner. All rights reserved.
//

import AVFoundation
import UIKit

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

    var midPoint: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

extension CGPoint {
    init(_ a: Double) {
        self = CGPoint(x: a, y: a)
    }

    init(_ a: Int) {
        self = CGPoint(x: a, y: a)
    }

    init(_ a: CGFloat) {
        self = CGPoint(x: a, y: a)
    }

    static func cgPointCombine(_ a: CGPoint, _ b: CGPoint, op: (CGFloat, CGFloat) -> CGFloat) -> CGPoint {
        return CGPoint(x: op(a.x, b.x), y: op(a.y, b.y))
    }

    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return cgPointCombine(lhs, rhs, op: +)
    }

    static func /(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return cgPointCombine(lhs, rhs, op: /)
    }

    static func *(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return cgPointCombine(lhs, rhs, op: *)
    }

    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return cgPointCombine(lhs, rhs, op: -)
        //return cgPointCombine(lhs, rhs, op: {abs($0 - $1)})
    }

    func orientated(to orientation: UIInterfaceOrientation) -> CGPoint {
        switch orientation {
        case .portrait:
            return self
        case .portraitUpsideDown:
            return CGPoint(x: -x, y: -y)
        case .landscapeLeft:
            return CGPoint(x: y, y: -x)
        case .landscapeRight:
            return CGPoint(x: -y, y: x)
        case .unknown:
            return self
        }
    }
}

extension AVCaptureDevice.Format {
    var noPixels: Int {
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        return Int(dimensions.width) * Int(dimensions.height)
    }
}

extension AVCaptureVideoOrientation {
    init(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .unknown:
            self = .portrait
        }

    }
}

class FaceTracker: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let callback: FaceTrackerCallback

    let captureSession: AVCaptureSession
    let captureDevice: AVCaptureDevice!
    let videoInput: AVCaptureDeviceInput
    var preview: AVCaptureVideoPreviewLayer?
    var previewContainer: UIView?

    let metadataOutput: AVCaptureMetadataOutput

    var xyScale: Double = 1
    var zoom: Double = 1
    var zoomCalibrate: Double = 50

    init(callback callbackTMP: @escaping FaceTrackerCallback, previewContainer previewContainerTMP: UIView?) {
        callback = callbackTMP

        captureSession = AVCaptureSession()
        captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        do {try videoInput = AVCaptureDeviceInput(device: captureDevice)} catch {fatalError("No Video Input")}
        metadataOutput = AVCaptureMetadataOutput()
        previewContainer = previewContainerTMP

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
        } catch {
            print(error)
        }
        captureDevice.unlockForConfiguration()

        if previewContainer != nil {
            preview = AVCaptureVideoPreviewLayer(session: captureSession)
            preview!.bounds = previewContainer!.bounds
            preview!.videoGravity = .resizeAspect
            preview!.connection?.videoOrientation = AVCaptureVideoOrientation(UIApplication.shared.statusBarOrientation)
            previewContainer?.widthAnchor
            previewContainer!.widthAnchor.constraint(equalToConstant: preview!.preferredFrameSize().width).isActive = true
            previewContainer!.heightAnchor.constraint(equalToConstant: preview!.preferredFrameSize().height).isActive = true
            previewContainer!.layer.addSublayer(preview!)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()

        metadataOutput.metadataObjectTypes = [.face]
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    }

    deinit {
        captureSession.stopRunning()
    }

    func metadataOutput(_ metadataOutput: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let face = (objects.filter{$0.type == .face}.map{$0.bounds}.max{$0.area < $1.area}) {
            callback(Location(point: (CGPoint(xyScale) * (face.midPoint - CGPoint(0.5))).orientated(to: UIApplication.shared.statusBarOrientation), depth: zoom * 180 / .pi * atan(zoomCalibrate * sqrt(Double(face.area)))))
        }
    }
}
