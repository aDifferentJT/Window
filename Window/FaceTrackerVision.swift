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

    var midPoint: CGPoint {
        return CGPoint(x: midX, y: midY)
    }

    func grow(factor: CGFloat) -> CGRect {
        return CGRect(x: midX - (width * factor / 2), y: midY - (height * factor / 2), width: width * factor, height: height * factor)
    }
}

protocol Averageable {
    init(_: Int)
    static func +(lhs: Self, rhs: Self) -> Self
    static func /(lhs: Self, rhs: Self) -> Self
}

extension Array where Element: Averageable {
    func average() -> Element {
        return map{(x) -> Element in x / Element.init(count)}.reduce(Element.init(0), +)
    }
}

extension CGPoint: Averageable {
    init(_ a: Int) {
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
        return cgPointCombine(lhs, rhs, op: {abs($0 - $1)})
    }
}

extension VNFaceLandmarks2D {
    var interEyeDistance: Double {
        guard leftEye != nil && rightEye != nil else {return Double.nan}
        let leftEyeCenter = leftEye!.normalizedPoints.average()
        let rightEyeCenter = rightEye!.normalizedPoints.average()
        let distance = rightEyeCenter - leftEyeCenter
        return Double((distance.x * distance.x) + (distance.y * distance.y))
    }

    var averageEye: CGPoint {
        guard leftEye != nil && rightEye != nil else {return CGPoint(0)}
        let leftEyeCenter = leftEye!.normalizedPoints.average()
        let rightEyeCenter = rightEye!.normalizedPoints.average()
        return (leftEyeCenter + rightEyeCenter) / CGPoint(2)
    }
}

extension VNFaceObservation: Comparable {
    public static func <(lhs: VNFaceObservation, rhs: VNFaceObservation) -> Bool {
        guard lhs.landmarks != nil && rhs.landmarks != nil else {return true}
        return lhs.landmarks!.interEyeDistance < rhs.landmarks!.interEyeDistance
    }

    public static func ==(lhs: VNFaceObservation, rhs: VNFaceObservation) -> Bool {
        guard lhs.landmarks != nil && rhs.landmarks != nil else {return true}
        return lhs.landmarks!.interEyeDistance == rhs.landmarks!.interEyeDistance
    }

    func transform(feature: CGPoint) -> CGPoint {
        return boundingBox.origin + (feature * CGPoint(x: boundingBox.width, y: boundingBox.height))
    }
}

class FaceTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let callback: FaceTrackerCallback

    let captureSession: AVCaptureSession
    let captureDevice: AVCaptureDevice!
    let videoInput: AVCaptureDeviceInput
    let videoOutput: AVCaptureVideoDataOutput
    let videoDispatchQueue: DispatchQueue

    enum FaceDetectType {
        case full, track
    }
    var faceDetectType: FaceDetectType
    var imageHandler: VNImageRequestHandler?
    var sequenceHandler: VNSequenceRequestHandler?
    var noOfTracks = 0
    var face: VNFaceObservation?

    init(callback callbackTMP: @escaping FaceTrackerCallback) {
        callback = callbackTMP

        captureSession = AVCaptureSession()
        captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        do {try videoInput = AVCaptureDeviceInput(device: captureDevice)} catch {fatalError("No Video Input")}
        videoOutput = AVCaptureVideoDataOutput()
        videoDispatchQueue = DispatchQueue(label: "videoFaceTrackingQueue", qos: .userInteractive, autoreleaseFrequency: .workItem)

        faceDetectType = .full

        super.init()

        guard captureDevice != nil else {fatalError("No Capture Device")}

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoDispatchQueue)

        captureSession.addInput(videoInput)
        captureSession.addOutput(videoOutput)
        captureSession.startRunning()
    }

    deinit {
        captureSession.stopRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let image = CMSampleBufferGetImageBuffer(buffer) {
            findFace(in: image)
        }
    }

/*
    func findFace(in image: CVImageBuffer) {
        imageHandler = VNImageRequestHandler(cvPixelBuffer: image)

        if face == nil {
            faceDetectType = .full
        }
        switch faceDetectType {
        case .track:
            if noOfTracks >= 16 {
                noOfTracks = 0
                sequenceHandler = nil
                fallthrough
            }
            print("track")
            if sequenceHandler == nil {
                sequenceHandler = VNSequenceRequestHandler()
            }
            noOfTracks += 1
            let trackRequest = VNTrackObjectRequest(detectedObjectObservation: face!, completionHandler: processFace)
            trackRequest.trackingLevel = .accurate
            do {
                try sequenceHandler!.perform([trackRequest], on: CIImage(cvImageBuffer: image))
            } catch {
                print("Sequence Handler Threw")
                print(error)
                fallthrough
            }
        case .full:
            print("full")
            let faceRequest = VNDetectFaceRectanglesRequest(completionHandler: processFace)
            do {
                try imageHandler!.perform([faceRequest])
            } catch {
                return
            }

            sequenceHandler = nil
            faceDetectType = .track
        }
    }

    func processFace(request: VNRequest, error: Error?) {
        guard error == nil else {return}

        if let faceRectangle = ((request.results as! [VNDetectedObjectObservation]).map{$0.boundingBox}.max{$0.area < $1.area}) {
            findFaceInBox(faceRectangle: faceRectangle)
        } else {
            self.face = nil
        }
    }

    func findFaceInBox(faceRectangle: CGRect?) {
        let landmarksRequest = VNDetectFaceLandmarksRequest(){request, error in
            guard error == nil else {self.face = nil; return}

            self.face = (request.results as! [VNFaceObservation]).max(by: {guard $0.landmarks != nil && $1.landmarks != nil else {return true}; return $0.landmarks!.interEyeDistance < $1.landmarks!.interEyeDistance})
            if let landmarks = self.face?.landmarks {
                self.callback(Location(point: self.face!.transform(feature: landmarks.averageEye), depth: landmarks.interEyeDistance))
            } else {
                self.face = nil
            }
        }
        if let faceRectangle = faceRectangle {
            landmarksRequest.inputFaceObservations = [VNFaceObservation(boundingBox: faceRectangle)]
        }
        do {
            try imageHandler!.perform([landmarksRequest])
        } catch {
            return
        }
    }
*/
}
