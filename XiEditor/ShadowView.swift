// Copyright 2016 Google Inc. All rights reserved.
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
/// A custom view that draws a shadow over the editView when content is clipped.
/// Note: - if we ever move to layer-based drawing this should be handled by a layer on the EditViewContainer
class ShadowView: NSView {
    private var topShadow = false
    private var leadingShadow = false
    private var trailingShadow = false
    
    override func draw(_ dirtyRect: NSRect) {
        if topShadow || leadingShadow || trailingShadow {
            let context = NSGraphicsContext.current()!.cgContext
            let colors = [CGColor(red: 0, green: 0, blue: 0, alpha: 0.4), CGColor(red: 0, green: 0, blue: 0, alpha: 0.0)]
            let colorLocations: [CGFloat] = [0, 1]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: colorLocations)!
            if topShadow {
                context.drawLinearGradient(gradient, start: NSPoint(x: 0, y: 0), end: NSPoint(x: 0, y: 3), options: [])
            }
            if leadingShadow {
                context.drawLinearGradient(gradient, start: NSPoint(x: 0, y: 0), end: NSPoint(x: 3, y: 0), options: [])
            }
            if trailingShadow {
                let x = bounds.size.width
                context.drawLinearGradient(gradient, start: NSPoint(x: x - 1, y: 0), end: NSPoint(x: x - 4, y: 0), options: [])
            }
        }
    }

    override var isFlipped: Bool {
        return true;
    }
    
    // shadow view shouldn't receive mouse events
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    func updateScroll(_ contentBounds: NSRect, _ docBounds: NSRect) {
        let newTop = contentBounds.origin.y != 0
        let newLead = contentBounds.origin.x != 0
        let newTrail = NSMaxX(contentBounds) < NSMaxX(docBounds)
        if newTop != topShadow || newLead != leadingShadow || newTrail != trailingShadow {
            needsDisplay = true
            topShadow = newTop
            leadingShadow = newLead
            trailingShadow = newTrail
        }
    }
}
