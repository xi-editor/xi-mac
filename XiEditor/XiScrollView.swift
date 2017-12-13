//
//  ScrollViewToo.swift
//  XiEditor
//
//  Created by Colin Rofls on 2017-12-12.
//  Copyright © 2017 Raph Levien. All rights reserved.
//

import Cocoa

class XiScrollView: NSScrollView {

    // NOTE: overriding scrollWheel: is necessary in order to disable responsiveScrolling
    // we don't like responsive scrolling because it is harder to predict when we will
    // be asked to draw, and so harder to ensure we have the necessary lines.
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        //        print("scroll event \(event)")
    }
}
