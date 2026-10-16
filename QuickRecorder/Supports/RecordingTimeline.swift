import CoreMedia

/// All tracks share this offset so a pause removes the same interval from video and audio.
enum RecordingTimeline {
    static func resumedOffset(previous: CMTime, lastEnd: CMTime?, next: CMTime) -> CMTime {
        let previous = previous.isNumeric ? previous : .zero
        guard let lastEnd, lastEnd.isNumeric, next.isNumeric else { return previous }
        let gap = CMTimeSubtract(CMTimeSubtract(next, previous), lastEnd)
        return gap > .zero ? CMTimeAdd(previous, gap) : previous
    }

    static func retime(_ sample: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        guard offset.isNumeric else { return nil }
        if offset == .zero { return sample }
        var count = 0
        guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr,
              count > 0 else { return nil }
        var timing = Array(repeating: CMSampleTimingInfo(), count: count)
        guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: count, arrayToFill: &timing, entriesNeededOut: nil) == noErr else { return nil }
        for i in timing.indices {
            if timing[i].presentationTimeStamp.isNumeric { timing[i].presentationTimeStamp = CMTimeSubtract(timing[i].presentationTimeStamp, offset) }
            if timing[i].decodeTimeStamp.isNumeric { timing[i].decodeTimeStamp = CMTimeSubtract(timing[i].decodeTimeStamp, offset) }
        }
        var output: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sample,
            sampleTimingEntryCount: count, sampleTimingArray: &timing, sampleBufferOut: &output) == noErr else { return nil }
        return output
    }
}
