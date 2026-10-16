# Luma repair and verification record

Date: 2026-10-16. This record supersedes the compatibility assumptions in the earlier macOS 27 design/plan documents under `docs/superpowers/`.

## Delivered behavior

- ScreenCaptureKit content discovery is asynchronous, publishes results on the main queue, coalesces overlapping requests, and never retries a denial automatically. Launch performs no screen-content or permission query; discovery begins with the user's recording/selection action. First-use system audio and hotkeys enter the same discovery flow. Denial leaves the application running with a Settings link.
- Screen recording access belongs to a code-signing identity, not just the name shown in System Settings. On this machine, TCC logged `Failed to match existing code requirement` when the unsigned Debug app was launched against the signed app's stored permission. The running Debug executable had `Signature=adhoc`, `TeamIdentifier=not set` and a cdhash-only requirement. The signed app uses bundle ID `com.liudicy.QuickRecorder`, team `P8XVY8TTCG` and an Apple Development certificate requirement. No TCC database was edited or reset during this repair.
- The build helper passes the usable certificate fingerprint explicitly to Xcode. The recommended testing artifact is the signed Release app, installed at `/Applications/Luma.app`. Both the current local Debug and Release products were signed with the same identity. Future builds with `CODE_SIGNING_ALLOWED=NO` still do not provide a persistent permission identity.
- Native NSStatusItem/NSMenu controls replace the menu bar's SwiftUI hosting view. Controls are always available through the menu, without hovering. Removed the empty parent tap gesture and the process-wide private glass-view method replacement. A floating controller can also be opened explicitly through the recording menu.
- Capture output callbacks share a serial queue. Stop is guarded against reentry, waits for capture and queued callbacks, finishes writers asynchronously, closes audio containers, and waits for conversion/mixing before releasing state. Quitting during a recording waits for finalization. Device recording cleanup uses its output delegate completion.
- Pause offsets start at a valid zero CMTime, accumulate across pauses, and apply consistently to video, system audio and microphone tracks. Timing copies use the actual CoreMedia timing-entry count. Elapsed-time resume no longer subtracts an extra second.
- File creation, audio-engine startup and capture errors surface as errors rather than forced-try crashes. Stop before the first frame cancels the unstarted writer. A hardware encoder warning no longer dispatches synchronously back onto its own main thread.
- Main-panel reopening identifies the actual EscPanel, avoiding SwiftUI's hidden empty document windows. Window cleanup correctly handles an empty exception string.
- H.265 onboarding is skipped if H.265 is already selected. Both accepting H.265 and choosing “Don't remind me again” consume the existing tip ID permanently.
- The product is Luma; bundle ID, preferences domain, source target and Swift module remain stable. The Swift module name is explicitly retained for AppleScript command classes. The original purple recording-ring icon was redrawn with reproducible vector code. README files were rewritten, upstream links retained, and LICENSE/NOTICE/dependency notices are bundled in the app.

## Checks completed

Environment: macOS 27.0.1, Apple silicon, Xcode 27.0 (27A266a), Swift 5 language mode.

| Check | Result |
| --- | --- |
| Debug compile | Passed, including a build signed with the same Apple Development identity |
| Release build through signing helper | Passed; universal arm64/x86_64 artifact produced |
| `codesign --verify --strict` | Passed for signed Debug and Release products and installed app |
| LICENSE, NOTICE and dependency texts in app Resources | Confirmed |
| Project plist and `git diff --check` | Passed |
| `./Scripts/test_recording_timeline.sh` | Passed; repeated pauses, missing/invalid timestamps, out-of-order input, unchanged source/duration, shared audio/video retiming |
| Installed signed app launch | Passed; Luma name/icon shown, no H.265 prompt with persisted H.265 selection |
| Screen selection with existing screen permission | Passed; display preview loaded without permission prompt |
| Native menu pause and resume | Passed through actual accessibility actions; timer froze at 00:14 while paused, menu changed to Resume, timer advanced after resume |
| Native menu stop and save | Passed; recording status item disappeared and completion preview appeared |
| Saved media inspection | ffprobe reported HEVC video 25.750 s, AAC audio 25.72325 s, both start at 0; 30,445,189-byte MP4 |

The recording/menu smoke test preceded the final main-panel refinement. A later UI observation reported no shareable display, so the last restart could not be visually rechecked in that state; final compile/signature checks are recorded separately.

The media inspection establishes that the recorded file is readable and contains aligned track boundaries. It does not establish perceptual lip sync for every microphone/device configuration. The test recording remains in the user's configured output folder; it is not committed to this repository.

## Remaining acceptance matrix

These scenarios require additional manual/device coverage and are not claimed as passed:

- macOS 12.3–15 and 26 runtime checks; Intel hardware runtime (the x86_64 build is compile-verified).
- Fresh permission grant, denial, revoke, and certificate replacement across clean installations. Existing signed authorization was exercised on the current Mac; it was not reset to simulate a new user.
- All window/application/area combinations, multi-display changes, fullscreen/notched menu bar behavior and mouse overlays.
- External microphones, acoustic echo cancellation, camera and mobile device recording, unplug/disconnect during capture, and Presenter Overlay.
- Audio-only/QMA mixing and MP3 export, long recordings, disk-full errors, rapid start/stop, and quit during slow export.
- Distribution signing, notarization and published updater feed verification.

The repository retains existing Swift concurrency/deprecation warnings in selectors and the audio player. This work does not claim a Swift 6 migration, warning-free build, or exhaustive runtime coverage.

## Repository presentation refresh

On 2026-10-16, the signed 1.7.1 app was relaunched and the main panel and settings were visually inspected again. Fresh launcher, recording-settings and paused native-menu screenshots are checked into `img/screenshots/`; the earlier no-display limitation no longer applied. Settings now use Luma in all three branding labels, including the English fallback. English and Chinese READMEs lead with Luma, with upstream provenance and license references confined to the open-source notice. Original screenshots were replaced; license texts and original source copyright notices remain intact. A system-audio-only session was started, paused and stopped to capture the native menu.
