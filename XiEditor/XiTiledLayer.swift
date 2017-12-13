//
//  XiTiledLayer.swift
//  XiEditor
//
//  Created by Colin Rofls on 2017-12-08.
//  Copyright © 2017 Raph Levien. All rights reserved.
//

import Cocoa

class XiTiledLayer: CATiledLayer {
    
    override class func fadeDuration() -> CFTimeInterval {
        return 0
    }
}
