//
//  XiClipView.swift
//  XiEditor
//
//  Created by Colin Rofls on 2017-12-10.
//  Copyright © 2017 Raph Levien. All rights reserved.
//

import Cocoa

protocol ScrollInterested {
    func willScroll(to newOrigin: NSPoint);
}

class XiClipView: NSClipView {
    var delegate: ScrollInterested?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }

    override func scroll(to newOrigin: NSPoint) {
        delegate?.willScroll(to: newOrigin)
        super.scroll(to: newOrigin)
    }
}
