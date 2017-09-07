//
//  ViewController.swift
//  Window
//
//  Created by Jonathan Tanner on 05/09/2017.
//  Copyright © 2017 Jonathan Tanner. All rights reserved.
//

import UIKit
import SceneKit

class ViewController: UIViewController {
    var faceTracker: FaceTracker!

    @IBOutlet var scnView: SCNView!
    var scene: Scene!
    @IBOutlet var xyScale: UISlider!
    @IBOutlet var zoom: UISlider!
    @IBOutlet var zoomCalibrate: UISlider!
    @IBAction func updateScale() {
        faceTracker.xyScale = Double(xyScale.value)
        faceTracker.zoom = Double(zoom.value)
        faceTracker.zoomCalibrate = Double(zoomCalibrate.value)
    }
    @IBOutlet var previewContainer: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        scene = Scene(scnView: scnView)

        faceTracker = FaceTracker(callback: scene.setViewLocation, previewContainer: previewContainer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func update() {

    }
}

