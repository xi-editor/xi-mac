// Copyright 2018 Google LLC
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

class ShadowView: NSView {

    override var wantsUpdateLayer: Bool {
        return true
    }

    fileprivate var leftShadow = CAGradientLayer()
    fileprivate var rightShadow = CAGradientLayer()

    /// The x coordinate of the leftmost edge of the left shadow.
    /// If there is a gutter, this should equal the gutter's right edge.
    var leftShadowMinX: CGFloat = 0 {
        didSet {
            self.setNeedsDisplay(self.bounds)
        }
    }

    /// If set to true, this view will display a shadow at the left side of the view.
    var showLeftShadow: Bool = true {
        didSet {
            updateVisibility()
        }
    }
    /// If set to true, this view will display a shadow at the right side of the view.
    var showRightShadow: Bool = true {
        didSet {
            updateVisibility()
        }
    }

    func updateVisibility() {
        self.isHidden = !(showLeftShadow || showRightShadow)
        leftShadow.isHidden = !showLeftShadow
        rightShadow.isHidden = !showRightShadow
    }

    func setup() {
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        self.layer!.addSublayer(leftShadow)
        self.layer!.addSublayer(rightShadow)

        leftShadow.colors = [NSColor.shadowColor.cgColor, NSColor.clear.cgColor]
        leftShadow.transform = CATransform3DMakeRotation((3 * CGFloat.pi) / 2, 0, 0, 1)
        leftShadow.opacity = 0.4
        leftShadow.autoresizingMask = .layerHeightSizable

        rightShadow.colors = [NSColor.shadowColor.cgColor, NSColor.clear.cgColor]
        rightShadow.transform = CATransform3DMakeRotation(CGFloat.pi / 2, 0, 0, 1)
        rightShadow.opacity = 0.3
        rightShadow.autoresizingMask = [.layerHeightSizable, .layerMinXMargin]
        updateVisibility()
    }

    override func updateLayer() {
        //FIXME: magic numbers
        leftShadow.frame = CGRect(x: leftShadowMinX - 2, y: self.bounds.origin.y,
                                  width: 6, height: self.bounds.height)

        rightShadow.frame = CGRect(x: self.bounds.width - 4, y: self.bounds.origin.y,
                                   width: 4, height: self.bounds.height)
    }
}
