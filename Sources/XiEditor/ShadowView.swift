// Copyright 2018 The xi-editor Authors.
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

class ShadowView: NSView, CALayerDelegate {

    override var wantsUpdateLayer: Bool {
        return true
    }

    fileprivate var leftShadow = CAGradientLayer()
    fileprivate var rightShadow = CAGradientLayer()

    /// The x coordinate of the leftmost edge of the left shadow.
    /// If there is a gutter, this should equal the gutter's right edge.
    var leftShadowMinX: CGFloat = 0 {
        didSet {
            self.needsDisplay = true
        }
    }

    /// If set to true, this view will display a shadow at the left side of the view.
    var showLeftShadow: Bool = true {
        didSet {
            if showLeftShadow != oldValue {
                updateVisibility()
            }
        }
    }

    /// If set to true, this view will display a shadow at the right side of the view.
    var showRightShadow: Bool = true {
        didSet {
            if showRightShadow != oldValue {
                updateVisibility()
            }
        }
    }

    fileprivate var shadowColor = NSColor.shadowColor

    func updateShadowColor(newColor: NSColor?) {
        if newColor ?? NSColor.shadowColor != self.shadowColor {
            self.shadowColor = newColor ?? NSColor.shadowColor
            self.needsDisplay = true
        }
    }

    fileprivate func updateVisibility() {
        self.isHidden = !(showLeftShadow || showRightShadow)
        leftShadow.isHidden = !showLeftShadow
        rightShadow.isHidden = !showRightShadow
    }

    func setup() {
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        self.leftShadow.delegate = self
        self.rightShadow.delegate = self
        self.layer!.addSublayer(leftShadow)
        self.layer!.addSublayer(rightShadow)

        updateVisibility()
    }

    override func updateLayer() {
        leftShadow.frame = CGRect(x: leftShadowMinX, y: self.bounds.origin.y,
                                  width: 4, height: self.bounds.height)

        rightShadow.frame = CGRect(x: self.bounds.width - 4, y: self.bounds.origin.y,
                                   width: 4, height: self.bounds.height)

        leftShadow.colors = [shadowColor.cgColor, NSColor.clear.cgColor]
        leftShadow.transform = CATransform3DMakeRotation((3 * CGFloat.pi) / 2, 0, 0, 1)
        leftShadow.opacity = 0.4
        leftShadow.autoresizingMask = .layerHeightSizable

        rightShadow.colors = [shadowColor.cgColor, NSColor.clear.cgColor]
        rightShadow.transform = CATransform3DMakeRotation(CGFloat.pi / 2, 0, 0, 1)
        rightShadow.opacity = 0.4
        rightShadow.autoresizingMask = [.layerHeightSizable, .layerMinXMargin]
    }

    // by default hiding and revealing our shadows is animated, which is distracting
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return NSNull()
    }
}
