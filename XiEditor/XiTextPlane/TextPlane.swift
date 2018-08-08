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
    var renderer: Renderer?
    var last: Double = 0
    var count = 0
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        wantsBestResolutionOpenGLSurface = true
        let glLayer = TextPlaneLayer()
        glLayer.textDelegate = self
        layer = glLayer
    }

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
        let tl = builder.build(fontCache: renderer.atlas.fontCache)
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

/// A layer that efficiently renders text content. It is a subclass of NSOpenGLLayer,
/// and is the main top-level integration point.
class TextPlaneLayer : NSOpenGLLayer, FpsObserver {
    lazy var renderer: Renderer = {
        glEnable(GLenum(GL_BLEND))
        glEnable(GLenum(GL_FRAMEBUFFER_SRGB))
        return Renderer()
    }()
    weak var textDelegate: TextPlaneDelegate?

    var fps = Fps()
    var last: Double = 0
    var count = 0

    override init() {
        super.init()
        // TODO: consider upgrading minimum version to 10.12
        if #available(OSX 10.12, *) {
            colorspace = CGColorSpace(name: CGColorSpace.linearSRGB)
        }
        fps.add(observer: self)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func copyCGLPixelFormat(forDisplayMask mask: UInt32) -> CGLPixelFormatObj {
        let attr = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAllowOfflineRenderers),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAOpenGLProfile),
            NSOpenGLPixelFormatAttribute(NSOpenGLProfileVersion3_2Core),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAlphaSize), 8,
            0
        ]
        return NSOpenGLPixelFormat(attributes: attr)!.cglPixelFormatObj!
    }

    func changed(fps: Double) {
        // TODO: use a view/text label overlay within the document to show this
        // controllable via a debug menu instead of a compile-time flag.
#if FPS_RAW
        print("Fps \(fps), ms/frame = \(1000.0 / fps)")
#endif
    }

    func changed(fpsStats stats: FpsSnapshot) {
        // TODO: use a view/text label overlay within the document to show this
        // controllable via a debug menu instead of a compile-time flag.
#if FPS_STATS
        print("Fps mean: \(stats.meanFps()), 99%: \(stats.fps(percentile: 0.01)), min: \(stats.minFps()), max: \(stats.maxFps())")
#endif
    }
    
    var previousFrame : FpsTimer?

    override func draw(in context: NSOpenGLContext, pixelFormat: NSOpenGLPixelFormat, forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>) {
        // We have to capture the FPS rate of successive draw calls.  This isn't
        // great because we will have an artificially low FPS if nothing is
        // happening and when things are happening it will by capped to VSync
        // since this only gets called when something needs to be redrawn (no
        // way to measure how much we exceed the refresh rate by).  This is
        // needed because the OpenGL rendering is deferred & when it actually
        // gets committed is out of our control (timing this method alone will
        // yield millions of FPS).
        previousFrame = nil
        previousFrame = fps.startRender()
        renderer.beginDraw(size: frame.size, scale: contentsScale)
        textDelegate?.render(renderer, dirtyRect: frame)
        renderer.endDraw()
    }

    override func releaseCGLPixelFormat(_ pf: CGLPixelFormatObj) {
        // CGLPixelFormats already seem to be released; leaving the default implementation causes a crash.
    }
}

