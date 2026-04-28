@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
@preconcurrency import ScreenCaptureKit

struct CaptureDisplay: Sendable, Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum ScreenCaptureServiceError: LocalizedError {
    case noDisplaysAvailable
    case selectedDisplayUnavailable
    case pixelBufferMissing
    case streamStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDisplaysAvailable:
            "No displays are available to record."
        case .selectedDisplayUnavailable:
            "The selected display is no longer available."
        case .pixelBufferMissing:
            "ScreenCaptureKit produced a complete frame without an image buffer."
        case .streamStartFailed(let message):
            "Unable to start screen capture: \(message)"
        }
    }
}

final class ScreenCaptureService: NSObject, @unchecked Sendable {
    let videoCallbackQueue = DispatchQueue(label: "com.demolens.capture.screen")
    let audioCallbackQueue = DispatchQueue(label: "com.demolens.capture.system-audio")

    private let mailbox: LatestVideoFrameMailbox
    private let clock: RecordingSessionClock
    private let renderPipeline: FrameRenderPipeline
    private let writer: VideoWriter
    private let metrics: RecordingMetricsStore
    private var stream: SCStream?
    private var onError: (@Sendable (Error) -> Void)?

    init(
        mailbox: LatestVideoFrameMailbox,
        clock: RecordingSessionClock,
        renderPipeline: FrameRenderPipeline,
        writer: VideoWriter,
        metrics: RecordingMetricsStore,
        onError: (@Sendable (Error) -> Void)? = nil
    ) {
        self.mailbox = mailbox
        self.clock = clock
        self.renderPipeline = renderPipeline
        self.writer = writer
        self.metrics = metrics
        self.onError = onError
    }

    static func availableDisplays() async throws -> [CaptureDisplay] {
        let content = try await SCShareableContent.current
        return content.displays.map { display in
            CaptureDisplay(
                id: display.displayID,
                name: Self.displayName(for: display.displayID),
                pixelWidth: max(1, CGDisplayPixelsWide(display.displayID)),
                pixelHeight: max(1, CGDisplayPixelsHigh(display.displayID))
            )
        }
    }

    static func firstDisplay(matching displayID: CGDirectDisplayID? = nil) async throws -> SCDisplay {
        let content = try await SCShareableContent.current
        guard !content.displays.isEmpty else {
            throw ScreenCaptureServiceError.noDisplaysAvailable
        }
        if let displayID, let selected = content.displays.first(where: { $0.displayID == displayID }) {
            return selected
        }
        if let mainDisplayID = CGMainDisplayID() as CGDirectDisplayID?,
           let main = content.displays.first(where: { $0.displayID == mainDisplayID }) {
            return main
        }
        return content.displays[0]
    }

    static func displayName(for displayID: CGDirectDisplayID) -> String {
        if displayID == CGMainDisplayID() {
            return "Main display"
        }
        return "Display \(displayID)"
    }

    func start(display: SCDisplay, excludedWindows: [SCWindow] = []) async throws {
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, CGDisplayPixelsWide(display.displayID))
        configuration.height = max(1, CGDisplayPixelsHigh(display.displayID))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.queueDepth = 8
        configuration.showsCursor = true
        configuration.capturesAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = false
        configuration.scalesToFit = false
        configuration.preservesAspectRatio = true

        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoCallbackQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioCallbackQueue)
        self.stream = stream

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: ScreenCaptureServiceError.streamStartFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func stop() async {
        guard let stream else { return }
        await withCheckedContinuation { continuation in
            stream.stopCapture { _ in
                continuation.resume()
            }
        }
        self.stream = nil
    }

    private func handleVideo(_ sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.isValid else { return }
        guard let status = frameStatus(from: sampleBuffer) else { return }

        switch status {
        case .complete:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                onError?(ScreenCaptureServiceError.pixelBufferMissing)
                return
            }
            let sourcePTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard sourcePTS.isValid else { return }
            clock.establishEpochIfNeeded(sourcePTS)
            let frame = CapturedVideoFrame(
                sampleBuffer: sampleBuffer,
                pixelBuffer: pixelBuffer,
                sourcePresentationTime: sourcePTS
            )
            if mailbox.store(frame) {
                metrics.incrementLatestFrameReplacements()
            }
            renderPipeline.signalFrameAvailable()
        case .idle:
            return
        case .blank, .suspended, .started, .stopped:
            return
        @unknown default:
            return
        }
    }

    private func handleSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.isValid else { return }
        let sourcePTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard sourcePTS.isValid, let rebasedPTS = clock.rebase(sourcePTS) else { return }
        guard let rebased = sampleBuffer.copyWithPresentationTime(rebasedPTS) else { return }
        writer.appendSystemAudio(rebased)
    }

    private func frameStatus(from sampleBuffer: CMSampleBuffer) -> SCFrameStatus? {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let first = attachments.first,
            let rawStatus = first[SCStreamFrameInfo.status] as? Int
        else {
            return nil
        }
        return SCFrameStatus(rawValue: rawStatus)
    }
}

extension ScreenCaptureService: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            handleVideo(sampleBuffer)
        case .audio:
            handleSystemAudio(sampleBuffer)
        case .microphone:
            return
        @unknown default:
            return
        }
    }
}

extension ScreenCaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onError?(error)
    }
}
