@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

enum VideoWriterError: LocalizedError {
    case cannotAddVideoInput
    case cannotAddSystemAudioInput
    case cannotAddMicrophoneAudioInput
    case startFailed
    case appendFailed(String)
    case finishFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotAddVideoInput:
            "Unable to add the video input to the asset writer."
        case .cannotAddSystemAudioInput:
            "Unable to add the system audio input to the asset writer."
        case .cannotAddMicrophoneAudioInput:
            "Unable to add the microphone audio input to the asset writer."
        case .startFailed:
            "Unable to start the asset writer."
        case .appendFailed(let message):
            "Unable to append media: \(message)"
        case .finishFailed(let message):
            "Unable to finish the movie: \(message)"
        }
    }
}

actor VideoWriter {
    let readiness: WriterReadinessSnapshot
    private let core: VideoWriterCore

    init(outputURL: URL, videoSize: CGSize, metrics: RecordingMetricsStore) throws {
        let readiness = WriterReadinessSnapshot()
        self.readiness = readiness
        self.core = try VideoWriterCore(
            outputURL: outputURL,
            videoSize: videoSize,
            readiness: readiness,
            metrics: metrics
        )
    }

    var outputURL: URL {
        core.outputURL
    }

    nonisolated func appendVideo(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        core.appendVideo(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
    }

    nonisolated func appendSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        core.appendAudio(sampleBuffer, track: .system)
    }

    nonisolated func appendMicrophoneAudio(_ sampleBuffer: CMSampleBuffer) {
        core.appendAudio(sampleBuffer, track: .microphone)
    }

    func finish(finalPresentationTime: CMTime?) async throws -> URL {
        try await core.finish(finalPresentationTime: finalPresentationTime)
    }

    func cancel() async {
        await core.cancel()
    }
}

private final class VideoWriterCore: @unchecked Sendable {
    let outputURL: URL

    private let writerQueue = DispatchQueue(label: "com.demolens.writer")
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private let systemAudioInput: AVAssetWriterInput
    private let microphoneAudioInput: AVAssetWriterInput
    private let systemAudioBuffer = BoundedAudioBuffer()
    private let microphoneAudioBuffer = BoundedAudioBuffer()
    private let readiness: WriterReadinessSnapshot
    private let metrics: RecordingMetricsStore

    private var didStartWriting = false
    private var didFinish = false
    private var writerError: Error?
    private var lastVideoPixelBuffer: CVPixelBuffer?
    private var lastVideoPresentationTime: CMTime?

    init(
        outputURL: URL,
        videoSize: CGSize,
        readiness: WriterReadinessSnapshot,
        metrics: RecordingMetricsStore
    ) throws {
        self.outputURL = outputURL
        self.readiness = readiness
        self.metrics = metrics

        try? FileManager.default.removeItem(at: outputURL)
        writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        writer.shouldOptimizeForNetworkUse = false

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(8_000_000, Int(videoSize.width * videoSize.height * 4)),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourceAttributes
        )

