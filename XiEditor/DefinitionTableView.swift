// Copyright 2018 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa

class DefinitionTableView: NSTableView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}

class DefinitionTableRowView: NSTableRowView {
    @IBOutlet weak var methodField: NSTextField!
    @IBOutlet weak var locationField: NSTextField!

    // MARK: - Mouse hover effect
    deinit {
        removeTrackingArea(trackingArea)
    }

    private var trackingArea: NSTrackingArea!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.alternateSelectedControlColor.set()
        // Fill on mouse hover
        if hover {
            let path = NSBezierPath(rect: bounds)
            path.fill()
            self.methodField.textColor = NSColor.alternateSelectedControlTextColor
            self.locationField.textColor = NSColor.alternateSelectedControlTextColor
        } else {
            self.methodField.textColor = NSColor.textColor
            self.locationField.textColor = NSColor.textColor
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        super.drawSelection(in: dirtyRect)

        NSColor.alternateSelectedControlColor.set()
        let rect = NSRect(x: 0, y: bounds.height - 2, width: bounds.width, height: bounds.height)
        let path = NSBezierPath(rect: rect)
        path.fill()
    }

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
}
