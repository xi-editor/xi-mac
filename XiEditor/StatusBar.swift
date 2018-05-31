// Copyright 2018 Google LLC
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

import Foundation
import Cocoa

enum StatusItemAlignment: String {
    case left = "left"
    case right = "right"
}

class StatusItem: NSTextField {

    let key: String
    var value: String = ""
    let barAlignment: StatusItemAlignment

    init(_ key: String, _ value: String, _ barAlignment: String) {
        self.key = key
        self.value = value
        self.barAlignment = StatusItemAlignment(rawValue: barAlignment)!
        super.init(frame: .zero)

        // Similar to what NSTextField convenience init creates
        self.isEditable = false
        self.isSelectable = false
        self.textColor = NSColor.labelColor
        self.backgroundColor = NSColor.clear
        self.lineBreakMode = .byClipping
        self.isBezeled = false
        self.stringValue = value
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class StatusBar: NSView {

    var backgroundColor: NSColor
    var itemTextColor: NSColor
    var statusBarPadding: CGFloat = 10
    let statusBarHeight: CGFloat = 20

    // This should change in the future, as ordering is alphabetical.
    var leftItems = [StatusItem]()
    var rightItems = [StatusItem]()

    var lastLeftItem: StatusItem?
    var lastRightItem: StatusItem?
    
    var currentItems = [String : StatusItem]()

    override var isFlipped: Bool {
        return true;
    }

    init(frame frameRect: NSRect, backgroundColor: NSColor, textColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.itemTextColor = textColor
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Adds a status bar item. Only appends status bar items for now.
    func addStatusItem(_ item: StatusItem) {
        if let existingItem = currentItems[item.key] {
            print("tried to add existing item \(existingItem.key), ignoring")
            return
        }
        item.translatesAutoresizingMaskIntoConstraints = false
        item.textColor = itemTextColor
        self.addSubview(item)
        item.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        currentItems[item.key] = item
        switch item.barAlignment {
            case .left:
                leftItems.append(item)
            case .right:
                rightItems.append(item)
        }
        self.needsUpdateConstraints = true
    }

    // Update a status bar item with a new value.
    func updateStatusItem(_ key: String, _ value: String) {
        if let item = currentItems[key] {
            item.stringValue = value
        } else {
            print("tried to update item with key \(key) that doesn't exist")
        }
    }

    // Removes status bar item with a specified key.
    func removeStatusItem(_ key: String) {
        if let item = currentItems[key]  {
            item.removeFromSuperview()
            leftItems = leftItems.filter { $0 != item }
            rightItems = rightItems.filter { $0 != item }
            currentItems.removeValue(forKey: key)
        } else {
            print("tried to remove item with \(key) that doesn't exist")
            return
        }
        self.needsUpdateConstraints = true
    }

    // Update constraints of status bar items.
    // Called when the status bar item state is modified.
    override func updateConstraints() {
        lastLeftItem = leftItems.first
        lastRightItem = rightItems.first

        for item in currentItems.values.sorted(by: {$0.key < $1.key}) {
            switch item.barAlignment {
            case .left:
                if item == leftItems.first {
                    item.leadingAnchor.constraint(equalTo:
                        self.leadingAnchor)
                        .isActive = true
                } else {
                    guard lastLeftItem != nil else { return }
                    item.leadingAnchor.constraint(equalTo:
                        lastLeftItem!.trailingAnchor, constant: statusBarPadding)
                        .isActive = true
                    lastLeftItem = item
                }
            case .right:
                if item == rightItems.first {
                    item.trailingAnchor.constraint(equalTo:
                        self.trailingAnchor)
                        .isActive = true
                } else {
                    guard lastRightItem != nil else { return }
                    item.trailingAnchor.constraint(equalTo:
                        lastRightItem!.leadingAnchor, constant: -statusBarPadding)
                        .isActive = true
                    lastRightItem = item
                }
            }
        }
        super.updateConstraints()
    }

    func updateStatusBarColor(newBackgroundColor: NSColor, newTextColor: NSColor) {
        self.backgroundColor = newBackgroundColor
        self.itemTextColor = newTextColor
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        backgroundColor.setFill()
        dirtyRect.fill()

        let borderColor = NSColor.black
        borderColor.setStroke()

        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: CGPoint(x: dirtyRect.minX, y: dirtyRect.minY))
        path.line(to: CGPoint(x: dirtyRect.maxX, y: dirtyRect.minY))
        path.stroke()

    }
}
