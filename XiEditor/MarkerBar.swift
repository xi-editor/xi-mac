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

class Marker {
    // let description: String
    let line: Int
    let color: NSColor

    init(_ line: Int, color: NSColor) {
        self.line = line
        self.color = color
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//class MarkerBar: NSView, CALayerDelegate {
//    var markers: [Marker] = []
//    var backgroundColor: NSColor = NSColor.clear
//    var parent: EditViewController!
//
//    var markerBarWidth: CGFloat = 16.0 {
//        didSet {
//            self.needsDisplay = true
//        }
//    }
//
//    var markerHeight: CGFloat = 1.0 {
//        didSet {
//            self.needsDisplay = true
//        }
//    }
//
//    override init(frame frameRect: NSRect) {
//        super.init(frame: .zero)
//        self.translatesAutoresizingMaskIntoConstraints = false
//        self.needsDisplay = true
//    }
//
//    @available(*, unavailable)
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    func setMarker(_ items: [Marker]) {
//        markers = items
//        self.needsDisplay = true
//    }
//
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        backgroundColor.setFill()
//        dirtyRect.fill()
//
//        let path = NSBezierPath()
//        path.lineWidth = 1
//        path.move(to: CGPoint(x: dirtyRect.minX, y: dirtyRect.minY))
//        path.line(to: CGPoint(x: dirtyRect.maxX, y: dirtyRect.minY))
//        path.stroke()
//
//        for marker in markers {
//            let totalLines = CGFloat(parent.lines.height)
//            let visiblesLines = CGFloat(parent.visibleLines.count)
//            let lineHeight = parent.textMetrics.linespace
//            let markerBarHeight = CGFloat(min(totalLines, visiblesLines)) * lineHeight
//
//            marker.color.setFill()
//            marker.color.setStroke()
//            path.lineWidth = markerHeight
//            path.move(to: CGPoint(x: dirtyRect.minX, y: dirtyRect.maxY - CGFloat(marker.line) / totalLines * markerBarHeight))
//            path.line(to: CGPoint(x: dirtyRect.maxX, y: dirtyRect.maxY - CGFloat(marker.line) / totalLines * markerBarHeight))
//            path.stroke()
//        }
//    }
//}
//
//
//class ScrollViewWithMarkerBar: NSScrollView {
//    var markerBar: MarkerBar!
//
//    private func showMarkerBar() {
//        markerBar.alphaValue = 1.0
//    }
//
//    @objc private func hideMarkerBar() {
//        NSAnimationContext.runAnimationGroup({_ in
//            NSAnimationContext.current.duration = 0.5
//            markerBar.animator().alphaValue = 0.0
//        }, completionHandler: {})
//    }
//
//    override func scrollWheel(with event: NSEvent) {
//        super.scrollWheel(with: event)
//        if event.type == NSEvent.EventType.scrollWheel {
//            switch event.phase {
//            case NSEvent.Phase.mayBegin, NSEvent.Phase.began, NSEvent.Phase.changed:
//                showMarkerBar()
//            case NSEvent.Phase.cancelled, NSEvent.Phase.ended:
//                if event.momentumPhase != NSEvent.Phase.changed &&
//                   event.momentumPhase != NSEvent.Phase.began {
//                    self.perform(#selector(hideMarkerBar), with: nil, afterDelay: 0.5)
//                }
//            default:
//                if event.momentumPhase == NSEvent.Phase.ended {
//                    self.perform(#selector(hideMarkerBar), with: nil, afterDelay: 0.5)
//                }
//                break
//            }
//        }
//    }
//}

//interface NSScroller (BWTSPrivate)
//- (NSRect)_drawingRectForPart:(NSScrollerPart)aPart;
//end


class MarkerBar: NSScroller {
    var markers: [Marker] = []
    var backgroundColor: NSColor = NSColor.red
    var parent: EditViewController!
    var markerLayer = CAShapeLayer()

    override func viewWillDraw() {
        super.viewWillDraw()
        self.layer?.sublayers?.last?.addObserver(self, forKeyPath: "opacity", options: .new, context: nil)
        self.layer?.addSublayer(markerLayer)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "opacity" {
            markerLayer.opacity = change![NSKeyValueChangeKey.newKey] as! Float
        }
    }

    var markerHeight: CGFloat = 1.0

    override class var isCompatibleWithOverlayScrollers: Bool {
        return true
    }

    override func drawKnob() {
        drawMarkers()
        super.drawKnob()
    }

    func setMarker(_ items: [Marker]) {
        markers = items
    }

    func drawMarkers() {
        print("markers")
        let path = CGMutablePath()
        let totalLines = CGFloat(parent.lines.height)
        let visiblesLines = CGFloat(parent.visibleLines.count)
        let lineHeight = parent.textMetrics.linespace
        let markerBarHeight = CGFloat(min(totalLines, visiblesLines)) * lineHeight

        for marker in markers {
            marker.color.setFill()
            marker.color.setStroke()

            markerLayer.fillColor = CGColor.init(red: 255, green: 255, blue: 255, alpha: 1.0)

            path.addRect(CGRect(x: markerLayer.bounds.minX, y:CGFloat(marker.line) / totalLines * markerBarHeight, width: 15, height: markerHeight))
            path.closeSubpath()
        }

        markerLayer.strokeColor = CGColor.init(red: 255, green: 255, blue: 255, alpha: 1.0)
        markerLayer.path = path
    }
}
