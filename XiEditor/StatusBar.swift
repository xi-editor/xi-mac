//
//  StatusBar.swift
//  XiEditor
//
//  Created by Dzũng Lê on 19/05/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Foundation
import Cocoa

enum StatusItemAlignment: String {
    case left = "left"
    case right = "right"
}

class StatusItem: NSTextField {

    var key: String = ""
    var value: String = ""
    var barAlignment: StatusItemAlignment

    init(_ key: String, _ value: String, _ barAlignment: String) {
        self.key = key
        self.value = value
        self.barAlignment = StatusItemAlignment(rawValue: barAlignment)!
        super.init(frame: NSZeroRect)

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

    private let backgroundColor = NSColor(deviceWhite: 0.9, alpha: 1.0)
    private let statusBarHeight: CGFloat = 20

    var leftItems = [StatusItem]()
    var rightItems = [StatusItem]()

    override var isFlipped: Bool {
        return true;
    }

    func setup(_ editView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightAnchor.constraint(equalToConstant: statusBarHeight).isActive = true
        self.widthAnchor.constraint(equalTo: editView.widthAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: editView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: editView.trailingAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: editView.bottomAnchor).isActive = true
    }

    // Adds a status bar item. Only appends status bar items for now.
    func addStatusItem(_ item: StatusItem) {
        item.translatesAutoresizingMaskIntoConstraints = false
        item.textColor = NSColor.black
        self.addSubview(item)
        item.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true

        switch item.barAlignment {
        case .left:
            if let lastLeftItem = self.leftItems.last {
                item.leadingAnchor.constraint(equalTo: lastLeftItem.trailingAnchor, constant: 10).isActive = true
            } else {
                item.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
            }
            leftItems.append(item)

        case .right:
            if let lastRightItem = self.rightItems.last {
                item.trailingAnchor.constraint(equalTo: lastRightItem.leadingAnchor, constant: 10).isActive = true
            } else {
                item.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
            }
            rightItems.append(item)
        }
    }

    // Update a status bar item with a new value.
    func updateStatusItem(_ key: String, _ value: String) {
        if let item = (leftItems + rightItems).first(where: { $0.key == key } )  {
            item.stringValue = value
        }
    }

    // Removes status bar item with a specified key.
    func removeStatusItem(_ key: String) {
        if let item = (leftItems + rightItems).first(where: { $0.key == key } )  {
            item.removeFromSuperview()
            leftItems = leftItems.filter { $0 != item }
            rightItems = rightItems.filter { $0 != item }
        }

        self.needsUpdateConstraints = true
    }

    // Update constraints of status bar items.
    // Called when the status bar item state is modified.
    override func updateConstraints() {
        for item in leftItems {
            if item == leftItems.first {
                item.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
            } else {
                item.leadingAnchor.constraint(equalTo: leftItems[leftItems.index(of: item)! - 1].leadingAnchor).isActive = true
            }
        }
        for item in rightItems {
            if item == rightItems.first {
                item.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
            } else {
                item.trailingAnchor.constraint(equalTo: rightItems[rightItems.index(of: item)! + 1].trailingAnchor).isActive = true
            }
        }
        super.updateConstraints()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath()
        backgroundColor.setFill()
        __NSRectFill(dirtyRect)
        path.move(to: CGPoint(x: dirtyRect.maxX, y: dirtyRect.minY))
        path.line(to: CGPoint(x: dirtyRect.minX, y: dirtyRect.minY))
    }
}
