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

extension NSFont {
    /// If the font is monospace, returns the width of a character, else returns 0.
    func characterWidth() -> CGFloat {
        if self.isFixedPitch {
            let characters = [UniChar(0x20)]
            var glyphs = [CGGlyph(0)]
            if CTFontGetGlyphsForCharacters(self, characters, &glyphs, 1) {
                let advance = CTFontGetAdvancesForGlyphs(self, .horizontal, glyphs, nil, 1)
                return CGFloat(advance)
            }
        }
        return 0
    }
}

/// A store of properties used to determine the layout of text.
struct TextDrawingMetrics {
    let font: NSFont
    var attributes: [NSAttributedStringKey: AnyObject] = [:]
    var ascent: CGFloat
    var descent: CGFloat
    var leading: CGFloat
    var baseline: CGFloat
    var linespace: CGFloat
    var fontWidth: CGFloat

    init(font: NSFont, textColor: NSColor) {
        self.font = font
        ascent = font.ascender
        descent = -font.descender // descender is returned as a negative number
        leading = font.leading
        linespace = ceil(ascent + descent + leading)
        baseline = ceil(ascent)
        fontWidth = font.characterWidth()
        attributes[NSAttributedStringKey.font] = font
        //FIXME: sometimes some regions of a file have no spans, so they don't have a style,
        // which means they get drawn as black. With this we default to drawing them like plaintext.
        // BUT: why are spans missing?
        attributes[NSAttributedStringKey.foregroundColor] = textColor
    }
}

/// The pre-renderered cache of the digits 0-9 for display in the gutter.
/// These can be scatter-gathered to quickly construct any sequence of digits.
struct GutterCache {
    private let font: CTFont
    /// Scatter-gather from here for the gutter for lines without a cursor.
    private let noCursorCache: TextLine
    /// Scatter-gather from here for the gutter for lines containing a cursor.
    private let cursorCache: TextLine

    /// Initializes the cache with the given font & the requested colors for
    /// when the line has a cursor or not (has cursor = foreground).
    init(cursorArgb foregroundArgb: UInt32, noCursorArgb backgroundArgb: UInt32,
         font: CTFont, fontCache: FontCache) {
        self.font = font

        let tlBuilder = TextLineBuilder("0123456789", font: font)
        tlBuilder.setFgColor(argb: foregroundArgb)
        self.cursorCache = tlBuilder.build(fontCache: fontCache)

        tlBuilder.setFgColor(argb: backgroundArgb)
        self.noCursorCache = tlBuilder.build(fontCache: fontCache)
    }

    func lookupLineNumber(lineIdx: UInt, hasCursor: Bool) -> TextLine {
        let cache = hasCursor ? cursorCache : noCursorCache
        // build up the indices of the characters.  results in little-endian
        // ordering.
        var glyphIndices : [Int] = []
        var n = lineIdx
        while n != 0 {
            glyphIndices.append(Int(n % 10))
            n /= 10
        }
        // reverse the glyph ordering to get the correct big-endian ordering
        // of the indices.
        return cache.scatterGather(indices: glyphIndices.reversed(), font: self.font)
    }
}

/// A line-column index into a displayed text buffer.
typealias BufferPosition = (line: Int, column: Int)


func insertedStringToJson(_ stringToInsert: NSString) -> Any {
    return ["chars": stringToInsert]
}

func colorFromArgb(_ argb: UInt32) -> NSColor {
    return NSColor(red: CGFloat((argb >> 16) & 0xff) * 1.0/255,
        green: CGFloat((argb >> 8) & 0xff) * 1.0/255,
        blue: CGFloat(argb & 0xff) * 1.0/255,
        alpha: CGFloat((argb >> 24) & 0xff) * 1.0/255)
}

/// Convert color to ARGB format. Note: we should do less conversion
/// back and forth to NSColor; this is a convenience so we don't have
/// to change as much code.
func colorToArgb(_ color: NSColor) -> UInt32 {
    let ciColor = CIColor(color: color)!
    let a = UInt32(round(ciColor.alpha * 255.0))
    let r = UInt32(round(ciColor.red * 255.0))
    let g = UInt32(round(ciColor.green * 255.0))
    let b = UInt32(round(ciColor.blue * 255.0))
    return (a << 24) | (r << 16) | (g << 8) | b
}

