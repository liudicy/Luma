import CoreMedia
import Foundation

@main
struct RecordingTimelineTests {
    static func time(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 48000) }
    static func main() {
        let first = RecordingTimeline.resumedOffset(previous: .zero, lastEnd: time(10), next: time(15))
        precondition(first == time(5), "First pause must remove five seconds")
        let second = RecordingTimeline.resumedOffset(previous: first, lastEnd: time(12), next: time(20))
        precondition(second == time(8), "Repeated pauses must accumulate")
        precondition(RecordingTimeline.resumedOffset(previous: first, lastEnd: nil, next: time(20)) == first)
        precondition(RecordingTimeline.resumedOffset(previous: .invalid, lastEnd: time(10), next: time(15)) == first)
        precondition(RecordingTimeline.resumedOffset(previous: first, lastEnd: time(20), next: time(10)) == first, "Out-of-order samples cannot reduce the offset")

        for mediaType in [kCMMediaType_Video, kCMMediaType_Audio] {
            var format: CMFormatDescription?
            precondition(CMFormatDescriptionCreate(allocator: kCFAllocatorDefault, mediaType: mediaType,
                mediaSubType: 0, extensions: nil, formatDescriptionOut: &format) == noErr)
            var timing = CMSampleTimingInfo(duration: time(1.0 / 60), presentationTimeStamp: time(20), decodeTimeStamp: .invalid)
            var sample: CMSampleBuffer?
            precondition(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                makeDataReadyCallback: nil, refcon: nil, formatDescription: format, sampleCount: 1,
                sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0,
                sampleSizeArray: nil, sampleBufferOut: &sample) == noErr)
            let adjusted = RecordingTimeline.retime(sample!, by: second)!
            precondition(CMSampleBufferGetPresentationTimeStamp(adjusted) == time(12), "Audio/video must resume on the same timeline")
            precondition(CMSampleBufferGetDecodeTimeStamp(adjusted) == .invalid)
            precondition(CMSampleBufferGetDuration(adjusted) == timing.duration)
            precondition(CMSampleBufferGetPresentationTimeStamp(sample!) == time(20), "Retiming must preserve the source")
            precondition(RecordingTimeline.retime(sample!, by: .invalid) == nil)
            precondition(RecordingTimeline.retime(sample!, by: .zero) === sample!)
        }
        print("PASS: repeated pauses, invalid/missing timestamps, out-of-order samples, shared audio/video timing, unchanged duration and source buffers")
    }
}
