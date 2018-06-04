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

        // Similar to what NSTextField's label convenience init creates
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

    var currentItems = [String : StatusItem]()
    var hiddenItems = [StatusItem]()
    var leftItems: [StatusItem] {
        return currentItems.values
            .filter { $0.barAlignment == .left }
            .sorted { $0.key < $1.key }
    }
    var rightItems: [StatusItem] {
        return currentItems.values
            .filter { $0.barAlignment == .right }
            .sorted { $0.key < $1.key }
    }

    var lastLeftItem: StatusItem?
    var lastRightItem: StatusItem?

    var backgroundColor: NSColor = NSColor.white
    var itemTextColor: NSColor = NSColor.black
    let statusBarPadding: CGFloat = 10
    let statusBarHeight: CGFloat = 20

    // Returns the minimum width required to display all items.
    var minWidth: CGFloat {
        return currentItems.values
            .map({$0.frame.width})
            .reduce(CGFloat(currentItems.count - 1) * statusBarPadding, +)
    }

    // Difference to compensate for when status bar is resized
    let minWidthDifference: CGFloat = 2

    override var isFlipped: Bool {
        return true;
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Adds a status bar item.
    func addStatusItem(_ item: StatusItem) {
        if let existingItem = currentItems[item.key] {
            print("tried to add existing item with key \(existingItem.key), ignoring")
            return
        }
        item.translatesAutoresizingMaskIntoConstraints = false
        item.textColor = itemTextColor
        self.addSubview(item)
        currentItems[item.key] = item
        updateItemVisibility(windowWidth: self.superview!.frame.width)
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
        if let item = currentItems[key] {
            item.removeFromSuperview()
            currentItems.removeValue(forKey: key)
        } else {
            print("tried to remove item with \(key) that doesn't exist")
            return
        }
        self.needsUpdateConstraints = true
    }

    // Also handles ordering of status bar items.
    // Called when the status bar item state is modified.
    override func updateConstraints() {
        lastLeftItem = leftItems.first
        lastRightItem = rightItems.first

        for item in currentItems.values.sorted(by: {$0.key < $1.key}) {
            item.removeFromSuperview()
            switch item.barAlignment {
            case .left:
                if item == leftItems.first {
                    self.addSubview(item)
                    item.leadingAnchor.constraint(equalTo:
                        self.leadingAnchor)
                        .isActive = true
                } else {
                    guard lastLeftItem != nil else { return }
                    self.addSubview(item)
                    item.leadingAnchor.constraint(equalTo:
                        lastLeftItem!.trailingAnchor, constant: statusBarPadding)
                        .isActive = true
                }
                lastLeftItem = item
            case .right:
                if item == rightItems.first {
                    self.addSubview(item)
                    item.trailingAnchor.constraint(equalTo:
                        self.trailingAnchor)
                        .isActive = true
                } else {
                    guard lastRightItem != nil else { return }
                    self.addSubview(item)
                    item.trailingAnchor.constraint(equalTo:
                        lastRightItem!.leadingAnchor, constant: -statusBarPadding)
                        .isActive = true
                }
                lastRightItem = item
            }
            item.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        }
        super.updateConstraints()
    }

    func updateStatusBarColor(newBackgroundColor: NSColor, newTextColor: NSColor) {
        self.backgroundColor = newBackgroundColor
        self.itemTextColor = newTextColor
        self.needsDisplay = true
    }

    func updateItemVisibility(windowWidth: CGFloat) {
        if windowWidth < minWidth {
            repeat {
                if leftItems.count > rightItems.count {
                    guard lastLeftItem != nil else { return }
                    lastLeftItem!.isHidden = true
                    currentItems.removeValue(forKey: lastLeftItem!.key)
                    hiddenItems.append(lastLeftItem!)
                    lastLeftItem = leftItems[leftItems.count - 1]
                } else {
                    guard lastRightItem != nil else { return }
                    lastRightItem!.isHidden = true
                    currentItems.removeValue(forKey: lastRightItem!.key)
                    hiddenItems.append(lastRightItem!)
                    lastRightItem = rightItems[rightItems.count - 1]
                }
            } while (windowWidth < minWidth)
        } else {
            if let lastHiddenItem = hiddenItems.last {
                let newMinWidth = minWidth + statusBarPadding + lastHiddenItem.frame.width
                if (newMinWidth - windowWidth) < minWidthDifference {
                    lastHiddenItem.isHidden = false
                    switch lastHiddenItem.barAlignment {
                    case .left:
                        lastLeftItem = lastHiddenItem
                    case .right:
                        lastRightItem = lastHiddenItem
                    }
                    currentItems[lastHiddenItem.key] = lastHiddenItem
                    self.needsUpdateConstraints = true
                    hiddenItems.removeLast()
                }
            }
        }
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
