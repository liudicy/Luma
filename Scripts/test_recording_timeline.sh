#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
TEST_OUT=$(mktemp -d)
trap 'rm -rf "$TEST_OUT"' EXIT
xcrun swiftc QuickRecorder/Supports/RecordingTimeline.swift Tests/RecordingTimelineTests.swift -o "$TEST_OUT/timeline-tests"
"$TEST_OUT/timeline-tests"
