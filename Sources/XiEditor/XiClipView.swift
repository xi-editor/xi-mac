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

protocol ScrollInterested: class {
    func willScroll(to newOrigin: NSPoint)
}

class XiClipView: NSClipView {
    weak var delegate: ScrollInterested?

    // Smooth scrolling (like the MacBook trackpad or Apple Magic Mouse) sends scroll events that are chunked, continuous and cumulative, 
    // and thus the scroll view's clipView's bounds is set properly (in small increments) for each of these small chunks of scrolling. 
    // Scrolling with notched mice scrolls in discrete units, takes into account acceleration but does not redraw the view when the view is continuously redrawn (like in xi-mac) during scrolling. 
    // This is because the bounds origin is only set after the scrolling has stopped completely.
    // We bypass this by simply setting the bound origin immediately. 
    override func scroll(to newOrigin: NSPoint) {
        delegate?.willScroll(to: newOrigin)
        super.setBoundsOrigin(newOrigin)
    }
}
