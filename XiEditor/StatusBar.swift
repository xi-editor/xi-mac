//
//  StatusBar.swift
//  XiEditor
//
//  Created by Dzũng Lê on 19/05/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Foundation
import Cocoa

class StatusBar: NSView {

    private let backgroundColor = NSColor(deviceWhite: 0.9, alpha: 1.0)
    private let statusBarHeight: CGFloat = 15

    func drawStatusBar(_ gutterWidth: CGFloat, _ renderer: Renderer, _ dirtyRect: NSRect) {
        renderer.drawSolidRect(x: GLfloat(gutterWidth), y: GLfloat(dirtyRect.height - statusBarHeight), width: GLfloat(dirtyRect.width), height: GLfloat(statusBarHeight), argb: colorToArgb(NSColor.white))
    }
}
