@preconcurrency import AVFoundation
import CoreVideo
import Foundation

struct CapturedVideoFrame: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
    let pixelBuffer: CVPixelBuffer
    let sourcePresentationTime: CMTime
}

final class LatestVideoFrameMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var latestFrame: CapturedVideoFrame?
    private var lastValidFrame: CapturedVideoFrame?

    @discardableResult
    func store(_ frame: CapturedVideoFrame) -> Bool {
        lock.withLock {
            let replaced = latestFrame != nil
            latestFrame = frame
            lastValidFrame = frame
            return replaced
        }
    }

    func takeLatest() -> CapturedVideoFrame? {
        lock.withLock {
            let frame = latestFrame
            latestFrame = nil
            return frame
        }
    }

    func currentLastValidFrame() -> CapturedVideoFrame? {
        lock.withLock { lastValidFrame }
    }

    func clear() {
        lock.withLock {
            latestFrame = nil
            lastValidFrame = nil
        }
    }
}
