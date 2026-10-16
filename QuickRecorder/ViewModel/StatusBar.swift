// Recording controls use AppKit's menu tracking, including while another app is active.
import SwiftUI

class PopoverState: ObservableObject {
    static let shared = PopoverState()
    @Published var isShowing = false
    @Published var isPaused = false
}

final class RecordingStatusController: NSObject, NSMenuDelegate {
    static let shared = RecordingStatusController()
    private var timer: Timer?
    private let menu = NSMenu()
    private var menuOpen = false
    private var controllerPinned = false

    func install() {
        menu.delegate = self
        menu.autoenablesItems = false
        statusBarItem.menu = menu
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        refresh()
    }

    func refresh() {
        guard let item = statusBarItem, let button = item.button else { return }
        let recording = SCContext.streamType != nil
        item.isVisible = recording || ud.bool(forKey: "showMenubar")
        button.image = NSImage(systemSymbolName: recording ? (SCContext.isPaused ? "pause.circle.fill" : "record.circle") : "record.circle", accessibilityDescription: "Luma")
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.title = recording ? " " + SCContext.getRecordingLength() : ""
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.toolTip = recording ? "Recording controls".local : "Luma"
        button.setAccessibilityLabel(recording ? "Luma · \(SCContext.getRecordingLength())" : "Luma")
        if !menuOpen { rebuildMenu() }

        if recording, !SCContext.isStopping, SCContext.autoStop > 0,
           SCContext.timePassed >= Double(SCContext.autoStop * 60) { stop(nil) }
        guard recording else { controllerPinned = false; controlPanel.orderOut(nil); return }
        // A native floating controller remains reachable in fullscreen or a crowded menu bar.
        let reachable = button.window?.occlusionState.contains(.visible) ?? false
        if (!reachable || controllerPinned), !controlPanel.isVisible, let screen = SCContext.getScreenWithMouse() {
            let size = NSSize(width: 240, height: 44)
            controlPanel.contentView = NSHostingView(rootView: StatusBarItem())
            controlPanel.setFrame(NSRect(x: screen.frame.midX - size.width / 2,
                y: screen.visibleFrame.maxY - size.height - 8, width: size.width, height: size.height), display: true)
            controlPanel.orderFrontRegardless()
        } else if reachable && !controllerPinned { controlPanel.orderOut(nil) }
    }

    func menuWillOpen(_ menu: NSMenu) { menuOpen = true; rebuildMenu() }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false; refresh() }

    private func add(_ title: String, _ action: Selector, enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        if SCContext.streamType != nil {
            add(SCContext.isStopping ? "Saving…".local : "Stop Recording".local, #selector(stop(_:)), enabled: !SCContext.isStopping)
            if SCContext.streamType != .idevice {
                add(SCContext.isPaused ? "Resume Recording".local : "Pause Recording".local,
                    #selector(pause(_:)), enabled: !SCContext.isStopping && SCContext.startTime != nil)
            }
            if SCContext.streamType != .systemaudio && SCContext.streamType != .idevice {
                add("Camera…".local, #selector(camera(_:)), enabled: !SCContext.isStopping)
                add("Save Current Frame".local, #selector(snapshot(_:)), enabled: !SCContext.isStopping)
            }
            add("Show Recording Controls".local, #selector(showController(_:)))
            menu.addItem(.separator())
        }
        add("Open Luma".local, #selector(open(_:)))
        add("Settings…".local, #selector(settings(_:)))
        menu.addItem(.separator())
        add("Quit Luma".local, #selector(quit(_:)))
    }

    @objc private func showController(_ sender: Any?) { controllerPinned = true; refresh() }
    @objc private func stop(_ sender: Any?) {
        if SCContext.streamType == .idevice { AVOutputClass.shared.stopRecording() }
        else { SCContext.stopRecording() }
    }
    @objc private func pause(_ sender: Any?) { SCContext.pauseRecording(); refresh() }
    @objc private func snapshot(_ sender: Any?) { SCContext.saveFrame = true }
    @objc private func open(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        _ = AppDelegate.shared.applicationShouldHandleReopen(NSApp, hasVisibleWindows: true)
    }
    @objc private func settings(_ sender: Any?) { AppDelegate.shared.openSettingPanel() }
    @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }
    @objc private func camera(_ sender: Any?) {
        AppDelegate.shared.createNewWindow(view: CameraPopoverView(closePopover: {
            NSApp.windows.first(where: { $0.title == "Camera".local })?.close()
        }), title: "Camera".local)
    }
}

// Floating fallback: no outer gesture, hover-only controls, or glass hit-test overrides.
struct StatusBarItem: View {
    @StateObject private var state = PopoverState.shared
    var body: some View {
        HStack(spacing: 12) {
            Button {
                if SCContext.streamType == .idevice { AVOutputClass.shared.stopRecording() }
                else { SCContext.stopRecording() }
            } label: { Image(systemName: "stop.circle.fill").foregroundStyle(.red) }
            .help("Stop Recording".local)
            if SCContext.streamType != .idevice {
                Button { SCContext.pauseRecording() } label: {
                    Image(systemName: state.isPaused ? "play.circle.fill" : "pause.circle.fill")
                }.help((state.isPaused ? "Resume Recording" : "Pause Recording").local)
            }
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text(SCContext.getRecordingLength()).monospacedDigit()
            }
        }
        .font(.system(size: 20))
        .buttonStyle(.plain)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .disabled(SCContext.isStopping)
    }
}

func updateStatusBar() {
    DispatchQueue.main.async { RecordingStatusController.shared.refresh() }
}
