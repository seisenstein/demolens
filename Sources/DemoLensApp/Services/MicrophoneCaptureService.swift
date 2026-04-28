@preconcurrency import AVFoundation
import CoreMedia
import Foundation

enum MicrophoneCaptureServiceError: LocalizedError {
    case noInputFormat
    case converterUnavailable
    case missingHostTime
    case conversionFailed(String)
    case sampleBufferCreationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noInputFormat:
            "No microphone input format is available."
        case .converterUnavailable:
            "Unable to create a microphone audio converter."
        case .missingHostTime:
            "The microphone callback did not include a usable host-time timestamp."
        case .conversionFailed(let message):
            "Unable to convert microphone audio: \(message)"
        case .sampleBufferCreationFailed(let status):
            "Unable to create a microphone sample buffer (\(status))."
        }
    }
}

final class MicrophoneCaptureService: @unchecked Sendable {
    let micCallbackQueue = DispatchQueue(label: "com.demolens.capture.microphone")

    private let engine = AVAudioEngine()
    private let clock: RecordingSessionClock
    private let writer: VideoWriter
    private let onError: (@Sendable (Error) -> Void)?
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var isRunning = false

    init(
        clock: RecordingSessionClock,
        writer: VideoWriter,
        onError: (@Sendable (Error) -> Void)? = nil
    ) {
        self.clock = clock
        self.writer = writer
        self.onError = onError
    }

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw MicrophoneCaptureServiceError.noInputFormat
        }

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        ) else {
            throw MicrophoneCaptureServiceError.noInputFormat
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw MicrophoneCaptureServiceError.converterUnavailable
        }

        self.outputFormat = outputFormat
        self.converter = converter

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, time in
            guard let self else { return }
            guard time.isHostTimeValid else {
                self.onError?(MicrophoneCaptureServiceError.missingHostTime)
                return
            }
            guard let copiedBuffer = Self.copyPCMBuffer(buffer) else { return }
            let payload = MicrophoneBufferPayload(buffer: copiedBuffer, hostTime: time.hostTime)
            self.micCallbackQueue.async { [weak self] in
                self?.process(payload)
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func process(_ payload: MicrophoneBufferPayload) {
        let sourcePTS = CMClockMakeHostTimeFromSystemUnits(payload.hostTime)
        guard let rebasedPTS = clock.rebase(sourcePTS) else { return }

        do {
            let normalized = try normalize(payload.buffer)
            guard let sampleBuffer = try makeSampleBuffer(from: normalized, presentationTime: rebasedPTS) else {
                return
            }
            writer.appendMicrophoneAudio(sampleBuffer)
        } catch {
            onError?(error)
        }
    }

    private func normalize(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let outputFormat, let converter else {
            throw MicrophoneCaptureServiceError.converterUnavailable
        }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(max(1, Double(buffer.frameLength) * ratio + 16))
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity) else {
            throw MicrophoneCaptureServiceError.noInputFormat
        }

        var providedInput = false
        var conversionError: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if providedInput {
                status.pointee = .noDataNow
                return nil
            }
            providedInput = true
            status.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &conversionError, withInputFrom: inputBlock)
        if let conversionError {
            throw MicrophoneCaptureServiceError.conversionFailed(conversionError.localizedDescription)
        }
        return outputBuffer
    }

    private func makeSampleBuffer(
        from buffer: AVAudioPCMBuffer,
        presentationTime: CMTime
    ) throws -> CMSampleBuffer? {
        guard buffer.frameLength > 0 else { return nil }

        var formatDescription: CMAudioFormatDescription?
        var status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: buffer.format.streamDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr, let formatDescription else {
            throw MicrophoneCaptureServiceError.sampleBufferCreationFailed(status)
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(buffer.format.sampleRate)),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else {
            throw MicrophoneCaptureServiceError.sampleBufferCreationFailed(status)
        }

        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList
        )
        guard status == noErr else {
            throw MicrophoneCaptureServiceError.sampleBufferCreationFailed(status)
        }
        return sampleBuffer
    }

    private static func copyPCMBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        copy.frameLength = buffer.frameLength

        let sourceBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<sourceBuffers.count {
            guard
                let source = sourceBuffers[index].mData,
                let destination = destinationBuffers[index].mData
            else { continue }

            let byteCount = Int(sourceBuffers[index].mDataByteSize)
            memcpy(destination, source, byteCount)
            destinationBuffers[index].mDataByteSize = sourceBuffers[index].mDataByteSize
        }
        return copy
    }
}

private final class MicrophoneBufferPayload: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let hostTime: UInt64

    init(buffer: AVAudioPCMBuffer, hostTime: UInt64) {
        self.buffer = buffer
        self.hostTime = hostTime
    }
}
