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

protocol Renderer {
    var fontCache: FontCache { get }

    func beginDraw(size: CGSize, scale: CGFloat)
    func endDraw()

    func clear(_ color: NSColor)
    func drawSolidRect(x: GLfloat, y: GLfloat, width: GLfloat, height: GLfloat, argb: UInt32)
    func drawLine(line: TextLine, x0: GLfloat, y0: GLfloat)
    func drawLineBg(line: TextLine, x0: GLfloat, yRange: Range<GLfloat>)
    func drawRectForRange(line: TextLine, x0: GLfloat, yRange: Range<GLfloat>, utf16Range: CountableRange<Int>, argb: UInt32)
    func drawLineDecorations(line: TextLine, x0: GLfloat, y0: GLfloat)
}
