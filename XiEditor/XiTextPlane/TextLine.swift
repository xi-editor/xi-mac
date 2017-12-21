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

/// A builder for TextLine objects.
class TextLineBuilder {
    var text: String
    var attributes: [NSAttributedStringKey: AnyObject]
    var defaultFgColor: UInt32 = 0xff000000
    var fgSpans: [ColorSpan] = []
    var selSpans: [SelSpan] = []

    init(_ text: String, font: CTFont) {
        attributes = [
            NSAttributedStringKey.font: font,
            ]
        self.text = text
    }

    /// Sets the default color of the text not covered by spans.
    func setFgColor(argb: UInt32) {
        defaultFgColor = argb
    }

    /// Add a foreground color span to the text line. This method assumes that such spans
    /// are added in sorted order and do not overlap.
    func addFgSpan(colorSpan: ColorSpan) {
        if !colorSpan.range.isEmpty {
            fgSpans.append(colorSpan)
        }
    }

    func addSelSpan(selSpan: SelSpan) {
        if !selSpan.range.isEmpty {
            selSpans.append(selSpan)
        }
    }

    func build(fontCache: FontCache) -> TextLine {
        let attrString = NSMutableAttributedString(string: text, attributes: attributes)
        let ctLine = CTLineCreateWithAttributedString(attrString)

        var fgSpanIx = 0
        var fgColor = argbToFloats(argb: defaultFgColor)
        var glyphs: [GlyphInstance] = []
        let runs = CTLineGetGlyphRuns(ctLine) as [AnyObject] as! [CTRun]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            let attributes: NSDictionary = CTRunGetAttributes(run)
            // TODO: deal with these being nil, as warned by doc
            let glyphsPtr = CTRunGetGlyphsPtr(run)
            let posPtr = CTRunGetPositionsPtr(run)
            let indicesPtr = CTRunGetStringIndicesPtr(run)
            let font = attributes[kCTFontAttributeName] as! CTFont
            let fr = fontCache.getFontRef(font: font)
            for i in 0..<count {
                let glyph = glyphsPtr![i]
                let pos = posPtr![i]
                let ix = indicesPtr![i]
                if fgSpanIx < fgSpans.count && ix >= fgSpans[fgSpanIx].range.endIndex {
                    fgSpanIx += 1
                }
                if fgSpanIx < fgSpans.count && fgSpans[fgSpanIx].range.contains(ix) {
                    // TODO: maybe could reduce the amount of conversion
                    fgColor = argbToFloats(argb: fgSpans[fgSpanIx].argb)
                } else {
                    fgColor = argbToFloats(argb: defaultFgColor)
                }
                glyphs.append(GlyphInstance(fontRef: fr, glyph: glyph, x: GLfloat(pos.x), y: GLfloat(pos.y), fgColor: fgColor))
            }
        }
        var selRanges: [Range<GLfloat>] = []
        for selSpan in selSpans {
            // TODO: make bidi-aware
            let selStart = GLfloat(CTLineGetOffsetForStringIndex(ctLine, selSpan.range.startIndex, nil))
            let selEnd = GLfloat(CTLineGetOffsetForStringIndex(ctLine, selSpan.range.endIndex, nil))
            selRanges.append(selStart..<selEnd)
        }
        return TextLine(glyphs: glyphs, ctLine: ctLine, selRanges: selRanges)
    }
}

/// A line of text with attributes that is ready for drawing.
struct TextLine {
    var glyphs: [GlyphInstance]
    // The CTLine is kept mostly for caret queries
    var ctLine: CTLine
    var selRanges: [Range<GLfloat>]
    
    func offsetForIndex(utf16Ix: Int) -> CGFloat {
        return CTLineGetOffsetForStringIndex(ctLine, utf16Ix, nil)
    }
}

struct GlyphInstance {
    var fontRef: FontRef
    var glyph: CGGlyph
    // next 2 values are in pixels
    var x: GLfloat
    var y: GLfloat
    var fgColor: (GLfloat, GLfloat, GLfloat, GLfloat)
}

// Possible refactor: have Span<T> so range is separated from payload
struct ColorSpan {
    // The range is in units of UTF-16 code units
    var range: CountableRange<Int>
    var argb: UInt32
}

struct SelSpan {
    var range: CountableRange<Int>
}

/// Converts color value in argb format to tuple of 4 floats.
func argbToFloats(argb: UInt32) -> (GLfloat, GLfloat, GLfloat, GLfloat) {
    return (GLfloat((argb >> 16) & 0xff),
            GLfloat((argb >> 8) & 0xff),
            GLfloat(argb & 0xff),
            GLfloat(argb >> 24))
}
