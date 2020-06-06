// Copyright 2017 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa
import OpenGL
import GLKit

class TextPlaneDemo: NSView, TextPlaneDelegate {
    var last: Double = 0
    var count = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        wantsBestResolutionOpenGLSurface = true
    }

    override func makeBackingLayer() -> CALayer {
        let layer = GLTextPlaneLayer()
        layer.textDelegate = self
        return layer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("coding not implemented for text plane")
    }

    override func draw(_ rect: NSRect) {
        print("draw \(rect)")
        //render()
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with theEvent: NSEvent) {
        //print("keyDown \(theEvent)")
        if theEvent.keyCode == 49 {
            self.needsDisplay = true
        }
    }

    override var isOpaque: Bool {
        return true
    }

    func render(_ renderer: Renderer, dirtyRect: NSRect) {
        renderer.clear(NSColor.white)
        renderer.drawSolidRect(x: 200, y: 200, width: 600, height: 600, argb: 0xffff8080)
        renderer.drawSolidRect(x: 500, y: 100, width: 100, height: 400, argb: 0x808080ff)
        renderer.drawSolidRect(x: GLfloat(dirtyRect.maxX - 10), y: GLfloat(dirtyRect.maxY - 10), width: 10, height: 10, argb: 0xff00ff00)

        let text = "Now is the time for all good people to come to the aid of their country. This is a very long string because I really want to fill up the window and see if we can get 60Hz"
        let font = NSFont(name: "Inconsolata", size: 14) ?? NSFont(name: "Menlo", size: 14)!
        let builder = TextLineBuilder(text, font: font)
        builder.addFgSpan(range: 7..<10, argb: 0xffff0000)
        let tl = builder.build(fontCache: renderer.fontCache)
        //textInstances.removeAll()
        //textInstances.append(contentsOf: [10, 100, 256, 256,  192.0, 192.0, 192.0, 255.0,  0.0, 0.0, 1.0, 1.0])
        for j in 0..<60 {
            renderer.drawLine(line: tl, x0: 10, y0: GLfloat(15 + j * 15))
        }
    }

}

protocol TextPlaneDelegate: class {
    func render(_ renderer: Renderer, dirtyRect: NSRect)
}
