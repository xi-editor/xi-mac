// Copyright 2017 Google Inc. All rights reserved.
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

/// Represents a single line, including rendering information.
struct Line {
    var text: String
    var cursor: [Int]
    var styles: [StyleSpan]
    
    /// A Boolean value representing whether this line contains selected/highlighted text.
    /// This is used to determine whether we should pre-draw its background.
    var containsReservedStyle: Bool {
        return styles.contains { $0.style < N_RESERVED_STYLES }
    }

    /// A Boolean indicating whether this line contains a cursor.
    var containsCursor: Bool {
        return cursor.count > 0
    }

    init(fromJson json: [String: AnyObject]) {
        // this could be a more clear exception
        text = json["text"] as! String
        cursor = json["cursor"] as? [Int] ?? []
        if let styles = json["styles"] as? [Int] {
            self.styles = StyleSpan.styles(fromRaw: styles, text: self.text)
        } else {
            self.styles = []
        }
    }

    init?(updateFromJson line: Line?, json: [String: AnyObject]) {
        guard let line = line else { return nil }
        self.text = line.text
        cursor = json["cursor"] as? [Int] ?? line.cursor
        if let styles = json["styles"] as? [Int] {
            self.styles = StyleSpan.styles(fromRaw: styles, text: self.text)
        } else {
            self.styles = line.styles
        }
    }
}

/// A data structure holding a cache of lines, with methods for updating based
/// on deltas from the core.
class LineCache {
    var nInvalidBefore = 0;
    var lines: [Line?] = []
    var nInvalidAfter = 0;

    var height: Int {
        get {
            return nInvalidBefore + lines.count + nInvalidAfter
        }
    }
    
    /// A boolean value indicating whether or not the linecache contains any text.
    /// - Note: An empty line cache will still contain a single empty line, this
    /// is sent as an update from the core after a new document is created.
    var isEmpty: Bool {
        return lines.count == 0 || (lines.count == 1 && lines[0]?.text  == "")
    }

    func get(_ ix: Int) -> Line? {
        if ix < nInvalidBefore { return nil }
        let ix = ix - nInvalidBefore
        if ix < lines.count {
            return lines[ix]
        }
        return nil
    }
    
    /// Returns range of lines that have been invalidated
    func applyUpdate(update: [String: Any]) -> InvalSet {
        let inval = InvalSet()
        guard let ops = update["ops"] else { return inval }
        let oldHeight = height
        var newInvalidBefore = 0
        var newLines: [Line?] = []
        var newInvalidAfter = 0
        var oldIx = 0;
        for op in ops as! [[String: AnyObject]] {
            guard let op_type = op["op"] as? String else { return inval }
            guard let n = op["n"] as? Int else { return inval }
            switch op_type {
            case "invalidate":
                // Add only lines that were not already invalid
                let curLine = newInvalidBefore + newLines.count + newInvalidAfter
                let ix = curLine - nInvalidBefore
                if ix + n > 0 && ix < lines.count {
                    for i in max(ix, 0) ..< min(ix + n, lines.count) {
                        if lines[i] != nil {
                            inval.addRange(start: i + nInvalidBefore, n: 1)
                        }
                    }
                }
                if newLines.count == 0 {
                    newInvalidBefore += n
                } else {
                    newInvalidAfter += n
                }
            case "ins":
                for _ in 0..<newInvalidAfter {
                    newLines.append(nil)
                }
                newInvalidAfter = 0
                inval.addRange(start: newInvalidBefore + newLines.count, n: n)
                guard let json_lines = op["lines"] as? [[String: AnyObject]] else { return inval }
                for json_line in json_lines {
                    newLines.append(Line(fromJson: json_line))
                }
            case "copy", "update":
                var nRemaining = n
                if oldIx < nInvalidBefore {
                    let nInvalid = min(n, nInvalidBefore - oldIx)
                    if newLines.count == 0 {
                        newInvalidBefore += nInvalid
                    } else {
                        newInvalidAfter += nInvalid
                    }
                    oldIx += nInvalid
                    nRemaining -= nInvalid
                }
                if nRemaining > 0 && oldIx < nInvalidBefore + lines.count {
                    for _ in 0..<newInvalidAfter {
                        newLines.append(nil)
                    }
                    newInvalidAfter = 0
                    let nCopy = min(nRemaining, nInvalidBefore + lines.count - oldIx)
                    if oldIx != newInvalidBefore + newLines.count || op_type != "copy" {
                        inval.addRange(start: newInvalidBefore + newLines.count, n: nCopy)
                    }
                    let startIx = oldIx - nInvalidBefore
                    if op_type == "copy" {
                        newLines.append(contentsOf: lines[startIx ..< startIx + nCopy])
                    } else {
                        guard let json_lines = op["lines"] as? [[String: AnyObject]] else { return inval }
                        var jsonIx = n - nRemaining
                        for ix in startIx ..< startIx + nCopy {
                            newLines.append(Line(updateFromJson: lines[ix], json: json_lines[jsonIx]))
                            jsonIx += 1
                        }
                    }
                    oldIx += nCopy
                    nRemaining -= nCopy
                }
                if newLines.count == 0 {
                    newInvalidBefore += nRemaining
                } else {
                    newInvalidAfter += nRemaining
                }
                oldIx += nRemaining
            case "skip":
                oldIx += n
            default:
                print("unknown op type \(op_type)")
            }
        }
        nInvalidBefore = newInvalidBefore
        lines = newLines
        nInvalidAfter = newInvalidAfter
        if height < oldHeight {
            inval.addRange(start: height, end: oldHeight)
        }
        return inval
    }

    /// Return ranges of invalid lines within the given range
    func computeMissing(_ first: Int, _ last: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        let last = min(last, height)  // lines past the end aren't considered missing
        guard first < last else {
            Swift.print("compute missing called with first > last")
            return result
        }
        
        for ix in first..<last {
            // could optimize a bit here, but unlikely to be important
            if ix < nInvalidBefore || ix >= nInvalidBefore + lines.count || lines[ix - nInvalidBefore] == nil {
                if result.count == 0 || result[result.count - 1].1 != ix {
                    result.append((ix, ix + 1))
                } else {
                    result[result.count - 1].1 = ix + 1
                }
            }
        }
        return result
    }

    /// Set of lines that need to be invalidated to blink the cursor
    var cursorInval: InvalSet {
        let inval = InvalSet()
        for (i, line) in lines.enumerated() {
            if line?.containsCursor ?? false {
                inval.addRange(start: i + nInvalidBefore, n: 1)
            }
        }
        return inval
    }
}

/// A set of line numbers to be invalidated, in run-length representation
class InvalSet {
    var ranges: [(Int, Int)] = []

    func addRange(start: Int, end: Int) {
        if ranges.last?.1 == start {
            ranges[ranges.count - 1].1 = end
        } else {
            ranges.append((start, end))
        }
    }

    func addRange(start: Int, n: Int) {
        addRange(start: start, end: start + n)
    }
}
