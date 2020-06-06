// Copyright 2019 The xi-editor Authors.
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

import Foundation
import OpenGL
import GLKit

/// A layer that efficiently renders text content. It is a subclass of NSOpenGLLayer,
/// and is the main top-level integration point.
class GLTextPlaneLayer: NSOpenGLLayer, TextPlaneLayer {
    lazy var renderer: GLRenderer = {
        glEnable(GLenum(GL_BLEND))
        glEnable(GLenum(GL_FRAMEBUFFER_SRGB))
        return GLRenderer()
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

    @available(*, unavailable)
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

    var previousFrame : FpsTimer?

    override var delegate: CALayerDelegate? {
        get { return super.delegate }
        set(newValue) { super.delegate = newValue }
    }

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

extension GLTextPlaneLayer: FpsObserver {
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
}
