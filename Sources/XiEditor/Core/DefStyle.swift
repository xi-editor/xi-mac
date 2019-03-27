// Copyright 2019 The xi-editor Authors.
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

import Foundation
import Cocoa

struct DefStyleParams {
    let styleID: Int
    let fgColor: NSColor?
    let bgColor: NSColor?
    let underline: Bool
    let italic: Bool
    let weight: Int?
}

extension DefStyleParams {
    init?(fromJson json: [String: Any]) {
        guard let styleID = json["id"] as? Int else { return nil }

        var fgColor: NSColor? = nil
        var bgColor: NSColor? = nil

        if let fg = json["fg_color"] as? UInt32 {
            fgColor = colorFromArgb(fg)
        }
        if let bg = json["bg_color"] as? UInt32 {
            bgColor = colorFromArgb(bg)
        }

        let underline = json["underline"] as? Bool ?? false
        let italic = json["italic"] as? Bool ?? false
        let weight = json["weight"] as? Int

        self.init(
            styleID: styleID,
            fgColor: fgColor, bgColor: bgColor,
            underline: underline, italic: italic, weight: weight
        )
    }
}
