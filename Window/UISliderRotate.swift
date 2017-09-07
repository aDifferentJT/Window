//
//  UISliderRotate.swift
//  Window
//
//  Created by Jonathan Tanner on 07/09/2017.
//  Copyright © 2017 Jonathan Tanner. All rights reserved.
//

import UIKit

@IBDesignable
class UISliderRotate: UISlider {
    @IBInspectable var rotation: CGFloat = 0 {
        didSet {
            transform = CGAffineTransform(rotationAngle: rotation * CGFloat(Double.pi) / 180)
        }
    }
}
