@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

enum FrameRenderPipelineError: LocalizedError {
    case pixelBufferPoolCreationFailed
    case pixelBufferPoolPrewarmFailed

    var errorDescription: String? {
        switch self {
        case .pixelBufferPoolCreationFailed:
            "Unable to create the video pixel buffer pool."
        case .pixelBufferPoolPrewarmFailed:
            "Unable to prewarm the video pixel buffer pool."
        }
    }
}

final class FrameRenderPipeline: @unchecked Sendable {
    private let renderQueue = DispatchQueue(label: "com.demolens.render.video")
    private let mailbox: LatestVideoFrameMailbox
    private let clock: RecordingSessionClock
    private let writer: VideoWriter
    private let readiness: WriterReadinessSnapshot
    private let metrics: RecordingMetricsStore
    private let pixelBufferPool: CVPixelBufferPool

    init(
        width: Int,
        height: Int,
        mailbox: LatestVideoFrameMailbox,
        clock: RecordingSessionClock,
        writer: VideoWriter,
        metrics: RecordingMetricsStore
    ) throws {
        self.mailbox = mailbox
        self.clock = clock
        self.writer = writer
        self.readiness = writer.readiness
        self.metrics = metrics
        self.pixelBufferPool = try Self.makePixelBufferPool(width: width, height: height)
        try Self.prewarm(pixelBufferPool)
    }

    func signalFrameAvailable() {
        renderQueue.async { [weak self] in
            self?.renderLatestFrame()
        }
    }

    private func renderLatestFrame() {
        guard let frame = mailbox.takeLatest() else { return }
        guard readiness.videoReady else {
            metrics.incrementFramesDropped()
            metrics.incrementWriterNotReadyVideo()
            return
        }
        guard let rebasedPTS = clock.rebase(frame.sourcePresentationTime) else { return }

        let start = CFAbsoluteTimeGetCurrent()
        writer.appendVideo(pixelBuffer: frame.pixelBuffer, presentationTime: rebasedPTS)
        metrics.recordRenderTime((CFAbsoluteTimeGetCurrent() - start) * 1_000)
    }

    private static func makePixelBufferPool(width: Int, height: Int) throws -> CVPixelBufferPool {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        let pixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelAttributes as CFDictionary,
            &pool
        )
        guard status == kCVReturnSuccess, let pool else {
            throw FrameRenderPipelineError.pixelBufferPoolCreationFailed
        }
        return pool
    }

    private static func prewarm(_ pool: CVPixelBufferPool) throws {
        var buffers: [CVPixelBuffer] = []
        for _ in 0..<3 {
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            guard status == kCVReturnSuccess, let buffer else {
                throw FrameRenderPipelineError.pixelBufferPoolPrewarmFailed
            }
            buffers.append(buffer)
        }
    }
}
