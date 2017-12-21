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
    
    func flush() {
        for fontInstance in fonts {
            fontInstance.map.removeAll()
        }
    }
}

/// This is an instance of a font in the font cache, which contains enough information
/// to retrieve glyphs from the texture atlas, and also render them on demand.
class FontInstance {
    var ctFont: CTFont
    // glyph indices are dense/small, don't need a hashmap, but we're keeping it simple
    var map: [UInt32: CachedGlyph] = [:]

    init(ctFont: CTFont) {
        self.ctFont = ctFont
    }
}

func fontMapKey(glyph: CGGlyph, flags: UInt32) -> UInt32 {
    return flags | UInt32(glyph)
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

    func getGlyph(fr: FontRef, glyph: CGGlyph, flags: UInt32) -> CachedGlyph? {
        let fakeItalic = (flags & FLAG_FAKE_ITALIC) != 0
        let fontInstance = fontCache.fonts[fr]
        let key = fontMapKey(glyph: glyph, flags: flags)
        let probe = fontInstance.map[key]
        if probe != nil {
            return probe
        }
        var rect = CGRect()
        var glyphInOut = glyph
        CTFontGetBoundingRectsForGlyphs(fontInstance.ctFont, .horizontal, &glyphInOut, &rect, 1)
        if rect.isEmpty {
            let result = CachedGlyph(uvCoords: [0, 0, 0, 0], xoff: 0, yoff: 0, width: 0, height: 0)
            fontInstance.map[key] = result
            return result
        }
        // TODO: get this from correct source
        let dpiScale: CGFloat = 2.0
        let invDpiScale = 1 / dpiScale
        // TODO: this can get more precise, and should take subpixel position into account
        //print("rect: \(rect)")
        let oblique: CGFloat = 0.2
        if fakeItalic {
            rect.origin.x += oblique * rect.origin.y
            rect.size.width += oblique * rect.size.height
        }
        let x0 = rect.origin.x * dpiScale
        let x1 = x0 + rect.size.width * dpiScale
        let y0 = rect.origin.y * dpiScale
        let y1 = y0 + rect.size.height * dpiScale
        let widthInt = 2 + Int(ceil(x1) - floor(x0))
        let heightInt = 2 + Int(ceil(y1) - floor(y0))
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
        ctx.fill(CGRect(x: 0, y: 0, width: widthInt, height: heightInt))
        ctx.setFillColor(gray: 0.0, alpha: 1.0)
        ctx.scaleBy(x: dpiScale, y: dpiScale)
        if fakeItalic {
            ctx.concatenate(CGAffineTransform(a: 1.0, b: 0.0, c: oblique, d: 1.0, tx: 0, ty: 0))
        }
        let xoff = 1 - floor(x0)
        let yoff = 1 - floor(y0)
        var point = CGPoint(x: xoff * invDpiScale, y: yoff * invDpiScale)
        CTFontDrawGlyphs(fontInstance.ctFont, &glyphInOut, &point, 1, ctx)
        glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, GLint(origin!.0), GLint(origin!.1), GLsizei(widthInt), GLsizei(heightInt), GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE), &data)
        let result = CachedGlyph(uvCoords: [GLfloat(origin!.0) * uvScale,
                                            GLfloat(origin!.1) * uvScale,
                                            GLfloat(widthInt) * uvScale,
                                            GLfloat(heightInt) * uvScale],
                                 xoff: GLfloat(-xoff * invDpiScale),
                                 yoff: GLfloat((yoff - CGFloat(heightInt)) * invDpiScale),
                                 width: GLfloat(CGFloat(widthInt) * invDpiScale),
                                 height: GLfloat(CGFloat(heightInt) * invDpiScale))
        fontInstance.map[key] = result
        return result
    }

    func flushCache() {
        fontCache.flush()
        strips.removeAll()
        nextStrip = 0
    }
}