class EditView: NSView, NSTextInputClient, TextPlaneDelegate {
    var scrollOrigin: NSPoint {
        didSet {
            if scrollOrigin != oldValue {
                needsDisplay = true
            }
        }
    }
    var lastRevisionRendered = 0
    var gutterXPad: CGFloat = 8
    var gutterCache: GutterCache?

    var dataSource: EditViewDataSource!

    var lastDragLineCol: (Int, Int)?
    var timer: Timer?
    var timerEvent: NSEvent?

    var cursorPos: (Int, Int)?
    fileprivate var _selectedRange: NSRange
    fileprivate var _markedRange: NSRange

    var isFirstResponder = false
    var isFrontmostView = false {
        didSet {
            //TODO: blinking should one day be a user preference
            showBlinkingCursor = isFrontmostView
            self.needsDisplay = true
        }
    }

    /*  Insertion point blinking.
     Only the frontmost ('key') window should have a blinking insertion point.
     A new 'on' cycle starts every time the window comes to the front, or the text changes, or the ins. point moves.
     Type fast enough and the ins. point stays on.
     */
    var _blinkTimer : Timer?
    private var _cursorStateOn = false
    /// if set to true, this view will show blinking cursors
    var showBlinkingCursor = false {
        didSet {
            _cursorStateOn = showBlinkingCursor
            _blinkTimer?.invalidate()
            if showBlinkingCursor {
                _blinkTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0), target: self, selector: #selector(_blinkInsertionPoint), userInfo: nil, repeats: true)
            } else {
                _blinkTimer = nil
            }
        }
    }

    private var cursorColor: NSColor {
        // using foreground instead of caret because caret looks weird in the default
        // theme, and seems to be ignored by sublime text anyway?
        return dataSource.theme.foreground
    }

    required init?(coder: NSCoder) {
        _selectedRange = NSMakeRange(NSNotFound, 0)
        _markedRange = NSMakeRange(NSNotFound, 0)
        scrollOrigin = NSPoint()
        super.init(coder: coder)

        wantsLayer = true
        wantsBestResolutionOpenGLSurface = true
        let glLayer = TextPlaneLayer()
        glLayer.textDelegate = self
        layer = glLayer
    }

    let x0: CGFloat = 2;

    // This needs to be implemented, even though it seems to never be called, to preserve
    // updating on live window resize.
    override func draw(_ dirtyRect: NSRect) {
        ()
    }

    override var acceptsFirstResponder: Bool {
        return true;
    }

    override func becomeFirstResponder() -> Bool {
        isFrontmostView = true
        isFirstResponder = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isFrontmostView = false
        isFirstResponder = false
        return true
    }

    // we use a flipped coordinate system primarily to get better alignment when scrolling
    override var isFlipped: Bool {
        return true;
    }

    override var isOpaque: Bool {
        return true
    }

    override var preservesContentDuringLiveResize: Bool {
        return true
    }

    // MARK: - NSTextInputClient protocol
    func insertText(_ aString: Any, replacementRange: NSRange) {
        self.removeMarkedText()
        let _ = self.replaceCharactersInRange(replacementRange, withText: aString as AnyObject)
    }

    public func characterIndex(for point: NSPoint) -> Int {
        return 0
    }

    func replacementMarkedRange(_ replacementRange: NSRange) -> NSRange {
        var markedRange = _markedRange


        if (markedRange.location == NSNotFound) {
            markedRange = _selectedRange
        }
        if (replacementRange.location != NSNotFound) {
            var newRange: NSRange = markedRange
            newRange.location += replacementRange.location
            newRange.length += replacementRange.length
            if (NSMaxRange(newRange) <= NSMaxRange(markedRange)) {
                markedRange = newRange
            }
        }

        return markedRange
    }

    func replaceCharactersInRange(_ aRange: NSRange, withText aString: AnyObject) -> NSRange {
        var replacementRange = aRange
        var len = 0
        if let attrStr = aString as? NSAttributedString {
            len = attrStr.string.count
        } else if let str = aString as? NSString {
            len = str.length
        }
        if (replacementRange.location == NSNotFound) {
            replacementRange.location = 0
            replacementRange.length = 0
        }
        for _ in 0..<aRange.length {
            dataSource.document.sendRpcAsync("delete_backward", params  : [])
        }
        if let attrStr = aString as? NSAttributedString {
            dataSource.document.sendRpcAsync("insert", params: insertedStringToJson(attrStr.string as NSString))
        } else if let str = aString as? NSString {
            dataSource.document.sendRpcAsync("insert", params: insertedStringToJson(str))
        }
        return NSMakeRange(replacementRange.location, len)
    }

    func setMarkedText(_ aString: Any, selectedRange: NSRange, replacementRange: NSRange) {
        var mutSelectedRange = selectedRange
        let effectiveRange = self.replaceCharactersInRange(self.replacementMarkedRange(replacementRange), withText: aString as AnyObject)
        if (selectedRange.location != NSNotFound) {
            mutSelectedRange.location += effectiveRange.location
        }
        _selectedRange = mutSelectedRange
        _markedRange = effectiveRange
        if (effectiveRange.length == 0) {
            self.removeMarkedText()
        }
    }

    func removeMarkedText() {
        if (_markedRange.location != NSNotFound) {
            for _ in 0..<_markedRange.length {
                dataSource.document.sendRpcAsync("delete_backward", params: [])
            }
        }
        _markedRange = NSMakeRange(NSNotFound, 0)
        _selectedRange = NSMakeRange(NSNotFound, 0)
    }

    func unmarkText() {
        self._markedRange = NSMakeRange(NSNotFound, 0)
    }

    func selectedRange() -> NSRange {
        return _selectedRange
    }

    func markedRange() -> NSRange {
        return _markedRange
    }

    func hasMarkedText() -> Bool {
        return _markedRange.location != NSNotFound
    }

    func attributedSubstring(forProposedRange aRange: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        return NSAttributedString()
    }

    func validAttributesForMarkedText() -> [NSAttributedStringKey] {
        return [NSAttributedStringKey.foregroundColor, NSAttributedStringKey.backgroundColor]
    }

    func firstRect(forCharacterRange aRange: NSRange, actualRange: NSRangePointer?) -> NSRect {
        if let viewWinFrame = self.window?.convertToScreen(self.frame),
            let (lineIx, pos) = self.cursorPos,
            let line = getLine(lineIx) {
            let str = line.text
            let ctLine = CTLineCreateWithAttributedString(NSMutableAttributedString(string: str, attributes: dataSource.textMetrics.attributes))
            let rangeWidth = CTLineGetOffsetForStringIndex(ctLine, pos, nil) - CTLineGetOffsetForStringIndex(ctLine, pos - aRange.length, nil)
            return NSRect(x: viewWinFrame.origin.x + CTLineGetOffsetForStringIndex(ctLine, pos, nil),
                          y: viewWinFrame.origin.y + viewWinFrame.size.height - dataSource.textMetrics.linespace * CGFloat(lineIx + 1) - 5,
                          width: rangeWidth,
                          height: dataSource.textMetrics.linespace)
        } else {
            return NSRect(x: 0, y: 0, width: 0, height: 0)
        }
    }

    /// MARK: - System Events

    /// timer callback to toggle the blink state
    @objc func _blinkInsertionPoint() {
        _cursorStateOn = !_cursorStateOn
        partialInvalidate(invalid: dataSource.lines.cursorInval)
    }

    // TODO: more functions should call this, just dividing by linespace doesn't account for descent
    func yToLine(_ y: CGFloat) -> Int {
        return Int(floor(max(y - dataSource.textMetrics.descent, 0) / dataSource.textMetrics.linespace))
    }

    func lineIxToBaseline(_ lineIx: Int) -> CGFloat {
        return CGFloat(lineIx + 1) * dataSource.textMetrics.linespace
    }

    /// given a point in the containing window's coordinate space, converts it into a line / column position in the current view.
    /// Note: - The returned position is not guaruanteed to be an existing line. For instance, if a buffer does not fill the current window, a point below the last line will return a buffer position with a line number exceeding the number of lines in the file. In this case position.column will always be zero.
    func bufferPositionFromPoint(_ point: NSPoint) -> BufferPosition {
        let point = self.convert(point, from: nil)
        let x = point.x + scrollOrigin.x - dataSource.gutterWidth
        let y = point.y + scrollOrigin.y
        let lineIx = yToLine(y)
        if let line = getLine(lineIx) {
            let s = line.text
            let attrString = NSAttributedString(string: s, attributes: dataSource.textMetrics.attributes)
            let ctline = CTLineCreateWithAttributedString(attrString)
            let relPos = NSPoint(x: x - x0, y: lineIxToBaseline(lineIx) - y)
            let utf16_ix = CTLineGetStringIndexForPosition(ctline, relPos)
            if utf16_ix != kCFNotFound {
                let col = utf16_offset_to_utf8(s, utf16_ix)
                return BufferPosition(line: lineIx, column: col)
            }
        }
        return BufferPosition(line: lineIx, column: 0)
    }

    private func utf8_offset_to_utf16(_ s: String, _ ix: Int) -> Int {
        // String(s.utf8.prefix(ix)).utf16.count
        return s.utf8.index(s.utf8.startIndex, offsetBy: ix).encodedOffset
    }

    private func utf16_offset_to_utf8(_ s: String, _ ix: Int) -> Int {
        return Substring(s.utf16.prefix(ix)).utf8.count
    }

    func getLine(_ lineNum: Int) -> Line<LineAssoc>? {
        return dataSource.lines.locked().get(lineNum)
    }

    func partialInvalidate(invalid: InvalSet) {
        for range in invalid.ranges {
            let start = range.lowerBound
            let height = range.count
            let y = CGFloat(start + 1) * dataSource.textMetrics.linespace - dataSource.textMetrics.ascent
            let h = CGFloat(height) * dataSource.textMetrics.linespace
            setNeedsDisplay(NSRect(x: 0, y: y, width: frame.width, height: h))
        }
    }

    /// Our equivalent of drawRect:, with rendering using TextPlane.
    ///
    /// Note: This function has side effects in two cases: It stashes
    /// the length of the longest line it sees, and passes this to the view controller;
    /// if this line is longer than the previous longest, the view's width is updated.
    /// It also updates IME state if IME is active.
    func render(_ renderer: Renderer, dirtyRect: NSRect) {
        Trace.shared.trace("EditView render", .main, .begin)
        renderer.clear(dataSource.theme.background)
        if dataSource.document.coreViewIdentifier == nil {
            Trace.shared.trace("EditView render", .main, .end)
            return
        }
        let linespace = dataSource.textMetrics.linespace
        let topPad = linespace - dataSource.textMetrics.ascent
        let xOff = dataSource.gutterWidth + x0 - scrollOrigin.x
        let yOff = topPad - scrollOrigin.y
        let firstVisible = max(0, Int((floor(dirtyRect.origin.y - topPad + scrollOrigin.y) / linespace)))
        let lastVisible = max(0, Int(ceil((dirtyRect.origin.y + dirtyRect.size.height - topPad + scrollOrigin.y) / linespace)))

        // Note: this locks the line cache for the duration of the render
        let lineCache = dataSource.lines.locked()
        let totalLines = lineCache.height
        let first = min(totalLines, firstVisible)
        let last = min(totalLines, lastVisible)
        let lines = lineCache.blockingGet(lines: first..<last)
        let font = dataSource.textMetrics.font as CTFont
        let styleMap = dataSource.styleMap.locked()
        var textLines: [TextLine?] = []
        var maxLineWidth: Double = 0

        // The actual drawing is split into passes for correct visual presentation and
        // also to improve batching of the OpenGL draw calls.

        // first pass: create TextLine objects and also draw background rects
        let selectionColor = self.isFrontmostView ? dataSource.theme.selection : dataSource.theme.inactiveSelection ?? dataSource.theme.selection
        let selArgb = colorToArgb(selectionColor)
        let foregroundArgb = colorToArgb(dataSource.theme.foreground)
        let gutterArgb = colorToArgb(dataSource.theme.gutterForeground)

        if gutterCache == nil {
            gutterCache = GutterCache(cursorArgb: foregroundArgb,
                                      noCursorArgb: gutterArgb,
                                      font: font, fontCache: renderer.fontCache)
        }

        for lineIx in first..<last {
            let relLineIx = lineIx - first
            guard let line = lines[relLineIx] else {
                textLines.append(nil)
                continue
            }
            let textLine: TextLine
            if let assoc = lineCache.get(lineIx)?.assoc {
                textLine = assoc.textLine
                textLines.append(assoc.textLine)
            } else {
                let builder = TextLineBuilder(line.text, font: font)
                builder.setFgColor(argb: foregroundArgb)
                styleMap.applyStyles(builder: builder, styles: line.styles)
                textLine = builder.build(fontCache: renderer.fontCache)

                let assoc = LineAssoc(textLine: textLine)
                lineCache.setAssoc(lineIx, assoc: assoc)
                textLines.append(textLine)
            }
            maxLineWidth = max(maxLineWidth, textLine.width)
            let y0 = yOff + linespace * CGFloat(lineIx)
            renderer.drawLineBg(line: textLine, x0: GLfloat(xOff), yRange: GLfloat(y0)..<GLfloat(y0 + linespace), selColor: selArgb)
        }

        // second pass: draw text
        for lineIx in first..<last {
            if let textLine = textLines[lineIx - first] {
                let y = yOff + dataSource.textMetrics.ascent + linespace * CGFloat(lineIx)
                renderer.drawLine(line: textLine, x0: GLfloat(xOff), y0: GLfloat(y))
            }
        }

        // third pass: draw text decorations
        for lineIx in first..<last {
            if let textLine = textLines[lineIx - first] {
                let y = yOff + dataSource.textMetrics.ascent + linespace * CGFloat(lineIx)
                renderer.drawLineDecorations(line: textLine, x0: GLfloat(xOff), y0: GLfloat(y))
            }
        }

        // fourth pass: draw carets
        let cursorArgb = colorToArgb(cursorColor)
        for lineIx in first..<last {
            let relLineIx = lineIx - first
            if let textLine = textLines[relLineIx], let line = lines[relLineIx] {
                let y0 = yOff + linespace * CGFloat(lineIx)
                for cursor in line.cursor {
                    let utf16Ix = utf8_offset_to_utf16(line.text, cursor)
                    // Note: It's ugly that cursorPos is set as a side-effect
                    // TODO: disabled until firstRect logic is fixed
                    //self.cursorPos = (lineIx, utf16Ix)
                    if (markedRange().location != NSNotFound) {
                        let markRangeStart = utf16Ix - markedRange().length
                        if markRangeStart >= 0 {
                            let yBaseline = y0 + dataSource.textMetrics.ascent
                            // TODO: perhaps this shouldn't be hardcoded
                            let yRange = GLfloat(yBaseline + 2) ..< GLfloat(yBaseline + 3)
                            let utf16Range = markRangeStart ..< utf16Ix
                            renderer.drawRectForRange(line: textLine, x0: GLfloat(xOff), yRange: yRange, utf16Range: utf16Range, argb: colorToArgb(dataSource.theme.foreground))
                        }
                    }
                    if (selectedRange().location != NSNotFound) {
                        let selectedRangeStart = utf16Ix - markedRange().length + selectedRange().location
                        if selectedRangeStart >= 0 {
                            let yBaseline = y0 + dataSource.textMetrics.ascent
                            // TODO: perhaps this shouldn't be hardcoded
                            let yRange = GLfloat(yBaseline + 2) ..< GLfloat(yBaseline + 4)
                            let utf16Range = selectedRangeStart ..< selectedRangeStart + selectedRange().length
                            renderer.drawRectForRange(line: textLine, x0: GLfloat(xOff), yRange: yRange, utf16Range: utf16Range, argb: colorToArgb(dataSource.theme.foreground))
                        }
                    }
                    if showBlinkingCursor && _cursorStateOn {
                        // TODO: the caret positions should be saved in TextLine
                        let x = textLine.offsetForIndex(utf16Ix: utf16Ix)
                        let cursorWidth: GLfloat = 1.0
                        renderer.drawSolidRect(x: GLfloat(xOff + x) - 0.5 * cursorWidth, y: GLfloat(y0), width: cursorWidth, height: GLfloat(linespace), argb: cursorArgb)
                    }
                }
            }
        }

        // gutter drawing
        // Note: drawing the gutter background after the text effectively clips the text. This
        // is a bit of a hack, and some optimization might be possible with real clipping
        // (especially if the gutter background is the same as the theme background).
        renderer.drawSolidRect(x: 0, y: GLfloat(dirtyRect.origin.x), width: GLfloat(dataSource.gutterWidth), height: GLfloat(dirtyRect.height), argb: colorToArgb(dataSource.theme.gutter))
        for lineIx in first..<last {
            let relLineIx = lineIx - first
            guard let line = lines[relLineIx] else {
              continue
            }

            let gutterNumber = UInt(lineIx) + 1
            let gutterTL = gutterCache!.lookupLineNumber(lineIdx: gutterNumber, hasCursor: line.containsCursor)

            let x = dataSource.gutterWidth - (gutterXPad + CGFloat(gutterTL.width))
            let y0 = yOff + dataSource.textMetrics.ascent + linespace * CGFloat(lineIx)
            renderer.drawLine(line: gutterTL, x0: GLfloat(x), y0: GLfloat(y0))
        }
        lastRevisionRendered = lineCache.revision
        dataSource.maxWidthChanged(toWidth: maxLineWidth)
        Trace.shared.trace("EditView render", .main, .end)
    }
}
