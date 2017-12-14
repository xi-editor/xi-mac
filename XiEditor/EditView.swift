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

class EditView: NSView, NSTextInputClient {
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
        super.init(coder: coder)
    }

    let x0: CGFloat = 2;

    override func draw(_ dirtyRect: NSRect) {
        if dataSource.document.coreViewIdentifier == nil { return }
        super.draw(dirtyRect)

        // draw the background
        let context = NSGraphicsContext.current!.cgContext
        dataSource.theme.background.setFill()
        dirtyRect.fill()

        // uncomment this to visualize dirty rects
        /*
        let path = NSBezierPath(ovalIn: dirtyRect)
        NSColor(red: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 0.25).setFill()
        path.fill()
        */

        let topPad = dataSource.textMetrics.linespace - dataSource.textMetrics.ascent
        let first = max(0, Int((floor(dirtyRect.origin.y - topPad) / dataSource.textMetrics.linespace)))
        let last = Int(ceil((dirtyRect.origin.y + dirtyRect.size.height - topPad) / dataSource.textMetrics.linespace))

        let lines = dataSource.lines.blockingGet(lines: first..<last)

        let missing = lines.enumerated().filter( { $0.element == nil } )
            .map( { $0.offset + first } )
        if !missing.isEmpty {
            print("draw missing lines: \(missing)")
        }

        // first pass, for drawing background selections and search highlights
        for lineIx in first...last {
            let relLineIx = lineIx - first
            guard relLineIx < lines.count, let line = lines[relLineIx], line.containsReservedStyle == true else { continue }
            let attrString = NSMutableAttributedString(string: line.text, attributes: dataSource.textMetrics.attributes)
            let ctline = CTLineCreateWithAttributedString(attrString)
            let y = dataSource.textMetrics.linespace * CGFloat(lineIx + 1)
            //TODO: also draw line highlight, as dictated by theme
            let selectionColor = self.isFrontmostView ? dataSource.theme.selection : dataSource.theme.inactiveSelection ?? dataSource.theme.selection
            selectionColor.setFill()
            let selections = line.styles.filter { $0.style == 0 }
            for selection in selections {
                let selStart = CTLineGetOffsetForStringIndex(ctline, selection.range.location, nil)
                let selEnd = CTLineGetOffsetForStringIndex(ctline, selection.range.location + selection.range.length, nil)
                context.fill(CGRect(x: x0 + selStart, y: y - dataSource.textMetrics.ascent,
                                    width: selEnd - selStart, height: dataSource.textMetrics.linespace))
            }

            dataSource.theme.findHighlight.setFill()
            let highlights = line.styles.filter { $0.style == 1 }
            for highlight in highlights {
                let selStart = CTLineGetOffsetForStringIndex(ctline, highlight.range.location, nil)
                let selEnd = CTLineGetOffsetForStringIndex(ctline, highlight.range.location + highlight.range.length, nil)
                context.fill(CGRect(x: x0 + selStart, y: y - dataSource.textMetrics.ascent,
                                    width: selEnd - selStart, height: dataSource.textMetrics.linespace))
            }
        }
        // second pass, for actually rendering text.
        for lineIx in first..<last {
            let relLineIx = lineIx - first
            guard relLineIx < lines.count, let line = lines[relLineIx] else { continue }
            let s = line.text
            var attrString = NSMutableAttributedString(string: s, attributes: dataSource.textMetrics.attributes)
            /*
            let randcolor = NSColor(colorLiteralRed: Float(drand48()), green: Float(drand48()), blue: Float(drand48()), alpha: 1.0)
            attrString.addAttribute(NSForegroundColorAttributeName, value: randcolor, range: NSMakeRange(0, s.utf16.count))
            */
            dataSource.styleMap.applyStyles(text: s, string: &attrString, styles: line.styles)
            for c in line.cursor {
                let cix = utf8_offset_to_utf16(s, c)

                self.cursorPos = (lineIx, cix)
                if (markedRange().location != NSNotFound) {
                    let markRangeStart = cix - markedRange().length
                    if (markRangeStart >= 0) {
                        attrString.addAttribute(NSAttributedStringKey.underlineStyle,
                                                value: NSUnderlineStyle.styleSingle.rawValue,
                                                range: NSMakeRange(markRangeStart, markedRange().length))
                    }
                }
                if (selectedRange().location != NSNotFound) {
                    let selectedRangeStart = cix - markedRange().length + selectedRange().location
                    if (selectedRangeStart >= 0) {
                        attrString.addAttribute(NSAttributedStringKey.underlineStyle,
                                                value: NSUnderlineStyle.styleThick.rawValue,
                                                range: NSMakeRange(selectedRangeStart, selectedRange().length))
                    }
                }
            }

            let y = dataSource.textMetrics.linespace * CGFloat(lineIx + 1);
            attrString.draw(with: NSRect(x: x0, y: y, width: dirtyRect.origin.x + dirtyRect.width - x0, height: 14), options: [])
            if showBlinkingCursor && _cursorStateOn {
                for cursor in line.cursor {
                    let ctline = CTLineCreateWithAttributedString(attrString)
                    /*
                    CGContextSetTextMatrix(context, CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: x0, ty: y))
                    CTLineDraw(ctline, context)
                    */
                    var pos = CGFloat(0)
                    // special case because measurement is so expensive; might have to rethink in rtl
                    if cursor != 0 {
                        let utf16_ix = utf8_offset_to_utf16(s, cursor)
                        pos = CTLineGetOffsetForStringIndex(ctline, CFIndex(utf16_ix), nil)
                    }
                    cursorColor.setStroke()
                    context.setShouldAntialias(false)
                    context.move(to: CGPoint(x: x0 + pos, y: y + dataSource.textMetrics.descent))
                    context.addLine(to: CGPoint(x: x0 + pos, y: y - dataSource.textMetrics.ascent))
                    context.strokePath()
                    context.setShouldAntialias(true)
                }
            }
        }
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
    
    // Mapping of selectors to simple no-parameter commands.
    static let selectorToCommand = [
        "deleteBackward:": "delete_backward",
        "deleteForward:": "delete_forward",
        "deleteToBeginningOfLine:": "delete_to_beginning_of_line",
        "deleteToEndOfParagraph:": "delete_to_end_of_paragraph",
        "deleteWordBackward:": "delete_word_backward",
        "deleteWordForward:": "delete_word_forward",
        "insertNewline:": "insert_newline",
        "insertTab:": "insert_tab",
        "moveBackward:": "move_backward",
        "moveDown:": "move_down",
        "moveDownAndModifySelection:": "move_down_and_modify_selection",
        "moveForward:": "move_forward",
        "moveLeft:": "move_left",
        "moveLeftAndModifySelection:": "move_left_and_modify_selection",
        "moveRight:": "move_right",
        "moveRightAndModifySelection:": "move_right_and_modify_selection",
        "moveToBeginningOfDocument:": "move_to_beginning_of_document",
        "moveToBeginningOfDocumentAndModifySelection:": "move_to_beginning_of_document_and_modify_selection",
        "moveToBeginningOfParagraph:": "move_to_beginning_of_paragraph",
        "moveToEndOfDocument:": "move_to_end_of_document",
        "moveToEndOfDocumentAndModifySelection:": "move_to_end_of_document_and_modify_selection",
        "moveToEndOfParagraph:": "move_to_end_of_paragraph",
        "moveToLeftEndOfLine:": "move_to_left_end_of_line",
        "moveToLeftEndOfLineAndModifySelection:": "move_to_left_end_of_line_and_modify_selection",
        "moveToRightEndOfLine:": "move_to_right_end_of_line",
        "moveToRightEndOfLineAndModifySelection:": "move_to_right_end_of_line_and_modify_selection",
        "moveUp:": "move_up",
        "moveUpAndModifySelection:": "move_up_and_modify_selection",
        "moveWordLeft:": "move_word_left",
        "moveWordLeftAndModifySelection:": "move_word_left_and_modify_selection",
        "moveWordRight:": "move_word_right",
        "moveWordRightAndModifySelection:": "move_word_right_and_modify_selection",
        "pageDownAndModifySelection:": "page_down_and_modify_selection",
        "pageUpAndModifySelection:": "page_up_and_modify_selection",
        "scrollPageDown:": "scroll_page_down",
        "scrollPageUp:": "scroll_page_up",
        // Note: these next two are mappings. Possible TODO to fix if core provides distinct behaviors
        "scrollToBeginningOfDocument:": "move_to_beginning_of_document",
        "scrollToEndOfDocument:": "move_to_end_of_document",
        "transpose:": "transpose",
        "yank:": "yank",
        "cancelOperation:": "cancel_operation",
    ]

    override func doCommand(by aSelector: Selector) {
        if (self.responds(to: aSelector)) {
            super.doCommand(by: aSelector);
        } else {
            if let commandName = EditView.selectorToCommand[aSelector.description] {
                dataSource.document.sendRpcAsync(commandName, params: []);
            } else {
                Swift.print("Unhandled selector: \(aSelector.description)")
                NSSound.beep()
            }
        }
    }
    
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
        let lineIx = yToLine(point.y)
        if let line = getLine(lineIx) {
            let s = line.text
            let attrString = NSAttributedString(string: s, attributes: dataSource.textMetrics.attributes)
            let ctline = CTLineCreateWithAttributedString(attrString)
            let relPos = NSPoint(x: point.x - x0, y: lineIxToBaseline(lineIx) - point.y)
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

    func getLine(_ lineNum: Int) -> Line? {
        return dataSource.lines.get(lineNum)
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
}
