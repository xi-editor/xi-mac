//
//  DefinitionTableView.swift
//  XiEditor
//
//  Created by Dzũng Lê on 7/11/18.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa


class DefinitionTableView: NSTableView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func updateTrackingAreas() {
        for area in self.trackingAreas {
            self.removeTrackingArea(area)
        }
        let newTrackingArea = NSTrackingArea(rect: self.bounds, options: [.activeInActiveApp, .mouseEnteredAndExited], owner: self, userInfo: nil)
        self.addTrackingArea(newTrackingArea)
    }

}

class DefinitionTableCellView: NSTableCellView {
    @IBOutlet weak var methodField: NSTextField!
    @IBOutlet weak var locationField: NSTextField!

    private var hover = false {
        didSet {
            setNeedsDisplay(bounds)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !hover {
            hover = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if hover {
            hover = false
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.controlHighlightColor.setFill()
        if hover {
            let path = NSBezierPath(rect: bounds)
            path.fill()
        }
        let rect = NSRect(x: 0, y: bounds.height - 2, width: bounds.width, height: bounds.height)
        let path = NSBezierPath(rect: rect)
        path.fill()
    }
}
