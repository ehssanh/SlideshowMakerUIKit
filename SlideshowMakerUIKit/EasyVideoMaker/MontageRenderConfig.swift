//
//  MontageRenderConfig.swift
//  SlideshowMakerUIKit
//
//  Created by ehoor on 2020-11-02.
//

import AVFoundation
import UIKit

enum TransitionEffect : UInt {
    case none
    case crossFade
}

struct MontageRenderConfig {
    
    var size : CGSize
    var transition : TransitionEffect
    var contentMode : UIView.ContentMode
    
    let frameRate : Int32 = 60
    
    var audio : URL?
    func hasAudio() -> Bool {
        return audio != nil
    }
}
