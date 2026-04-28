@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

enum RecordingLifecycleState: Equatable, Sendable {
    case idle
    case preparing
    case countdown
    case recording
    case paused
    case stopping
    case finished(URL)
    case failed(String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .idle:
            "Ready"
        case .preparing:
            "Preparing"
        case .countdown:
            "Starting"
        case .recording:
            "Recording"
        case .paused:
            "Paused"
        case .stopping:
            "Stopping"
        case .finished:
            "Finished"
        case .failed:
            "Failed"
        }
    }
}

final class RecordingStateUpdates: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<RecordingLifecycleState>.Continuation] = [:]

    func stream() -> AsyncStream<RecordingLifecycleState> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                continuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock {
                    self?.continuations[id] = nil
                }
            }
        }
    }

    func yield(_ state: RecordingLifecycleState) {
        let active = lock.withLock { Array(continuations.values) }
        active.forEach { $0.yield(state) }
    }
}

actor RecordingCoordinator {
    nonisolated let updates = RecordingStateUpdates()

    private var state: RecordingLifecycleState = .idle
    private var session: RecordingSession?

    func startRecording(displayID: CGDirectDisplayID? = nil, includeMicrophone: Bool = true) async {
        guard canStart(from: state) else { return }
        await transition(.preparing)

        do {
            let display = try await ScreenCaptureService.firstDisplay(matching: displayID)
            let pixelWidth = max(1, CGDisplayPixelsWide(display.displayID))
            let pixelHeight = max(1, CGDisplayPixelsHigh(display.displayID))
            let outputURL = try FileManager.default.makeDemoLensRecordingURL()
            let metrics = RecordingMetricsStore()
            let clock = RecordingSessionClock()
            let mailbox = LatestVideoFrameMailbox()
            let writer = try VideoWriter(
                outputURL: outputURL,
                videoSize: CGSize(width: pixelWidth, height: pixelHeight),
                metrics: metrics
            )
            let renderPipeline = try FrameRenderPipeline(
                width: pixelWidth,
                height: pixelHeight,
                mailbox: mailbox,
                clock: clock,
                writer: writer,
                metrics: metrics
            )

            let errorSink: @Sendable (Error) -> Void = { [weak updates] error in
                updates?.yield(.failed(error.localizedDescription))
            }
            let screenCapture = ScreenCaptureService(
                mailbox: mailbox,
                clock: clock,
                renderPipeline: renderPipeline,
                writer: writer,
                metrics: metrics,
                onError: errorSink
            )
            let microphoneCapture = MicrophoneCaptureService(
                clock: clock,
                writer: writer,
                onError: errorSink
            )

            session = RecordingSession(
                displayID: display.displayID,
                displayName: ScreenCaptureService.displayName(for: display.displayID),
                outputURL: outputURL,
                clock: clock,
                mailbox: mailbox,
                writer: writer,
                screenCapture: screenCapture,
                microphoneCapture: microphoneCapture,
                metrics: metrics
            )

            try await screenCapture.start(display: display)

            if includeMicrophone, AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                do {
                    try microphoneCapture.start()
                } catch {
                    // Graceful degradation: system audio continues when microphone capture is unavailable.
                }
            }

            await transition(.countdown)
            await transition(.recording)
        } catch {
            await fail(error.localizedDescription)
        }
    }

    func stopRecording() async -> URL? {
        guard let session else { return nil }
        await transition(.stopping)

        session.microphoneCapture.stop()
        await session.screenCapture.stop()

        let finalPTS: CMTime?
        if let now = session.clock.rebase(CMClockGetTime(CMClockGetHostTimeClock())) {
            finalPTS = now
        } else {
            finalPTS = nil
        }

        do {
            let url = try await session.writer.finish(finalPresentationTime: finalPTS)
            self.session = nil
            await transition(.finished(url))
            return url
        } catch {
            await session.writer.cancel()
            self.session = nil
            await fail(error.localizedDescription)
            return nil
        }
    }

    func metricsSnapshot() -> RecordingMetrics? {
        session?.metrics.snapshot()
    }

    func activeDisplayName() -> String {
        session?.displayName ?? "Main display"
    }

    private func canStart(from state: RecordingLifecycleState) -> Bool {
        switch state {
        case .idle, .finished, .failed:
            true
        case .preparing, .countdown, .recording, .paused, .stopping:
            false
        }
    }

    private func transition(_ newState: RecordingLifecycleState) async {
        state = newState
        updates.yield(newState)
    }

    private func fail(_ message: String) async {
        if let session {
            session.microphoneCapture.stop()
            await session.screenCapture.stop()
            await session.writer.cancel()
        }
        session = nil
        await transition(.failed(message))
    }
}

private struct RecordingSession: Sendable {
    let displayID: CGDirectDisplayID
    let displayName: String
    let outputURL: URL
    let clock: RecordingSessionClock
    let mailbox: LatestVideoFrameMailbox
    let writer: VideoWriter
    let screenCapture: ScreenCaptureService
    let microphoneCapture: MicrophoneCaptureService
    let metrics: RecordingMetricsStore
}
