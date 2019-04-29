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
    let findHighlights: [NSColor]?
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
        return Theme(foreground: .black,
              background: .white,
              caret: .black,
              lineHighlight: nil,
              findHighlights: [NSColor(deviceWhite: 0.8, alpha: 0.4)],
              findHighlightForeground: nil,
              gutter: NSColor(deviceWhite: 0.9, alpha: 1.0),
              gutterForeground: NSColor(deviceWhite: 0.5, alpha: 1.0),
              selection: .selectedTextBackgroundColor,
              selectionForeground: .selectedTextColor,
              selectionBorder: nil,
              inactiveSelection: NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),
              inactiveSelectionForeground: .selectedTextColor,
              shadow: nil
            )
    }

    init(fromJson json: [String: Any]) {
        let foreground = NSColor(jsonRgbaColor: json["foreground"] as? [String: Any] ?? [:])
        let background = NSColor(jsonRgbaColor: json["background"] as? [String: Any] ?? [:])
        let caret = NSColor(jsonRgbaColor: json["caret"] as? [String: Any] ?? [:])
        let line_highlight = NSColor(jsonRgbaColor: json["line_highlight"] as? [String: Any] ?? [:])

        let find_highlight: NSColor? = NSColor(jsonRgbaColor: json["find_highlight"] as? [String: Any] ?? [:])
        let find_highlight_foreground = NSColor(jsonRgbaColor: json["find_highlight_foreground"] as? [String: Any] ?? [:])
        let gutter = NSColor(jsonRgbaColor: json["gutter"] as? [String: Any] ?? [:])
        let gutter_foreground = NSColor(jsonRgbaColor: json["gutter_foreground"] as? [String: Any] ?? [:])

        let selection = NSColor(jsonRgbaColor: json["selection"] as? [String: Any] ?? [:])
        let selection_foreground = NSColor(jsonRgbaColor: json["selection_foreground"] as? [String: Any] ?? [:])
        let selection_border = NSColor(jsonRgbaColor: json["selection_border"] as? [String: Any] ?? [:])
        let inactive_selection = NSColor(jsonRgbaColor: json["inactive_selection"] as? [String: Any] ?? [:])
        let inactive_selection_foreground = NSColor(jsonRgbaColor: json["inactive_selection_foreground"] as? [String: Any] ?? [:])
        let shadow = NSColor(jsonRgbaColor: json["shadow"] as? [String: Any] ?? [:])

        let defaults = Theme.defaultTheme()
        self.init(
            foreground: foreground ?? defaults.foreground,
            background: background ?? defaults.background,
            caret: caret ?? defaults.caret,
            lineHighlight: line_highlight ?? defaults.lineHighlight,
            findHighlights: Theme.generateHighlightColors(findHighlight: find_highlight ?? defaults.findHighlights?.first!),
            findHighlightForeground: find_highlight_foreground ?? defaults.findHighlightForeground,
            gutter: gutter ?? (background ?? defaults.gutter),
            gutterForeground: gutter_foreground ?? defaults.gutterForeground,
            selection: selection ?? defaults.selection,
            selectionForeground: selection_foreground ?? defaults.selectionForeground,
            selectionBorder: selection_border ?? defaults.selectionBorder,
            inactiveSelection: inactive_selection ?? defaults.inactiveSelection,
            inactiveSelectionForeground: inactive_selection_foreground ?? defaults.inactiveSelectionForeground,
            shadow: shadow ?? defaults.shadow)
    }

    /// Helper function to generate highlight colors for multiple search queries. This is required because custom fields cannot be retrieved from themes. Therefore, it is not possible to define multiple highlight colors.
    static func generateHighlightColors(findHighlight: NSColor?) -> [NSColor]? {
        return findHighlight.map({(defaultHighlight: NSColor) -> [NSColor] in
            var hue: CGFloat = 0.0
            var saturation: CGFloat = 0.0
            var brightness: CGFloat = 0.0
            var alpha: CGFloat = 0.0
            defaultHighlight.usingColorSpaceName(.calibratedRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            // Leave room for default highlight and selection colors
            let customHighlights = Style.N_RESERVED_STYLES - 2
            return [defaultHighlight] + (0..<customHighlights).map({
                return NSColor(hue: CGFloat((1.0 / Double(customHighlights)) * Double($0)), saturation: 1, brightness: brightness, alpha: alpha)
            })
        })
    }
}

extension NSColor {
    convenience init?(jsonRgbaColor dict: [String: Any]) {
        guard let red = dict["r"] as? CGFloat,
              let green = dict["g"] as? CGFloat,
              let blue = dict["b"] as? CGFloat,
              let alpha = dict["a"] as? CGFloat else {
                return nil
        }
        self.init(red: red/255, green: green/255, blue: blue/255, alpha: alpha/255)
    }
}
