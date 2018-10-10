// Copyright 2016 The xi-editor Authors.
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

public struct FpsMeasurement {
    fileprivate let start : DispatchTime
    fileprivate let end : DispatchTime

    public init(from start: DispatchTime, to end: DispatchTime) {
        self.start = start
        self.end = end
    }

    public static func fps(nanosecondsPerFrame: UInt64) -> Double {
        // seconds per frame = (nanoseconds per frame) / (nanoseconds per second)
        //                   === (ns/frame) / (ns/s)
        //                   === (ns/frame) * (s/ns)
        //                   === s/frame
        //
        // frames per second = 1 / (seconds per frame)
        //                   === 1 / (nanoseconds per frame / nanoseconds per second)
        //                   === nanoseconds per second / nanoseconds per frame
        //                   === (ns/s) / (ns/frame)
        //                   === (ns/s) * (frame/ns)
        return Double(NSEC_PER_SEC) / Double(nanosecondsPerFrame)
    }

    public func fps() -> Double {
        return FpsMeasurement.fps(nanosecondsPerFrame: self.elapsedNanoseconds())
    }

    public func elapsedSeconds() -> Double {
        return Double(self.elapsedNanoseconds()) / Double(NSEC_PER_SEC)
    }

    public func elapsedMilliseconds() -> Double {
        return Double(self.elapsedNanoseconds()) / Double(NSEC_PER_MSEC)
    }

    public func elapsedNanoseconds() -> UInt64 {
        return self.end.uptimeNanoseconds - self.start.uptimeNanoseconds
    }

    public func elapsedNanoseconds(since start: DispatchTime) -> UInt64 {
        return end.uptimeNanoseconds - start.uptimeNanoseconds
    }

    public func elapsedSeconds(since start: DispatchTime) -> Double {
        return Double(self.elapsedNanoseconds(since: start)) / Double(NSEC_PER_SEC)
    }
}

public class FpsTimer {
    private let fps : Fps
    private let start : DispatchTime

    fileprivate init(fps: Fps) {
        self.fps = fps
        self.start = DispatchTime.now()
    }

    deinit {
        let end = DispatchTime.now()
        self.fps.save(measurement: FpsMeasurement(from: start, to: end))
    }
}

public struct FpsSnapshot {
    private let samples: [FpsMeasurement]

    fileprivate init(samples: [FpsMeasurement]) {
        // Sort by increasing FPS (samples[0] is slowest frame, samples[len] is
        // fastest frame).
        self.samples = samples.sorted(by: { (fps1, fps2) -> Bool in
            return fps1.elapsedNanoseconds() >= fps2.elapsedNanoseconds()
        })
    }

    public func minFps() -> Double {
        return samples.first?.fps() ?? Double.nan
    }

    public func maxFps() -> Double {
        return samples.last?.fps() ?? Double.nan
    }

    public func fps(percentile: Double) -> Double {
        if samples.count == 0 {
            return Double.nan
        }

        var sample_idx = Int(Double(samples.count) * percentile)
        if sample_idx >= samples.count {
           sample_idx = samples.count - 1
        }
        return samples[sample_idx].fps()
    }

    public func meanFps() -> Double {
        let totalNanoseconds = samples.reduce(UInt64(0)) { (elapsedNanosTotal, measurement) -> UInt64 in
            return elapsedNanosTotal + measurement.elapsedNanoseconds()
        }
        let meanNanosecondsPerFrame = totalNanoseconds / UInt64(samples.count)
        return FpsMeasurement.fps(nanosecondsPerFrame: meanNanosecondsPerFrame)
    }
}

public protocol FpsObserver : class {
    func changed(fps: Double)
    func changed(fpsStats: FpsSnapshot)
}

fileprivate struct WeakFpsObserver {
    private weak var value: FpsObserver?

    init (_ value: FpsObserver) {
        self.value = value
    }

    func get() -> FpsObserver? {
        return self.value
    }
}

/// This gathers Fps samples via instrumentation.  It keeps a historical
/// record of the previous 1s of samples so that you can compute statistics
/// (min, max, percentiles, mean, etc).
public class Fps {
    /// A collection of all samples gathered over the previous second
    private var samples = [FpsMeasurement]()
    private var previousSecond : FpsSnapshot?
    private let snapshotThresholdSeconds = 1.0

    private var observers = [WeakFpsObserver]()

    public var snapshot : FpsSnapshot? {
        get {
            return self.previousSecond
        }
    }

    public func startRender() -> FpsTimer {
        return FpsTimer(fps: self)
    }

    fileprivate func save(measurement: FpsMeasurement) {
        samples.append(measurement)
        let sampleWindowSeconds = samples.last!.elapsedSeconds(since: samples.first!.start)
        if sampleWindowSeconds >= snapshotThresholdSeconds {
            previousSecond = FpsSnapshot(samples: samples)
            samples.removeAll(keepingCapacity: true)

            for observer in observers {
                observer.get()?.changed(fpsStats: previousSecond!)
            }
        }

        let currentFps = measurement.fps()
        for observer in observers {
            observer.get()?.changed(fps: currentFps)
        }
    }

    public func add(observer: FpsObserver) {
        observers.append(WeakFpsObserver(observer))
    }
}
