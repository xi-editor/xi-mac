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

class GutterView: NSView {
    var dataSource: EditViewDataSource!
    let xPadding: CGFloat = 8

    override var isFlipped: Bool {
        return true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current()!.cgContext
        NSColor(deviceWhite: 0.9, alpha: 1.0).setFill()
        NSRectFill(dirtyRect)
        context.setShouldSmoothFonts(true)
        
        var fontAttributes = dataSource.textMetrics.attributes
        fontAttributes[NSForegroundColorAttributeName] = NSColor(deviceWhite: 0.5, alpha: 1.0)
        let first = Int(floor(dirtyRect.origin.y / dataSource.textMetrics.linespace))
        let last = min(Int(ceil((dirtyRect.origin.y + dirtyRect.size.height) / dataSource.textMetrics.linespace)), dataSource.lines.height)
        guard first < last else {
            Swift.print("gutterview first > last")
            return
        }

        for lineNb in first..<last {
            let y = dataSource.textMetrics.linespace * CGFloat(lineNb + 1)
            let attrString = NSMutableAttributedString(string: "\(lineNb)", attributes: fontAttributes)
            let expectedSize = attrString.size()
            attrString.draw(with: NSRect(x: dataSource.gutterWidth - expectedSize.width - xPadding, y: y, width: expectedSize.width, height: expectedSize.height), options: NSStringDrawingOptions(rawValue: 0))
        }
        super.draw(dirtyRect)
    }
}
