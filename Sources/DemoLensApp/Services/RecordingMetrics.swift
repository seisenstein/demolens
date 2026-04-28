import Foundation

struct RecordingMetrics: Sendable {
    var framesRendered: Int = 0
    var framesDropped: Int = 0
    var audioSamplesDropped: Int = 0
    var latestFrameReplacements: Int = 0
    var writerNotReadyVideo: Int = 0
    var renderTimesMs: [Double] = []
    var appendTimesMs: [Double] = []
    var audioBufferedMsSystem: Double = 0
    var audioBufferedMsMicrophone: Double = 0

    var renderLatencyP50: Double { percentile(renderTimesMs, percentile: 0.50) }
    var renderLatencyP95: Double { percentile(renderTimesMs, percentile: 0.95) }
    var appendLatencyP50: Double { percentile(appendTimesMs, percentile: 0.50) }
    var appendLatencyP95: Double { percentile(appendTimesMs, percentile: 0.95) }

    private func percentile(_ values: [Double], percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * percentile)))
        return sorted[index]
    }
}

final class RecordingMetricsStore: @unchecked Sendable {
    private let lock = NSLock()
    private var metrics = RecordingMetrics()

    func snapshot() -> RecordingMetrics {
        lock.withLock { metrics }
    }

    func incrementFramesRendered() {
        lock.withLock { metrics.framesRendered += 1 }
    }

    func incrementFramesDropped() {
        lock.withLock { metrics.framesDropped += 1 }
    }

    func incrementLatestFrameReplacements() {
        lock.withLock { metrics.latestFrameReplacements += 1 }
    }

    func incrementWriterNotReadyVideo() {
        lock.withLock { metrics.writerNotReadyVideo += 1 }
    }

    func addAudioSamplesDropped(_ count: Int) {
        guard count > 0 else { return }
        lock.withLock { metrics.audioSamplesDropped += count }
    }

    func recordRenderTime(_ milliseconds: Double) {
        lock.withLock {
            metrics.renderTimesMs.append(milliseconds)
            if metrics.renderTimesMs.count > 300 {
                metrics.renderTimesMs.removeFirst(metrics.renderTimesMs.count - 300)
            }
        }
    }

    func recordAppendTime(_ milliseconds: Double) {
        lock.withLock {
            metrics.appendTimesMs.append(milliseconds)
            if metrics.appendTimesMs.count > 300 {
                metrics.appendTimesMs.removeFirst(metrics.appendTimesMs.count - 300)
            }
        }
    }

    func setAudioBufferedMilliseconds(system: Double? = nil, microphone: Double? = nil) {
        lock.withLock {
            if let system {
                metrics.audioBufferedMsSystem = system
            }
            if let microphone {
                metrics.audioBufferedMsMicrophone = microphone
            }
        }
    }
}

extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
