// Copyright 2017 The xi-editor Authors.
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

/// A half-open range representing lines in a document.
typealias LineRange = CountableRange<Int>

/// Represents a single line, including rendering information.
struct Line<T> {
    var text: String
    var cursor: [Int]
    var styles: [StyleSpan]
    /// Associated data, to be managed by client
    var assoc: T?

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

    /// Create a new line, applying new styles to an existing line's text
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

/// The underlying state of the cache, with methods for applying update deltas.
fileprivate class LineCacheState<T>: UnfairLock {
    /// A semaphore we use to wake up the main thread if it is blocking missing lines
    let waitingForLines = DispatchSemaphore(value: 0)
    /// Whether the main thread is waiting on the semaphore
    var isWaiting = false
    /// A revision count used for suppressing duplicated drawing; guaranteed nonzero
    var revision = 1

    var nInvalidBefore = 0;
    var lines: [Line<T>?] = []
    var nInvalidAfter = 0;

    var height: Int {
        return nInvalidBefore + lines.count + nInvalidAfter
    }

    var isEmpty: Bool {
        return  lines.count == 0 || (lines.count == 1 && lines[0]?.text  == "")
    }

    func _get(_ ix: Int) -> Line<T>? {
        if ix < nInvalidBefore { return nil }
        let ix = ix - nInvalidBefore
        if ix < lines.count {
            return lines[ix]
        }
        return nil
    }

    func setAssoc(_ ix: Int, _ assoc: T?) {
        assert(ix >= nInvalidBefore)
        let ix = ix - nInvalidBefore
        assert(ix < lines.count)
        lines[ix]!.assoc = assoc
    }

    func flushAssoc() {
        for ix in 0..<lines.count {
            lines[ix]?.assoc = nil
        }
    }

    func linesForRange(range: LineRange) -> [Line<T>?] {
        return range.map( { _get($0) } )
    }

    /// Updates the state by applying a delta. The update format is detailed in the
    /// [xi-core docs](https://github.com/google/xi-editor/blob/master/doc/update.md).
    func applyUpdate(update: [String: AnyObject]) -> InvalSet {
        let inval = InvalSet()
        guard let ops = update["ops"] else { return inval }
        let oldHeight = height
        var newInvalidBefore = 0
        var newLines: [Line<T>?] = []
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
        revision += 1

        if height < oldHeight {
            inval.addRange(start: height, end: oldHeight)
        }
        return inval
    }

    /// The set of lines which contain cursors.
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

/// An object that provides safe mutable access to the line cache state, as
/// it holds an associated mutex during its lifetime.
/// - Note: This uses a pattern that is very similar to Rust's
/// [MutexGuard](https://doc.rust-lang.org/std/sync/struct.MutexGuard.html).
class LineCacheLocked<T> {
    private var inner: LineCacheState<T>
    var shouldSignal = false

    fileprivate init(_ mutex: LineCacheState<T>) {
        inner = mutex
        inner.lock()
    }
    
    deinit {
        inner.unlock()
        if shouldSignal {
            inner.waitingForLines.signal()
            shouldSignal = false
        }
    }

    /// The maximum time (in milliseconds) to block when missing lines.
    let MAX_BLOCK_MS = 30;

    var isEmpty: Bool {
        return inner.isEmpty
    }

    var height: Int {
        return inner.height
    }

    var cursorInval: InvalSet {
        return inner.cursorInval
    }

    var revision: Int {
        return inner.revision
    }

    /// Returns the line for the given index, if it exists in the cache.
    func get(_ ix: Int) -> Line<T>? {
        return inner._get(ix)
    }

    /// Sets the associated data for a line. The line _must_ be valid.
    func setAssoc(_ ix: Int, assoc: T) {
        inner.setAssoc(ix, assoc)
    }

    /// Flushes all associated data, necessary on theme change.
    func flushAssoc() {
        inner.flushAssoc()
    }

    /**
     Returns the lines in `lineRange`, waiting for an update if necessary.

     - Note: If any of the lines in `lineRange` are absent in the cache, this method
     will block the calling thread for a short time, to see if the missing lines are
     contained in the next received update.
     */
    func blockingGet(lines lineRange: LineRange) -> [Line<T>?] {
        let lines = inner.linesForRange(range: lineRange)
        let missingLines = lineRange.enumerated()
            .filter( { lines.count > $0.offset && lines[$0.offset] == nil })
            .map( { $0.element })
        if !missingLines.isEmpty {
            // TODO: should we send request to core?
#if DEBUG
            print("waiting for lines: (\(missingLines.first!), \(missingLines.last!))")
#endif
            //TODO: this timing + printing code can come out
            // when we're comfortable with the performance and
            // the timeout duration
            let blockTime = DispatchTime.now()
            inner.isWaiting = true
            inner.unlock()
            Trace.shared.trace("blockingGet", .main, .begin)
            let waitResult = inner.waitingForLines.wait(timeout: .now() + .milliseconds(MAX_BLOCK_MS))
            Trace.shared.trace("blockingGet", .main, .end)
            inner.lock()

            let elapsed = DispatchTime.now().uptimeNanoseconds - blockTime.uptimeNanoseconds

            if inner.isWaiting {
                print("semaphore timeout \(elapsed / 1000)us \(waitResult)")
                inner.isWaiting = false
            } else {
                if waitResult == .timedOut {
                    // Semaphore was signalled after the wait timed out but before the
                    // lock was re-acquired.
                    inner.waitingForLines.wait()
                }
#if DEBUG
                print("finished waiting: \(elapsed / 1000)us \(waitResult)")
#endif
            }
        }

        return inner.linesForRange(range: lineRange)
    }

    /// Returns range of lines that have been invalidated
    func applyUpdate(update: [String: AnyObject]) -> InvalSet {
        Trace.shared.trace("applyUpdate", .main, .begin)
        let inval = inner.applyUpdate(update: update)
        Trace.shared.trace("applyUpdate", .main, .end)
        if inner.isWaiting {
            shouldSignal = true
            inner.isWaiting = false
        }
        return inval
    }
}

/**
 A cache of lines representing a document in xi-core. The cache is updated based
 on deltas from the core.

 - Note: To facilitate smooth scrolling, updates to the LineCache are expected
 to arrive on a dedicated thread. When drawing, lines are fetched through the
 `blockingGet(lines:)` method, which will block for some maximum amount of time
 waiting for the lines to arrive from xi-core.
 */
class LineCache<T> {

    /// The underlying cache state
    private let state = LineCacheState<T>()

    /// Lock the mutex protecting the linecache state and return an object giving
    /// safe mutable access to that state.
    func locked() -> LineCacheLocked<T> {
        return LineCacheLocked(state)
    }
    
    /// A boolean value indicating whether or not the linecache contains any text.
    /// - Note: An empty line cache will still contain a single empty line, this
    /// is sent as an update from the core after a new document is created.
    var isEmpty: Bool {
        return locked().isEmpty
    }

    /// The number of lines in the underlying document.
    var height: Int {
        return locked().height
    }

    /// Set of lines that need to be invalidated to blink the cursor
    var cursorInval: InvalSet {
        return locked().cursorInval
    }
}

/// A set of line numbers, represented as a collection of `LineRange`s.
class InvalSet {
    private var _ranges: [LineRange] = []
    
    /// The ranges of lines in this set.
    var ranges: [LineRange] {
        return _ranges
    }

    func addRange(start: Int, end: Int) {
        if _ranges.last?.upperBound == start {
            _ranges[ranges.count - 1] = _ranges[ranges.count - 1].lowerBound ..< end
        } else {
            _ranges.append(start..<end)
        }
    }

    func addRange(start: Int, n: Int) {
        addRange(start: start, end: start + n)
    }
}
