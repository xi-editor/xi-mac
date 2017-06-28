// Copyright 2017 Google Inc. All rights reserved.
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

let N_RESERVED_STYLES = 2

/// A represents a given text style.
struct Style {
    var font: NSFont?
    var fgColor: NSColor?
    var bgColor: NSColor?
    var underline: Bool
    var italic: Bool
    var weight: Int?
    var attributes: [String: Any] = [:]

    init(font fromFont: NSFont, fgColor: NSColor?, bgColor: NSColor?, underline: Bool, italic: Bool, weight: Int?) {
        if let fgColor = fgColor {
            attributes[NSForegroundColorAttributeName] = fgColor
        }

        if let bgColor = bgColor, bgColor.alphaComponent != 0.0 {
            attributes[NSBackgroundColorAttributeName] = bgColor
        }

        if underline {
            attributes[NSUnderlineStyleAttributeName] = NSUnderlineStyle.styleSingle.rawValue
        }

        let fm = NSFontManager.shared()
        var font: NSFont?

        if italic {
            var traits = fm.traits(of: fromFont)
            traits.insert(NSFontTraitMask.italicFontMask)
            if let f = closestMatch(of: fromFont, traits: traits, weight: weight ?? fm.weight(of: fromFont)) {
                font = f
            } else {
                attributes[NSObliquenessAttributeName] = 0.2
            }
        }

        if font == nil && weight != nil {
            font = closestMatch(of: fromFont, traits: fm.traits(of: fromFont), weight: weight!)
        }

        if let font = font {
            attributes[NSFontAttributeName] = font
        }

        self.font = font
        self.fgColor = fgColor
        self.bgColor = bgColor
        self.underline = underline
        self.italic = italic
        self.weight = weight
    }
}

typealias StyleIdentifier = Int

/// A basic type representing a range of text and and a style identifier.
struct StyleSpan {
    let range: NSRange
    let style: StyleIdentifier

    /// given a line of text and an array of style values, generate an array of StyleSpans.
    /// see https://github.com/google/xi-editor/blob/protocol_doc/doc/update.md
    static func styles(fromRaw raw: [Int], text: String) -> [StyleSpan] {
        var out: [StyleSpan] = [];
        var ix = 0;
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
    return s.utf8.index(s.utf8.startIndex, offsetBy: ix).samePosition(in: s.utf16)!._offset
}

/// A store of text styles, indexable by id.
class StyleMap {
    private var font: NSFont
    private var styles: [Style?] = []

    init(font: NSFont) {
        self.font = font
        let selectionStyle = Style(font: font,
                                   fgColor: (NSApplication.shared().delegate as! AppDelegate).theme.selectionForeground,
                                   bgColor: nil,
                                   underline: false,
                                   italic: false,
                                   weight: nil)
        let highlightStyle = Style(font: font,
                                   fgColor: (NSApplication.shared().delegate as! AppDelegate).theme.findHighlightForeground,
                                   bgColor: nil,
                                   underline: false,
                                   italic: false,
                                   weight: nil)
        self.styles.append(selectionStyle)
        self.styles.append(highlightStyle)
    }

    func defStyle(json: [String: AnyObject]) {
        guard let styleID = json["id"] as? Int else { return }

        let fgColor: NSColor
        var bgColor: NSColor? = nil

        if let fg = json["fg_color"] as? UInt32 {
            fgColor = colorFromArgb(fg)
        } else {
            fgColor = (NSApplication.shared().delegate as! AppDelegate).theme.foreground
        }
        if let bg = json["bg_color"] as? UInt32 {
            bgColor = colorFromArgb(bg)
        }

        let underline = json["underline"] as? Bool ?? false
        let italic = json["italic"] as? Bool ?? false
        var weight = json["weight"] as? Int
        if let w = weight {
            // convert to NSFont weight: (100-500 -> 2-6 (5 normal weight), 600-800 -> 8-10, 900 -> 12
            // see https://github.com/google/xi-mac/pull/32#discussion_r115114037
            weight = Int(floor(1 + Float(w) * (0.01 + 3e-6 * Float(w))))
        }
        
        let style = Style(font: font, fgColor: fgColor, bgColor: bgColor,
                          underline: underline, italic: italic, weight: weight)
        while styles.count < styleID {
            styles.append(nil)
        }
        if styles.count == styleID {
            styles.append(style)
        } else {
            styles[styleID] = style
        }
    }

    /// applies a given style to the AttributedString
    private func applyStyle(string: NSMutableAttributedString, id: Int, range: NSRange) {
        if id >= styles.count { return }
        guard let style = styles[id] else { return }

        string.addAttributes(style.attributes, range: range)
    }

    /// Given style information, applies the appropriate text attributes to the passed NSAttributedString
    func applyStyles(text: String, string: inout NSMutableAttributedString, styles: [StyleSpan]) {
        // we handle the 0 (selection) and 1 (search highlight) styles in EditView.drawRect
        for styleSpan in styles.filter({ $0.style >= N_RESERVED_STYLES }) {
                applyStyle(string: string, id: styleSpan.style, range: styleSpan.range)
        }
    }

    func updateFont(to font: NSFont) {
        self.font = font
        styles = styles.map { $0.map {
            Style(font: font, fgColor: $0.fgColor, bgColor: $0.bgColor,
                  underline: $0.underline, italic: $0.italic, weight: $0.weight)
        } }
    }
}

func closestMatch(of font: NSFont, traits: NSFontTraitMask, weight: Int) -> NSFont? {
    let fm = NSFontManager.shared()
    var weight = weight
    let fromWeight = fm.weight(of: font)
    let direction = fromWeight > weight ? 1 : -1
    while weight != fromWeight {
        if let f = fm.font(withFamily: font.familyName ?? font.fontName, traits: traits, weight: weight, size: font.pointSize) {
            return f
        }
        weight += direction
    }
    return nil
}
