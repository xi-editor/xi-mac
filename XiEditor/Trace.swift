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

// A simple mechanism for logging trace events and outputting a file in
// Chrome tracing format

import Foundation

/// Collect trace events so they can be output in Chrome tracing format.
class Trace {
    let mutex = UnfairLock()
    let BUF_SIZE = 100_000
    var buf: [TraceEntry]
    var n_entries = 0
    let mach_time_numer: UInt64
    let mach_time_denom: UInt64

    /// Shared instance, most uses should call this.
    static var shared = Trace()

    init() {
        buf = [TraceEntry](repeating: TraceEntry(), count: BUF_SIZE)
        var info = mach_timebase_info(numer: 0, denom: 0)
        mach_timebase_info(&info)
        mach_time_numer = UInt64(info.numer)
        // the 1000 is because mach time is ns, and chrome tracing time is us
        mach_time_denom = UInt64(info.denom) * 1000
    }

    func trace(_ name: String, _ cat: TraceCategory, _ ph: TracePhase) {
        mutex.lock()
        let i = n_entries % BUF_SIZE
        buf[i].name = name
        buf[i].cat = cat
        buf[i].ph = ph
        buf[i].abstime = mach_absolute_time()
        pthread_threadid_np(nil, &buf[i].tid)
        n_entries += 1
        mutex.unlock()
    }

    // TODO: more control over where this gets saved
    func write() {
        let pid = getpid()
        let path = "/tmp/xi-trace-\(pid)"
        if !FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) {
            print("error creating trace file")
            return
        }
        guard let fh = FileHandle(forWritingAtPath: path) else {
            print("error opening trace file for writing")
            return
        }
        fh.write(Data("[\n".utf8))
        for entry_num in max(0, n_entries - BUF_SIZE) ..< n_entries {
            let i = entry_num % BUF_SIZE
            let ts = buf[i].abstime * mach_time_numer / mach_time_denom
            let comma = entry_num == n_entries - 1 ? "" : ","
            fh.write(Data("""
                  {"name": "\(buf[i].name)", "cat": "\(buf[i].cat)", "ph": "\(buf[i].ph.rawValue)", \
                "pid": \(pid), "tid": \(buf[i].tid), "ts": \(ts)}\(comma)\n
                """.utf8))
        }
        fh.write(Data("]\n".utf8))
    }
}

enum TraceCategory: String {
    case main
    case rpc
}

enum TracePhase: String {
    case begin = "B"
    case end = "E"
    case instant = "I"
}

struct TraceEntry {
    var name: String
    var cat: TraceCategory
    var ph: TracePhase
    var abstime: UInt64  // In mach_absolute_time format
    var tid: UInt64

    /// Create a default trace entry, contents don't matter as it's just preallocated
    init() {
        name = ""
        cat = .main
        ph = .instant
        abstime = mach_absolute_time()
        tid = 0
    }
}
