import Foundation

final class WriterReadinessSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var videoReadyStorage = true

    var videoReady: Bool {
        lock.withLock { videoReadyStorage }
    }

    func setVideoReady(_ ready: Bool) {
        lock.withLock {
            videoReadyStorage = ready
        }
    }
}
