// Copyright 2017 Google LLC
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

/// TextPlane is a view made of layers that supports fast text rendering.

class TextPlane: NSView {
    var renderer: Renderer?
    var last: Double = 0
    var count = 0
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        wantsBestResolutionOpenGLSurface = true
        let glLayer = MyGlLayer()
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
}

class MyGlLayer : NSOpenGLLayer {
    var renderer: Renderer?
    var last: Double = 0
    var count = 0
    
    override init() {
        super.init()
        // TODO: consider upgrading minimum version to 10.12
        if #available(OSX 10.12, *) {
            colorspace = CGColorSpace(name: CGColorSpace.linearSRGB)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func copyCGLPixelFormat(forDisplayMask mask: UInt32) -> CGLPixelFormatObj {
        let attr = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAOpenGLProfile),
            NSOpenGLPixelFormatAttribute(NSOpenGLProfileVersion3_2Core),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAlphaSize), 8,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAccelerated),
            0
        ]
        return NSOpenGLPixelFormat(attributes: attr)!.cglPixelFormatObj!
        
    }
    
    override func draw(in context: NSOpenGLContext, pixelFormat: NSOpenGLPixelFormat, forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>) {
        if renderer == nil {
            renderer = Renderer()
            glEnable(GLenum(GL_BLEND))
            glEnable(GLenum(GL_FRAMEBUFFER_SRGB))
        }
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT))
        renderer?.render(size: frame.size)
        let now = NSDate().timeIntervalSince1970
        let elapsed = now - last
        last = now
        //print("\(count) \(elapsed)")
        count += 1
    }
}

