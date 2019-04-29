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

struct Config {
    let fontFace: String?
    let fontSize: CGFloat?
    let scrollPastEnd: Bool?
    let unifiedToolbar: Bool?
}

extension Config {
    init?(fromJson json: [String: Any]) {
        let fontFace = json["font_face"] as? String
        let fontSize = json["font_size"] as? CGFloat

        let scrollPastEnd = json["scroll_past_end"] as? Bool
        let unifiedToolbar = json["unified_titlebar"] as? Bool

        self.init(
            fontFace: fontFace,
            fontSize: fontSize,
            scrollPastEnd: scrollPastEnd,
            unifiedToolbar: unifiedToolbar
        )
    }
}
