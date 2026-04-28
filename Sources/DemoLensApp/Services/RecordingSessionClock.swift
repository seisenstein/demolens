import CoreMedia
import Foundation

final class RecordingSessionClock: @unchecked Sendable {
    private let lock = NSLock()
    private var epochStorage: CMTime?

    var epoch: CMTime? {
        lock.withLock { epochStorage }
    }

    @discardableResult
    func establishEpochIfNeeded(_ timestamp: CMTime) -> CMTime {
        lock.withLock {
            if let epochStorage {
                return epochStorage
            }
            epochStorage = timestamp
            return timestamp
        }
    }

    func rebase(_ timestamp: CMTime) -> CMTime? {
        lock.withLock {
            guard let epochStorage else { return nil }
            let rebased = CMTimeSubtract(timestamp, epochStorage)
            guard rebased.isValid, rebased >= .zero else { return nil }
            return rebased
        }
    }

    func reset() {
        lock.withLock {
            epochStorage = nil
        }
    }
}
