//
//  UIColor+Hex.swift
//  QuizChallenge
//
//  Created by Eduardo Sanches Bocato on 21/09/19.
//  Copyright © 2019 Bocato. All rights reserved.
//

import UIKit

extension UIColor {
    
    /// Creates a UIColor for it's red, green, and blue values
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    
    /// Creates a UIColor from a hexadecimal representation
    convenience init(from hexValue: String) {
        
        // Remove # if existis
        let tempHex = hexValue.replacingOccurrences(of: "#", with: "")
        
        let hex = Int(tempHex, radix: 16)
        
        if hex != nil {
            self.init(red:(hex! >> 16) & 0xff, green:(hex! >> 8) & 0xff, blue:hex! & 0xff)
        } else {
            assert(hex == nil, "Invalid Hex value")
            self.init(red: 0, green: 0, blue: 0)
        }
    }
    
}
