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


/// A represents a given text style.
struct Style {
    let font: NSFont?
    let fgColor: NSColor?
    let bgColor: NSColor?
    let underline: Bool
    let italic: Bool
    let weight: Int?
    let attributes: [NSAttributedString.Key: Any]
    let fakeItalic: Bool

    static let N_RESERVED_STYLES = 8        // todo: can be removed in the future for new update protocol

    init(fromFont: NSFont, fgColor: NSColor?, bgColor: NSColor?, underline: Bool, italic: Bool, weight: Int?) {
        var attributes: [NSAttributedString.Key: Any] = [:]

        if let fgColor = fgColor {
            attributes[NSAttributedString.Key.foregroundColor] = fgColor
        }

        if let bgColor = bgColor, bgColor.alphaComponent != 0.0 {
            attributes[NSAttributedString.Key.backgroundColor] = bgColor
        }

        if underline {
            attributes[NSAttributedString.Key.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        let fm = NSFontManager.shared
        var font: NSFont?
        var fakeItalic = false

        if italic {
            var traits = fm.traits(of: fromFont)
            traits.insert(NSFontTraitMask.italicFontMask)
            if let f = closestMatch(of: fromFont, traits: traits, weight: weight ?? fm.weight(of: fromFont)) {
                font = f
            } else {
                attributes[NSAttributedString.Key.obliqueness] = 0.2
                fakeItalic = true
            }
        }

        if font == nil && weight != nil {
            font = closestMatch(of: fromFont, traits: fm.traits(of: fromFont), weight: weight!)
        }

        if let font = font {
            attributes[NSAttributedString.Key.font] = font
        }

        self.font = font
        self.fgColor = fgColor
        self.bgColor = bgColor
        self.underline = underline
        self.italic = italic
        self.weight = weight
        self.attributes = attributes
        self.fakeItalic = fakeItalic
    }

    func withFont(_ font: NSFont) -> Style {
        return Style(
            fromFont: font,
            fgColor: self.fgColor, bgColor: self.bgColor,
            underline: self.underline, italic: self.italic, weight: self.weight)
    }
}

typealias StyleIdentifier = Int

/// A basic type representing a range of text and and a style identifier.
struct StyleSpan {
    let range: NSRange
    let style: StyleIdentifier

    /// given a line of text and an array of style values, generate an array of StyleSpans.
    /// see http://xi-editor.github.io/xi-editor/docs/frontend-protocol.html#def_style
    static func styles(fromRaw raw: [Int], text: String) -> [StyleSpan] {
        var out: [StyleSpan] = []
        var ix = 0
        for i in stride(from: 0, to: raw.count, by: 3) {
            let start = ix + raw[i]
            let end = start + raw[i + 1]
            let style = raw[i + 2]
            let startIx = utf8_offset_to_utf16(text, start)
            let endIx = utf8_offset_to_utf16(text, end)
            if startIx < 0 || endIx < startIx {
                //FIXME: how should we be doing error handling?
                print("malformed style array for line:", text, raw)
            } else {
                out.append(StyleSpan(range: NSMakeRange(startIx, endIx - startIx), style: style))
            }
            ix = end
        }
        return out
    }
}

func utf8_offset_to_utf16(_ s: String, _ ix: Int) -> Int {
    return s.utf8.index(s.utf8.startIndex, offsetBy: ix).utf16Offset(in: s)
}

/// A store of text styles, indexable by id.
class StyleMapState: UnfairLock {
    private var font: NSFont
    private var styles: [Style?] = []

    init(font: NSFont, theme: Theme) {
        self.font = font
    }

    func defStyle(params: DefStyleParams) {
        let fgColor: NSColor

        if let fg = params.fgColor {
            fgColor = fg
        } else {
            fgColor = (NSApplication.shared.delegate as! AppDelegate).xiClient.theme.foreground
        }

        var weight = params.weight
        if let w = params.weight {
            // convert to NSFont weight: (100-500 -> 2-6 (5 normal weight), 600-800 -> 8-10, 900 -> 12
            // see https://github.com/xi-editor/xi-mac/pull/32#discussion_r115114037
            weight = Int(floor(1 + Float(w) * (0.01 + 3e-6 * Float(w))))
        }

        let style = Style(fromFont: font, fgColor: fgColor, bgColor: params.bgColor,
                          underline: params.underline,
                          italic: params.italic,
                          weight: weight)

        while styles.count < params.styleID   {
            styles.append(nil)
        }
        if styles.count == params.styleID {
            styles.append(style)
        } else {
            styles[params.styleID] = style
        }
    }

    func applyStyle(builder: TextLineBuilder, id: Int, range: NSRange) {
        if id < 0 || id >= styles.count {
            print("stylemap can't resolve \(id)")
            return
        }

        // todo: remove once update protocol does not have reserved styles anymore
        if id >= Style.N_RESERVED_STYLES {
            guard let style = styles[id] else { return }
            if let fgColor = style.fgColor {
                builder.addFgSpan(range: convertRange(range), argb: colorToArgb(fgColor))
            }
            if let bgColor = style.bgColor {
                builder.addBgSpan(range: convertRange(range), argb: colorToArgb(bgColor))
            }
            if let font = style.font {
                builder.addFontSpan(range: convertRange(range), font: font)
            }
            if style.fakeItalic {
                builder.addFakeItalicSpan(range: convertRange(range))
            }
            if style.underline {
                builder.addUnderlineSpan(range: convertRange(range), style: .single)
            }
        }
    }

    func applyStyles(builder: TextLineBuilder, styles: [StyleSpan]) {
        for styleSpan in styles {
            if styleSpan.style >= Style.N_RESERVED_STYLES {
                // Theme-provided background colors are rendered first
                applyStyle(builder: builder, id: styleSpan.style, range: styleSpan.range)
            }
        }
    }

    func updateFont(to font: NSFont) {
        self.font = font
        styles = styles.map { $0.map {
            $0.withFont(font)
        } }
    }

    func measureWidth(id: Int, s: String) -> Double {
        let builder = TextLineBuilder(s, font: self.font)
        let range = NSMakeRange(0, s.utf16.count)
        applyStyle(builder: builder, id: id, range: range)
        return builder.measure()
    }

    func measureWidths(_ args: [MeasureWidthParams]) -> [[Double]] {
        Trace.shared.trace("measureWidths", .main, .begin)
        defer { Trace.shared.trace("measureWidths", .main, .end) }

        return args.map { p in
            return p.strings.map { s in measureWidth(id: p.id, s: s)}
        }
    }
}

/// Safe access to the style map, holding a lock
class StyleMapLocked {
    private var inner: StyleMapState

    fileprivate init(_ mutex: StyleMapState) {
        inner = mutex
        inner.lock()
    }

    deinit {
        inner.unlock()
    }

    /// Defines a style that can then be referred to by index.
    func defStyle(params: DefStyleParams) {
        inner.defStyle(params: params)
    }

    /// Applies the styles to the text line builder.
    func applyStyles(builder: TextLineBuilder, styles: [StyleSpan]) {
        inner.applyStyles(builder: builder, styles: styles)
    }

    func updateFont(to font: NSFont) {
        inner.updateFont(to: font)
    }

    func measureWidths(_ args: [MeasureWidthParams]) -> [[Double]] {
        return inner.measureWidths(args)
    }
}

class StyleMap {
    private let state: StyleMapState

    init(font: NSFont, theme: Theme) {
        state = StyleMapState(font: font, theme: theme)
    }

    func locked() -> StyleMapLocked {
        return StyleMapLocked(state)
    }
}

func closestMatch(of font: NSFont, traits: NSFontTraitMask, weight: Int) -> NSFont? {
    let fm = NSFontManager.shared
    var weight = weight
    let fromWeight = fm.weight(of: font)
    let direction = fromWeight > weight ? 1 : -1
    while true {
        if let f = fm.font(withFamily: font.familyName ?? font.fontName, traits: traits, weight: weight, size: font.pointSize) {
            return f
        }
        if weight == fromWeight || weight + direction == fromWeight {
            break
        }
        weight += direction
    }
    return nil
}

func convertRange(_ range: NSRange) -> CountableRange<Int> {
    return range.location ..< (range.location + range.length)
}
