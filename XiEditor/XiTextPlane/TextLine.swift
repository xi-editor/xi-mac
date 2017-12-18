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

/// A line of text with attributes that is ready for drawing.
class TextLine {
    var glyphs: [GlyphInstance]
    
    // TODO: this is a placeholder, we want a builder that works from string
    // and builds our own CTLine
    init(ctLine: CTLine, fontCache: FontCache, argb: UInt32) {
        glyphs = []
        let fgColor = (GLfloat((argb >> 16) & 0xff),
                  GLfloat((argb >> 8) & 0xff),
                  GLfloat(argb & 0xff),
                  GLfloat(argb >> 24))
        let runs = CTLineGetGlyphRuns(ctLine) as [AnyObject] as! [CTRun]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            let attributes: NSDictionary = CTRunGetAttributes(run)
            let font = attributes[kCTFontAttributeName] as! CTFont
            let fr = fontCache.getFontRef(font: font)
            for i in 0..<count {
                var glyph = CGGlyph()
                var pos = CGPoint()
                let range = CFRange(location: i, length: 1)
                CTRunGetGlyphs(run, range, &glyph)
                CTRunGetPositions(run, range, &pos)
                glyphs.append(GlyphInstance(fontRef: fr, glyph: glyph, x: GLfloat(pos.x), y: GLfloat(pos.y), fgColor: fgColor))
            }
        }
    }
}

struct GlyphInstance {
    var fontRef: FontRef
    var glyph: CGGlyph
    // next 4 values are in pixels
    var x: GLfloat
    var y: GLfloat
    var fgColor: (GLfloat, GLfloat, GLfloat, GLfloat)
}
