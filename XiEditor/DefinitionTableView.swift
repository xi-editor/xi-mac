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

}

class DefinitionTableRowView: NSTableRowView {
    @IBOutlet weak var methodField: NSTextField!
    @IBOutlet weak var locationField: NSTextField!

    // MARK: - Mouse hover
    deinit {
        removeTrackingArea(trackingArea)
    }

    private var trackingArea: NSTrackingArea!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.trackingArea = NSTrackingArea(
            rect: frame,
            options: [.activeAlways,.mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.00).set()
        // mouse hover
        if highlight {
            let path = NSBezierPath(rect: bounds)
            path.fill()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        super.drawSelection(in: dirtyRect)
    }

    private var highlight = false {
        didSet {
            setNeedsDisplay(bounds)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !highlight {
            highlight = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if highlight {
            highlight = false
        }
    }
}
