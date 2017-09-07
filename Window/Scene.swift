//
//  Scene.swift
//  Window
//
//  Created by Jonathan Tanner on 06/09/2017.
//  Copyright © 2017 Jonathan Tanner. All rights reserved.
//

import SceneKit
import ImageIO

  func UIImageCreateWithHDR(named name: String) -> UIImage {
    if let imageURL = Bundle.main.url(forResource: name, withExtension: "hdr") {
        if let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, [kCGImageSourceTypeIdentifierHint: "public.radiance"] as CFDictionary) {
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, [kCGImageSourceShouldAllowFloat: true, kCGImageSourceShouldCache: true, kCGImageSourceCreateThumbnailFromImageIfAbsent: false, kCGImageSourceCreateThumbnailFromImageAlways: false] as CFDictionary) {
                return UIImage(cgImage: cgImage)
            }
        } else {
            fatalError("No Image Source")
        }
    } else {
        fatalError("No Image URL")
    }
    return UIImage()
}

class Scene {
    let scnView: SCNView

    init(scnView scnViewTMP: SCNView) {
        scnView = scnViewTMP
        scnView.isUserInteractionEnabled = false
        scnView.scene = SCNScene()
        scnView.scene!.background.contents = #imageLiteral(resourceName: "snowy.hdr")

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.eulerAngles = SCNVector3Make(0, 0, 0)
        cameraNode.position = SCNVector3Make(0, 0, 0)
        scnView.scene!.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
    }

    func setViewLocation(_ location: Location) {
        scnView.pointOfView?.eulerAngles.x = Float(location.x)
        scnView.pointOfView?.eulerAngles.y = Float(location.y)
        if #available(iOS 11.0, *) {
            scnView.pointOfView?.camera?.fieldOfView = CGFloat(location.z)
        } else {
            scnView.pointOfView?.camera?.xFov = location.z
        }
    }
}
