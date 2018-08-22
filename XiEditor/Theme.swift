// Copyright 2017 The xi-editor Authors.
//
// Licensed under the Apache License Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing software
// distributed under the License is distributed on an "AS IS" BASIS
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa


/// Theme information for styling an editor instance.
///
/// - Note: this is copied verbatim from
/// [syntect](https://github.com/trishume/syntect/blob/master/src/highlighting/theme.rs);
/// and that in turn is derived from TextMate's .tmTheme format. Many fields may not be used.
struct Theme {
    /// Text color for the view.
    let foreground: NSColor
    /// Backgound color of the view.
    let background: NSColor
    /// Color of the caret.
    let caret: NSColor
    /// Color of the line the caret is in.
    /// Only used when the `highlight_line` setting is set to `true`.
    let lineHighlight: NSColor?


    /// Background color of regions matching the current search.
    let findHighlight: NSColor
    let findHighlights = [      // todo: instead retrieve from theme definition
        NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.5),
        NSColor(red: 0.1, green: 0.1, blue: 1.0, alpha: 0.5),
        NSColor(red: 0.8, green: 0.1, blue: 1.0, alpha: 0.5),
        NSColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 0.5),
        NSColor(red: 1.0, green: 0.1, blue: 0.8, alpha: 0.5),
        NSColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 0.5),
        NSColor(red: 0.1, green: 1.0, blue: 0.8, alpha: 0.5),
    ]
    /// Background color of regions matching the current search.
    let findHighlightForeground: NSColor?

    /// Background color of the gutter.
    let gutter: NSColor
    /// The color of the line numbers in the gutter.
    let gutterForeground: NSColor

    /// The background color of selections.
    let selection: NSColor
    /// text color of the selection regions.
    let selectionForeground: NSColor
    /// Color of the selection regions border.
    let selectionBorder: NSColor?
    /// Background color of inactive selections (inactive view).
    let inactiveSelection: NSColor?
    /// Text color of inactive selections (inactive view).
    let inactiveSelectionForeground: NSColor?

    /// The color of the shadow used when a text area can be horizontally scrolled.
    let shadow: NSColor?
}

extension Theme {
    static func defaultTheme() -> Theme {
        return Theme(foreground: NSColor.black,
              background: NSColor.white,
              caret: NSColor.black,
              lineHighlight: nil,
              findHighlight: NSColor(deviceWhite: 0.8, alpha: 0.4),
              findHighlightForeground: nil,
              gutter: NSColor(deviceWhite: 0.9, alpha: 1.0),
              gutterForeground: NSColor(deviceWhite: 0.5, alpha: 1.0),
              selection: NSColor.selectedTextBackgroundColor,
              selectionForeground: NSColor.selectedTextColor,
              selectionBorder: nil,
              inactiveSelection: NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),
              inactiveSelectionForeground: NSColor.selectedTextColor,
              shadow: nil
            )
    }

    init(jsonObject dict: [String: AnyObject]) {
        let foreground = NSColor(jsonRgbaColor: dict["foreground"] as? [String: AnyObject] ?? [:])
        let background = NSColor(jsonRgbaColor: dict["background"] as? [String: AnyObject] ?? [:])
        let caret = NSColor(jsonRgbaColor: dict["caret"] as? [String: AnyObject] ?? [:])
        let line_highlight = NSColor(jsonRgbaColor: dict["line_highlight"] as? [String: AnyObject] ?? [:])

        let find_highlight = NSColor(jsonRgbaColor: dict["find_highlight"] as? [String: AnyObject] ?? [:])
        let find_highlight_foreground = NSColor(jsonRgbaColor: dict["find_highlight_foreground"] as? [String: AnyObject] ?? [:])
        let gutter = NSColor(jsonRgbaColor: dict["gutter"] as? [String: AnyObject] ?? [:])
        let gutter_foreground = NSColor(jsonRgbaColor: dict["gutter_foreground"] as? [String: AnyObject] ?? [:])

        let selection = NSColor(jsonRgbaColor: dict["selection"] as? [String: AnyObject] ?? [:])
        let selection_foreground = NSColor(jsonRgbaColor: dict["selection_foreground"] as? [String: AnyObject] ?? [:])
        let selection_border = NSColor(jsonRgbaColor: dict["selection_border"] as? [String: AnyObject] ?? [:])
        let inactive_selection = NSColor(jsonRgbaColor: dict["inactive_selection"] as? [String: AnyObject] ?? [:])
        let inactive_selection_foreground = NSColor(jsonRgbaColor: dict["inactive_selection_foreground"] as? [String: AnyObject] ?? [:])
        let shadow = NSColor(jsonRgbaColor: dict["shadow"] as? [String: AnyObject] ?? [:])

        let defaults = Theme.defaultTheme()
        self.init(
            foreground: foreground ?? defaults.foreground,
            background: background ?? defaults.background,
            caret: caret ?? defaults.caret,
            lineHighlight: line_highlight ?? defaults.lineHighlight,
            findHighlight: find_highlight ?? defaults.findHighlight,
            findHighlightForeground: find_highlight_foreground ?? defaults.findHighlightForeground,
            gutter: gutter ?? defaults.gutter,
            gutterForeground: gutter_foreground ?? defaults.gutterForeground,
            selection: selection ?? defaults.selection,
            selectionForeground: selection_foreground ?? defaults.selectionForeground,
            selectionBorder: selection_border ?? defaults.selectionBorder,
            inactiveSelection: inactive_selection ?? defaults.inactiveSelection,
            inactiveSelectionForeground: inactive_selection_foreground ?? defaults.inactiveSelectionForeground,
            shadow: shadow ?? defaults.shadow)
    }
}

extension NSColor {
    convenience init?(jsonRgbaColor dict: [String: AnyObject]) {
        guard let red = dict["r"] as? CGFloat,
              let green = dict["g"] as? CGFloat,
              let blue = dict["b"] as? CGFloat,
              let alpha = dict["a"] as? CGFloat else {
                return nil
        }
        self.init(red: red/255, green: green/255, blue: blue/255, alpha: alpha/255)
    }
}
