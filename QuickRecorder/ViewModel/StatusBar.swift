//
//  StatusBarItem.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI

class PopoverState: ObservableObject {
    static let shared = PopoverState()
    @Published var isShowing: Bool = false
    @Published var isPaused: Bool = false
}

struct StatusBarItem: View {
    @State private var deviceWindowIsShowing = true
    @State private var isMainMenuShowing = false
    @State private var isHovering = false
    @State private var recordingLength = "00:00"
    //@State private var isPassed = SCContext.isPaused
    @StateObject private var popoverState = PopoverState.shared
    //@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("miniStatusBar") private var miniStatusBar: Bool = false
    //@AppStorage("highlightMouse") private var highlightMouse: Bool = false
    private var appDelegate = AppDelegate.shared
    
    var body: some View {
        HStack(spacing: 0) {
            if SCContext.streamType != nil {
                ZStack {
                    if #available(macOS 26, *) {
                        Rectangle()
                            .fill(Color.clear)
                            .qrGlassBackground(tint: .mypurple, cornerRadius: 4, interactive: true)
                    } else {
                        Rectangle()
                            .fill(Color.mypurple)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .cornerRadius(4)
                    }
                    HStack(spacing: 4) {
                        if miniStatusBar {
                            // macOS 27 renders the elapsed time followed by the always-visible buttons
                            // (hover-driven reveal is unavailable, FB23329983); macOS <= 26 keeps the
                            // original collapsed (time only) / hover-expanded (buttons only) layout.
                            if isMacOS27 || !isHovering {
                                Text(recordingLength)
                                    .foregroundStyle(.white)
                                    .font(.system(size: 15).monospaced())
                                    .offset(x: 0.5)
                            }
                            if isMacOS27 || isHovering {
                                Button(action: {
                                    if SCContext.streamType == .idevice {
                                        AVOutputClass.shared.stopRecording()
                                    } else {
                                        SCContext.stopRecording()
                                    }
                                }, label: {
                                    ZStack {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.red)
                                            .frame(width: 10, alignment: .center)
                                        Image(systemName: "stop.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, alignment: .center)
                                    }
                                }).buttonStyle(.plain)
                                if SCContext.streamType != .idevice {
                                    Button(action: {
                                        SCContext.pauseRecording()
                                    }, label: {
                                        Image(systemName: popoverState.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, alignment: .center)
                                    }).buttonStyle(.plain)
                                } else {
                                    Button(action:{
                                        DispatchQueue.main.async {
                                            if deviceWindow.isVisible { deviceWindow.close() } else { deviceWindow.orderFront(nil) }
                                            deviceWindowIsShowing = deviceWindow.isVisible
                                        }
                                    }, label: {
                                        Image(systemName: "eye.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, alignment: .center)
                                            .opacity(deviceWindowIsShowing ? 1 : 0.7)
                                    }).buttonStyle(.plain)
                                }
                                if SCContext.streamType != .systemaudio && SCContext.streamType != .idevice && SCContext.streamType != .window {
                                    Button(action:{
                                        popoverState.isShowing = true
                                    }, label: {
                                        Image(systemName: "camera.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, alignment: .center)
                                    }).buttonStyle(.plain)
                                }
                            }
                        } else {
                            Group {
                                Button(action: {
                                    if SCContext.streamType == .idevice {
                                        AVOutputClass.shared.stopRecording()
                                    } else {
                                        SCContext.stopRecording()
                                    }
                                }, label: {
                                    ZStack {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.red)
                                            .frame(width: 10, alignment: .center)
                                        Image(systemName: "stop.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, alignment: .center)
                                    }
                                }).buttonStyle(.plain)
                                if SCContext.streamType != .idevice {//&& SCContext.streamType != .systemaudio {
                                    Button(action: {
                                        SCContext.pauseRecording()
                                    }, label: {
                                        Image(systemName: popoverState.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .frame(width: 16, alignment: .center)
                                    }).buttonStyle(.plain)
                                }
                                Text(recordingLength)
                                    .foregroundStyle(.white)
                                    .font(.system(size: 15).monospaced())
                                    .offset(x: 0.5)
                            }
                        }
                    }
                }
                .padding([.leading,.trailing], 4)
                .popover(isPresented: $popoverState.isShowing, arrowEdge: .bottom) {
                    CameraPopoverView(closePopover: { popoverState.isShowing = false })
                }
                .onReceive(updateTimer) { t in
                    recordingLength = SCContext.getRecordingLength()
                    let timePassed = Date.now.timeIntervalSince(SCContext.startTime ?? t)
                    if SCContext.autoStop != 0 && timePassed / 60 >= CGFloat(SCContext.autoStop) { SCContext.stopRecording() }

                    if isMacOS27 {
                        // macOS 27: occlusionState is unreliable (FB23349447), so menu-bar visibility is a
                        // best-effort composite of the visibleFrame geometry and the status item's own
                        // window visibility (the bar can occupy space while our item is pushed out by the
                        // notch / a crowded bar, which is exactly when the floating panel is needed).
                        let mainPanelVisible = NSApp.windows.contains(where: { $0.title == "QuickRecorder".local && $0.isVisible })
                        if mainPanelVisible {
                            NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.close()
                            return
                        }
                        guard let screen = SCContext.getScreenWithMouse() else { return }
                        let menuBarOccupiesSpace = screen.visibleFrame.maxY < screen.frame.maxY
                        let itemReachable = statusBarItem.button?.window?.isVisible ?? false
                        let menuBarVisible = menuBarOccupiesSpace && itemReachable
                        if menuBarVisible {
                            NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.close()
                            return
                        }
                        if SCContext.streamType != nil && !(NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.isVisible ?? false) {
                            showFloatingControlPanel(on: screen)
                        }
                    } else {
                        // macOS 26-: original occlusionState logic
                        if let visible = statusBarItem.button?.window?.occlusionState.contains(.visible) {
                            if visible { NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.close(); return }
                            if SCContext.streamType != nil && !visible && !(NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.isVisible ?? false) {
                                guard let screen = SCContext.getScreenWithMouse() else { return }
                                showFloatingControlPanel(on: screen)
                            }
                        }
                    }
                }
                if !miniStatusBar {
                    if SCContext.streamType != .systemaudio {
                        if SCContext.streamType != .idevice {
                            Button(action:{
                                popoverState.isShowing = true
                            }, label: {
                                ZStack {
                                    if #available(macOS 26, *) {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .qrGlassBackground(tint: SCContext.isCameraRunning() ? .mygreen : .gray, cornerRadius: 4, interactive: true)
                                    } else {
                                        Rectangle()
                                            .fill(SCContext.isCameraRunning() ? Color.mygreen : .gray)
                                            .shadow(color: .black.opacity(0.3), radius: 4)
                                            .cornerRadius(4)
                                    }
                                    Image("camera")
                                        .foregroundStyle(.white)
                                }.frame(width: 36).padding([.leading,.trailing], 4)
                            }).buttonStyle(.plain)
                        } else {
                            Button(action:{
                                DispatchQueue.main.async {
                                    if deviceWindow.isVisible { deviceWindow.close() } else { deviceWindow.orderFront(nil) }
                                }
                            }, label: {
                                ZStack {
                                    if #available(macOS 26, *) {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .qrGlassBackground(tint: deviceWindow.isVisible ? .myblue : .gray.opacity(0.7), cornerRadius: 4, interactive: true)
                                    } else {
                                        Rectangle()
                                            .fill(deviceWindow.isVisible ? Color.myblue : .gray.opacity(0.7))
                                            .shadow(color: .black.opacity(0.3), radius: 4)
                                            .cornerRadius(4)
                                    }
                                    Image(systemName: "apps.ipad")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                }.frame(width: 36).padding([.leading,.trailing], 4)
                            })
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if ud.bool(forKey: "showMenubar") {
                Button(action: {
                    popoverState.isShowing = true
                }, label: {
                    ZStack {
                        Color.white.opacity(0.0001)
                        Image(systemName: "dot.circle.and.hand.point.up.left.fill")
                            .font(.system(size: 14, weight: .medium))
                            .offset(y: 1)
                    }
                })
                .buttonStyle(.plain)
                .popover(isPresented: $popoverState.isShowing, arrowEdge: .bottom) {
                    if #available(macOS 13, *) {
                        ContentViewNew().onAppear{ closeAllWindow() }
                    } else {
                        ContentView(fromStatusBar: true)
                            .onAppear{
                                closeAllWindow()
                                if isMacOS12 { NSApp.activate(ignoringOtherApps: true) }
                            }
                    }
                }
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if !isMacOS27 {
                hideMousePointer = hovering
                hideScreenMagnifier = hovering
            }
        }
    }
}

// Builds and shows the floating "Recording Controller" fallback panel centered on
// `screen`, just below the menu-bar edge. Shared by the macOS 27 and <= 26 branches
// of the updateTimer logic (identical action, different conditions).
private func showFloatingControlPanel(on screen: NSScreen) {
    let width = getStatusBarWidth()
    let wX = (screen.frame.width - width) / 2
    let contentView = NSHostingView(rootView: StatusBarItem())
    contentView.frame = NSRect(x: wX, y: screen.visibleFrame.maxY, width: width, height: 24)
    controlPanel.setFrame(contentView.frame, display: true)
    controlPanel.contentView = contentView
    controlPanel.makeKeyAndOrderFront(nil)
}

func updateStatusBar() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        if SCContext.streamType == nil && !ud.bool(forKey: "showMenubar") {
            statusBarItem.isVisible = false
            return
        }
        guard let button = statusBarItem.button else { return }
        //let width = SCContext.streamType == nil ? 36 : ((SCContext.streamType == .idevice || SCContext.streamType == .systemaudio) ? 138 : 158)
        let topPadding: CGFloat = isMacOS27 ? -2 : (isMacOS14 ? -2 : -1)
        let barHeight: CGFloat = isMacOS27 ? 22 : (isMacOS14 ? 22 : 21)
        let iconView = NSHostingView(rootView: StatusBarItem().padding(.top, topPadding))
        iconView.frame = NSRect(x: 0, y: 1, width: getStatusBarWidth(), height: barHeight)
        button.subviews = [iconView]
        button.frame = iconView.frame
        button.setAccessibilityLabel("QuickRecorder")
        statusBarItem.isVisible = true
    }
}