        let systemAudioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000
        ]
        systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: systemAudioSettings)
        systemAudioInput.expectsMediaDataInRealTime = true

        let microphoneAudioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000
        ]
        microphoneAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: microphoneAudioSettings)
        microphoneAudioInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(videoInput) else { throw VideoWriterError.cannotAddVideoInput }
        writer.add(videoInput)

        guard writer.canAdd(systemAudioInput) else { throw VideoWriterError.cannotAddSystemAudioInput }
        writer.add(systemAudioInput)

        guard writer.canAdd(microphoneAudioInput) else { throw VideoWriterError.cannotAddMicrophoneAudioInput }
        writer.add(microphoneAudioInput)

        readiness.setVideoReady(true)
    }

    func appendVideo(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        let payload = VideoAppendPayload(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
        writerQueue.async { [weak self] in
            guard let self, !self.didFinish, self.writerError == nil else { return }
            let start = CFAbsoluteTimeGetCurrent()
            do {
                try self.ensureStarted()
                guard self.videoInput.isReadyForMoreMediaData else {
                    self.readiness.setVideoReady(false)
                    self.metrics.incrementWriterNotReadyVideo()
                    self.metrics.incrementFramesDropped()
                    return
                }

                let appended = self.pixelBufferAdaptor.append(payload.pixelBuffer, withPresentationTime: payload.presentationTime)
                self.readiness.setVideoReady(self.videoInput.isReadyForMoreMediaData)
                guard appended else {
                    throw VideoWriterError.appendFailed(self.writer.error?.localizedDescription ?? "video append returned false")
                }

                self.lastVideoPixelBuffer = payload.pixelBuffer
                self.lastVideoPresentationTime = payload.presentationTime
                self.metrics.incrementFramesRendered()
                self.metrics.recordAppendTime((CFAbsoluteTimeGetCurrent() - start) * 1_000)
                self.drainAudioBuffers()
            } catch {
                self.fail(error)
            }
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, track: RecordingAudioTrack) {
        let payload = AudioAppendPayload(sampleBuffer: sampleBuffer, track: track)
        writerQueue.async { [weak self] in
            guard let self, !self.didFinish, self.writerError == nil else { return }
            do {
                try self.ensureStarted()
                switch payload.track {
                case .system:
                    let dropped = self.systemAudioBuffer.enqueue(payload.sampleBuffer)
                    self.metrics.addAudioSamplesDropped(dropped)
                    self.metrics.setAudioBufferedMilliseconds(system: self.systemAudioBuffer.bufferedMilliseconds)
                case .microphone:
                    let dropped = self.microphoneAudioBuffer.enqueue(payload.sampleBuffer)
                    self.metrics.addAudioSamplesDropped(dropped)
                    self.metrics.setAudioBufferedMilliseconds(microphone: self.microphoneAudioBuffer.bufferedMilliseconds)
                }
                self.drainAudioBuffers()
            } catch {
                self.fail(error)
            }
        }
    }

    func finish(finalPresentationTime: CMTime?) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            writerQueue.async { [weak self] in
                guard let self else { return }
                guard !self.didFinish else {
                    continuation.resume(returning: self.outputURL)
                    return
                }

                if let writerError = self.writerError {
                    self.didFinish = true
                    self.writer.cancelWriting()
                    continuation.resume(throwing: writerError)
                    return
                }

                do {
                    try self.ensureStarted()
                    self.appendFinalVideoFrameIfNeeded(finalPresentationTime)
                    self.drainAudioBuffers()
                    self.videoInput.markAsFinished()
                    self.systemAudioInput.markAsFinished()
                    self.microphoneAudioInput.markAsFinished()
                    self.didFinish = true
                    self.writer.finishWriting {
                        if let error = self.writer.error {
                            continuation.resume(throwing: VideoWriterError.finishFailed(error.localizedDescription))
                        } else {
                            continuation.resume(returning: self.outputURL)
                        }
                    }
                } catch {
                    self.didFinish = true
                    self.writer.cancelWriting()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cancel() async {
        await withCheckedContinuation { continuation in
            writerQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                self.didFinish = true
                self.writer.cancelWriting()
                continuation.resume()
            }
        }
    }

    private func ensureStarted() throws {
        guard !didStartWriting else { return }
        guard writer.startWriting() else {
            throw VideoWriterError.startFailed
        }
        writer.startSession(atSourceTime: .zero)
        didStartWriting = true
        readiness.setVideoReady(videoInput.isReadyForMoreMediaData)
    }

    private func drainAudioBuffers() {
        drainAudioBuffer(systemAudioBuffer, input: systemAudioInput, track: .system)
        drainAudioBuffer(microphoneAudioBuffer, input: microphoneAudioInput, track: .microphone)
        metrics.setAudioBufferedMilliseconds(
            system: systemAudioBuffer.bufferedMilliseconds,
            microphone: microphoneAudioBuffer.bufferedMilliseconds
        )
    }

    private func drainAudioBuffer(
        _ buffer: BoundedAudioBuffer,
        input: AVAssetWriterInput,
        track: RecordingAudioTrack
    ) {
        while input.isReadyForMoreMediaData, let sample = buffer.peekFirst() {
            let start = CFAbsoluteTimeGetCurrent()
            guard input.append(sample) else {
                fail(VideoWriterError.appendFailed(writer.error?.localizedDescription ?? "audio append returned false"))
                return
            }
            _ = buffer.popFirst()
            metrics.recordAppendTime((CFAbsoluteTimeGetCurrent() - start) * 1_000)
        }
    }

    private func appendFinalVideoFrameIfNeeded(_ finalPresentationTime: CMTime?) {
        guard
            let finalPresentationTime,
            let lastVideoPixelBuffer,
            let lastVideoPresentationTime,
            finalPresentationTime > lastVideoPresentationTime,
            videoInput.isReadyForMoreMediaData
        else { return }

        let appended = pixelBufferAdaptor.append(lastVideoPixelBuffer, withPresentationTime: finalPresentationTime)
        if appended {
            metrics.incrementFramesRendered()
            self.lastVideoPresentationTime = finalPresentationTime
        } else {
            metrics.incrementFramesDropped()
        }
    }

    private func fail(_ error: Error) {
        writerError = error
        readiness.setVideoReady(false)
    }
}

private final class VideoAppendPayload: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let presentationTime: CMTime

    init(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        self.pixelBuffer = pixelBuffer
        self.presentationTime = presentationTime
    }
}

private final class AudioAppendPayload: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
    let track: RecordingAudioTrack

    init(sampleBuffer: CMSampleBuffer, track: RecordingAudioTrack) {
        self.sampleBuffer = sampleBuffer
        self.track = track
    }
}
