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
    var fonts: [CachedFont] = []
    var fontMap: [CTFont: Int] = [:]

    func getFontRef(font: CTFont) -> FontRef {
        var fr = fontMap[font]
        if fr == nil {
            fr = fonts.count
            fonts.append(CachedFont(ctFont: font))
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
class CachedFont {
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

typealias AtlasPoint = (x: Int, y: Int)
typealias AtlasSize = (width: Int, height: Int)

/// Texture atlas containing glyph cache.
/// The atlas is organized into strips of glyphs. Within a strip, the glyphs
/// are all the same height.
class Atlas {
    let width = 512
    let height = 512
    let uvScale: GLfloat

    // key is rounded-up height, value is x, y coords of next alloc
    var strips: [Int: AtlasPoint] = [:]
    var nextStrip = 0

    var fontCache = FontCache()
    var fontRefs: [CTFont: FontRef] = [:]

    init() {
        uvScale = 1.0 / Float(width)
    }

    // Round a value up to the next power-of-2 multiple of a number at most fracBits long
    func roundUp(_ y: Int, fracBits: Int) -> Int {
        if y < 1 << fracBits { return y }
        let mask = 1 << (Int.bitWidth - (y - 1).leadingZeroBitCount - fracBits)
        return y + (-y & (mask - 1))
    }

    // Returns x, y coords on successful alloc
    func allocRect(w: Int, h: Int) -> AtlasPoint? {
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

    func getGlyph(fr: FontRef, glyph: CGGlyph, flags: UInt32, scale: CGFloat) -> CachedGlyph? {
        // Some discussion about this approach: the correctness condition is that we never
        // use the same key for two different scale factors. A more robust approach would
        // be to generate a unique flag value for each scale factor, but this will work in
        // the common case of two monitors, one low-dpi (1.0) and the other retina (2.0).
        // It will also work on devices with a single scaling factor, no matter the value.
        let flagsForKey = flags | (scale > 1.0 ? FLAG_HI_DPI : 0)
        let fontInstance = fontCache.fonts[fr]
        let key = fontMapKey(glyph: glyph, flags: flagsForKey)
        if let probe = fontInstance.map[key] {
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
        let invScale = 1 / scale
        // TODO: this can get more precise, and should take subpixel position into account
        //print("rect: \(rect)")
        let oblique: CGFloat = 0.2
        let fakeItalic = (flagsForKey & FLAG_FAKE_ITALIC) != 0
        if fakeItalic {
            rect.origin.x += oblique * rect.origin.y
            rect.size.width += oblique * rect.size.height
        }
        let x0 = rect.origin.x * scale
        let x1 = x0 + rect.size.width * scale
        let y0 = rect.origin.y * scale
        let y1 = y0 + rect.size.height * scale
        let widthInt = 2 + Int(ceil(x1) - floor(x0))
        let heightInt = 2 + Int(ceil(y1) - floor(y0))
        guard let origin = allocRect(w: widthInt, h: heightInt) else {
            // atlas is full
            return nil
        }
        var data = [UInt8](repeating: 255, count: widthInt * heightInt * 4)

        let colorspace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        let ctx = CGContext(data: &data,
                            width: widthInt, height: heightInt,
                            bitsPerComponent: 8,
                            bytesPerRow: widthInt * 4,
                            space: colorspace,
                            bitmapInfo: bitmapInfo)!

        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: widthInt, height: heightInt))
        ctx.setFillColor(gray: 0.0, alpha: 1.0)
        ctx.scaleBy(x: scale, y: scale)
        if fakeItalic {
            ctx.concatenate(CGAffineTransform(a: 1.0, b: 0.0, c: oblique, d: 1.0, tx: 0, ty: 0))
        }
        let xoff = 1 - floor(x0)
        let yoff = 1 - floor(y0)
        var point = CGPoint(x: xoff * invScale, y: yoff * invScale)
        CTFontDrawGlyphs(fontInstance.ctFont, &glyphInOut, &point, 1, ctx)

        self.writeGlyphToTexture(origin: origin,
                                 size: AtlasSize(width: widthInt, height: heightInt),
                                 data: data)

        let result = CachedGlyph(uvCoords: [GLfloat(origin.0) * uvScale,
                                            GLfloat(origin.1) * uvScale,
                                            GLfloat(widthInt) * uvScale,
                                            GLfloat(heightInt) * uvScale],
                                 xoff: GLfloat(-xoff * invScale),
                                 yoff: GLfloat((yoff - CGFloat(heightInt)) * invScale),
                                 width: GLfloat(CGFloat(widthInt) * invScale),
                                 height: GLfloat(CGFloat(heightInt) * invScale))
        fontInstance.map[key] = result
        return result
    }

    func flushCache() {
        fontCache.flush()
        strips.removeAll()
        nextStrip = 0
    }

    func writeGlyphToTexture(origin: AtlasPoint, size: AtlasSize, data: [uint8]) {
        fatalError("This function must be overridden!")
    }
}
