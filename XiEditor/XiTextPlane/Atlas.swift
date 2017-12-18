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

struct CachedGlyph {
    var uvCoords: [GLfloat]
    var xoff: GLfloat
    var yoff: GLfloat
    var width: GLfloat
    var height: GLfloat
}

/// The font cache keeps track of currently active fonts and assigns them a small
/// integer id, which is useful for very fast lookup. At present "active" means
/// any font that has ever been seen, so callers should be careful to reuse fonts
/// as much as possible.
class FontCache {
    var fonts: [FontInstance] = []
    var fontMap: [CTFont: Int] = [:]

    func getFontRef(font: CTFont) -> FontRef {
        var fr = fontMap[font]
        if fr == nil {
            fr = fonts.count
            fonts.append(FontInstance(ctFont: font))
            fontMap[font] = fr
        }
        return fr!
    }
}

/// This is an instance of a font in the font cache, which contains enough information
/// to retrieve glyphs from the texture atlas, and also render them on demand.
class FontInstance {
    var ctFont: CTFont
    // glyph indices are dense/small, don't need a hashmap, but we're keeping it simple
    var map: [CGGlyph: CachedGlyph] = [:]

    init(ctFont: CTFont) {
        self.ctFont = ctFont
    }
}

typealias FontRef = Int

/// Texture atlas containing glyph cache.

class Atlas {
    var textureId: GLuint = 0
    let width = 512
    let height = 512
    let uvScale: GLfloat
    
    // key is rounded-up height, value is x, y coords of next alloc
    var strips: [Int: (Int, Int)] = [:]
    var nextStrip = 0

    var fontCache = FontCache()
    var fontRefs: [CTFont: FontRef] = [:]
    
    init() {
        glGenTextures(1, &textureId)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureId)
        glPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        var data = [UInt8](repeating: 255, count: width * height * 4)
        
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        let ctx = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorspace, bitmapInfo: bitmapInfo)!
        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(gray: 0.0, alpha: 1.0)
        ctx.setAllowsFontSmoothing(true)
        ctx.setShouldSmoothFonts(true)
        ctx.setAllowsFontSubpixelPositioning(true)
        ctx.setShouldSubpixelPositionFonts(true)
        ctx.setAllowsFontSubpixelQuantization(false)
        ctx.setShouldSubpixelQuantizeFonts(false)
        
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(width), GLsizei(height), 0, GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE), &data)
        uvScale = 1.0 / Float(width)
    }
    
    // Round a value up to the next power-of-2 multiple of a number at most fracBits long
    func roundUp(_ y: Int, fracBits: Int) -> Int {
        if y < 1 << fracBits { return y }
        let mask = 1 << (Int.bitWidth - (y - 1).leadingZeroBitCount - fracBits)
        return y + (-y & (mask - 1))
    }
    
    // Returns x, y coords on successful alloc
    func allocRect(w: Int, h: Int) -> (Int, Int)? {
        if w > width || h > height {
            // request cannot be satisfied
            return nil
        }
        let roundHeight = roundUp(h, fracBits: 2)
        var coords = strips[roundHeight]
        if coords == nil || coords!.0 + w > width {
            if nextStrip + roundHeight > height {
                // no more free space in this atlas
                return nil
            }
            coords = (0, nextStrip)
            nextStrip += roundHeight
        }
        strips[roundHeight] = (coords!.0 + w, coords!.1)
        return coords
    }

    func getGlyph(fr: FontRef, glyph: CGGlyph) -> CachedGlyph? {
        let fontInstance = fontCache.fonts[fr]
        let probe = fontInstance.map[glyph]
        if probe != nil {
            return probe
        }
        var rect = CGRect()
        var glyphInOut = glyph
        CTFontGetBoundingRectsForGlyphs(fontInstance.ctFont, .horizontal, &glyphInOut, &rect, 1)
        if rect.isEmpty {
            let result = CachedGlyph(uvCoords: [0, 0, 0, 0], xoff: 0, yoff: 0, width: 0, height: 0)
            fontInstance.map[glyph] = result
            return result
        }
        // TODO: this can get more precise, and should take subpixel position into account
        let rectIntegral = rect.integral.insetBy(dx: -1, dy: -1)
        let widthInt = Int(rectIntegral.width)
        let heightInt = Int(rectIntegral.height)
        let origin = allocRect(w: widthInt, h: heightInt)
        if origin == nil {
            // atlas is full
            return nil
        }
        var data = [UInt8](repeating: 255, count: widthInt * heightInt * 4)
        
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        let ctx = CGContext(data: &data, width: widthInt, height: heightInt, bitsPerComponent: 8, bytesPerRow: widthInt * 4, space: colorspace, bitmapInfo: bitmapInfo)!
        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(gray: 0.0, alpha: 1.0)
        var point = CGPoint(x: 1 - rect.origin.x, y: 1 - rect.origin.y)
        CTFontDrawGlyphs(fontInstance.ctFont, &glyphInOut, &point, 1, ctx)
        glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, GLint(origin!.0), GLint(origin!.1), GLsizei(widthInt), GLsizei(heightInt), GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE), &data)
        let result = CachedGlyph(uvCoords: [GLfloat(origin!.0) * uvScale,
                                            GLfloat(origin!.1) * uvScale,
                                            GLfloat(widthInt) * uvScale,
                                            GLfloat(heightInt) * uvScale],
                                 xoff: GLfloat(floor(rect.origin.x) - 1),
                                 yoff: GLfloat(floor(-rect.origin.y) - 1) - GLfloat(heightInt),
                                 width: GLfloat(widthInt),
                                 height: GLfloat(heightInt))
        fontInstance.map[glyph] = result
        return result
    }
}
