@preconcurrency import AVFoundation
import CoreMedia
import Foundation

enum RecordingAudioTrack: Sendable {
    case system
    case microphone
}

final class BoundedAudioBuffer: @unchecked Sendable {
    private var samples: [CMSampleBuffer] = []
    private var bufferedDuration = CMTime.zero
    private let maximumDuration: CMTime

    init(maximumDuration: CMTime = CMTime(seconds: 0.1, preferredTimescale: 48_000)) {
        self.maximumDuration = maximumDuration
    }

    var bufferedMilliseconds: Double {
        max(0, bufferedDuration.seconds * 1_000)
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) -> Int {
        samples.append(sampleBuffer)
        bufferedDuration = CMTimeAdd(bufferedDuration, Self.duration(of: sampleBuffer))

        var droppedSamples = 0
        while bufferedDuration > maximumDuration, !samples.isEmpty {
            let dropped = samples.removeFirst()
            bufferedDuration = CMTimeSubtract(bufferedDuration, Self.duration(of: dropped))
            droppedSamples += CMSampleBufferGetNumSamples(dropped)
        }
        return droppedSamples
    }

    func popFirst() -> CMSampleBuffer? {
        guard !samples.isEmpty else { return nil }
        let sample = samples.removeFirst()
        bufferedDuration = CMTimeSubtract(bufferedDuration, Self.duration(of: sample))
        return sample
    }

    func peekFirst() -> CMSampleBuffer? {
        samples.first
    }

    func removeAll() {
        samples.removeAll()
        bufferedDuration = .zero
    }

    private static func duration(of sampleBuffer: CMSampleBuffer) -> CMTime {
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        if duration.isValid, duration > .zero {
            return duration
        }

        let sampleDuration = sampleBuffer.firstSampleDuration
        let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
        if sampleDuration.isValid, sampleDuration > .zero, sampleCount > 0 {
            return CMTimeMultiply(sampleDuration, multiplier: Int32(sampleCount))
        }

        return CMTime(seconds: 0, preferredTimescale: 48_000)
    }
}

extension CMSampleBuffer {
    func copyWithPresentationTime(_ presentationTime: CMTime) -> CMSampleBuffer? {
        let sampleDuration = firstSampleDuration
        let duration = sampleDuration.isValid && sampleDuration > .zero
            ? sampleDuration
            : CMTime(value: 1, timescale: 48_000)
        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var output: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &output
        )
        guard status == noErr else { return nil }
        return output
    }
}

private extension CMSampleBuffer {
    var firstSampleDuration: CMTime {
        var timing = CMSampleTimingInfo()
        let status = CMSampleBufferGetSampleTimingInfo(self, at: 0, timingInfoOut: &timing)
        guard status == noErr else { return .invalid }
        return timing.duration
    }
}
