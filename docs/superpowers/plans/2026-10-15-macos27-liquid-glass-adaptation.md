# QuickRecorder macOS 27 适配与 Liquid Glass 全面改造实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 QuickRecorder 在 macOS 27 上原生运行，全面采用 Liquid Glass 设计语言，修复菜单栏交互 Bug，完成 Fork 分发配置。

**Architecture:** 在现有 SwiftUI/AppKit 混合架构上做适配层修改。所有 macOS 26+ 新 API 通过 `#available` 守卫 + View extension (`qrGlassBackground`) 统一封装，低版本自动回退到 `.ultraThinMaterial` / 纯色方案。菜单栏 Bug 修复针对 NSStatusItem 系统级行为变化做条件分支。

**Tech Stack:** Swift 5.0, SwiftUI, AppKit, ScreenCaptureKit, Sparkle, Xcode 27 SDK

**Spec:** `docs/superpowers/specs/2026-10-15-macos27-liquid-glass-adaptation-design.md`

## Global Constraints

- 最低部署目标：`MACOSX_DEPLOYMENT_TARGET = 12.3`（不变）
- Swift 语言模式：Swift 5（不启用 Swift 6 并发检查）
- 新 Bundle ID：`com.liudicy.QuickRecorder`
- Fork 仓库地址：`https://github.com/liudicy/Luma`
- 原版归属：`https://github.com/lihaoyun6/QuickRecorder`
- 所有 macOS 26+ API 用 `#available(macOS 26, *)` 守卫
- 所有 macOS 27 特有用 `isMacOS27`（`majorVersion >= 27`）守卫
- 品牌色：`mypurple`（P3 #5756CF light / #6261EA dark），定义在 Assets.xcassets/Colors/mypurple.colorset
- 验证命令：`xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build`（编译通过即验证成功）

---

### Task 1: 版本检测常量

**Files:**
- Modify: `QuickRecorder/QuickRecorderApp.swift:19-21`

**Interfaces:**
- Produces: `isMacOS26: Bool`, `isMacOS27: Bool` — 全局常量，后续所有任务使用

- [ ] **Step 1: 添加 macOS 26/27 版本检测常量**

在 `QuickRecorderApp.swift` 第 21 行 `isMacOS15` 之后添加：

```swift
let isMacOS26 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
let isMacOS27 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`，无 error。

- [ ] **Step 3: Commit**

```bash
git add QuickRecorder/QuickRecorderApp.swift
git commit -m "feat: add macOS 26/27 version detection constants"
```

---

### Task 2: Xcode 项目配置更新

**Files:**
- Modify: `QuickRecorder.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: 无
- Produces: 更新后的项目配置（Bundle ID、版本号、LastUpgradeCheck）

- [ ] **Step 1: 修改 Bundle ID**

在 `project.pbxproj` 中，将所有 `PRODUCT_BUNDLE_IDENTIFIER = com.lihaoyun6.QuickRecorder` 替换为 `PRODUCT_BUNDLE_IDENTIFIER = com.liudicy.QuickRecorder`。共 2 处（Debug + Release）。

- [ ] **Step 2: 更新版本号**

将 `MARKETING_VERSION = 1.6.9` 替换为 `MARKETING_VERSION = 1.7.0`（2 处）。
将 `CURRENT_PROJECT_VERSION = 169` 替换为 `CURRENT_PROJECT_VERSION = 170`（2 处）。

- [ ] **Step 3: 更新 LastUpgradeCheck**

将 `LastUpgradeCheck = 1600` 替换为 `LastUpgradeCheck = 1700`。

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: Commit**

```bash
git add QuickRecorder.xcodeproj/project.pbxproj
git commit -m "chore: update bundle ID, version 1.7.0, LastUpgradeCheck 1700"
```

---

### Task 3: Bundle ID 引用同步

**Files:**
- Modify: `QuickRecorder/SCContext.swift:53`
- Modify: `QuickRecorder/QuickRecorderApp.swift:204`
- Modify: `QuickRecorder/QuickRecorderApp.swift:551`

**Interfaces:**
- Consumes: Task 2 的新 Bundle ID
- Produces: 所有对旧 Bundle ID 的硬编码引用更新

- [ ] **Step 1: 更新 SCContext.swift excludedApps**

在 `SCContext.swift:53`，`excludedApps` 数组中检查是否包含旧 Bundle ID `com.lihaoyun6.QuickRecorder`。如果有，替换为 `com.liudicy.QuickRecorder`。当前代码中该数组不包含旧 Bundle ID（排除的是其他 app），所以**确认无需修改即可**。

- [ ] **Step 2: 更新 QuickRecorderApp.swift 中的 Bundle ID 引用**

`QuickRecorderApp.swift:204` 中 `process.filter({ $0.bundleIdentifier == "com.lihaoyun6.QuickRecorder" })` 替换为 `"com.liudicy.QuickRecorder"`。

`QuickRecorderApp.swift:551` 中 `excludedAppBundleIDs` 数组里的 `"com.lihaoyun6.QuickRecorder"` 替换为 `"com.liudicy.QuickRecorder"`。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/SCContext.swift QuickRecorder/QuickRecorderApp.swift
git commit -m "chore: sync bundle ID references to com.liudicy.QuickRecorder"
```

---

### Task 4: Sparkle 更新配置

**Files:**
- Modify: `QuickRecorder/Info.plist:48-49`

**Interfaces:**
- Consumes: 无
- Produces: Sparkle 指向 fork 仓库

- [ ] **Step 1: 修改 SUFeedURL**

`Info.plist:48` 中 `SUFeedURL` 的值从 `https://raw.githubusercontent.com/lihaoyun6/QuickRecorder/main/appcast.xml` 改为 `https://raw.githubusercontent.com/liudicy/Luma/main/appcast.xml`。

- [ ] **Step 2: 生成新的 EdDSA 密钥对**

Run: 找到 Sparkle 框架中的 `generate_keys` 工具并运行。通常在 SPM 缓存或 `Pods/Sparkle/bin/generate_keys`。
如果没有本地安装，可通过 `brew install sparkle` 或从 GitHub release 下载。

```bash
# 假设 Sparkle 在 DerivedData 的 SPM 缓存中
find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" -type f 2>/dev/null | head -1
# 运行 generate_keys，将输出的公钥写入 SUPublicEDKey
```

将输出的公钥（base64 字符串）写入 `Info.plist:49` 的 `SUPublicEDKey`。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/Info.plist
git commit -m "chore: update Sparkle feed URL and EdDSA key for fork"
```

---

### Task 5: qrGlassBackground View Extension

**Files:**
- Create: `QuickRecorder/Supports/GlassBackground.swift`

**Interfaces:**
- Consumes: Task 1 的 `isMacOS26`
- Produces: `qrGlassBackground(tint:cornerRadius:interactive:)` — 后续所有 Glass 适配任务使用

- [ ] **Step 1: 创建 GlassBackground.swift**

```swift
//
//  GlassBackground.swift
//  QuickRecorder
//
//  Liquid Glass background extension for macOS 26+ with fallback for older versions.
//

import SwiftUI

extension View {
    @ViewBuilder
    func qrGlassBackground(tint: Color? = nil, cornerRadius: CGFloat = 8, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            // NOTE: .interactive() availability on macOS needs verification.
            // If unavailable on macOS 26+ SDK, omit .interactive() and use only tint + cornerRadius.
            if let tint = tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                }
            }
        } else {
            if let tint = tint {
                self.background(tint.opacity(0.8)).cornerRadius(cornerRadius)
            } else {
                self.background(.ultraThinMaterial).cornerRadius(cornerRadius)
            }
        }
    }
}
```

- [ ] **Step 2: 将文件添加到 Xcode 项目**

打开 `QuickRecorder.xcodeproj`，将 `GlassBackground.swift` 拖入 `Supports` 分组。确保 Target Membership 勾选 QuickRecorder。

或者手动编辑 `project.pbxproj` 添加文件引用（与 `SleepPreventer.swift` 同组）。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。如果 `.interactive()` 在 macOS SDK 中不可用导致编译错误，移除所有 `.interactive()` 调用并记录。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/Supports/GlassBackground.swift QuickRecorder.xcodeproj/project.pbxproj
git commit -m "feat: add qrGlassBackground View extension for Liquid Glass adaptation"
```

---

### Task 6: 修复菜单栏 onHover 失效（FB23329983）

**Files:**
- Modify: `QuickRecorder/ViewModel/StatusBar.swift:37-95, 216-221`

**Interfaces:**
- Consumes: Task 1 的 `isMacOS27`
- Produces: 修复后的 mini 模式按钮显示逻辑

- [ ] **Step 1: 修改 mini 模式 hover 逻辑**

在 `StatusBar.swift:38`，将：

```swift
if miniStatusBar {
    if isHovering {
```

改为：

```swift
if miniStatusBar {
    if isMacOS27 || isHovering {
```

- [ ] **Step 2: 修改 hideMousePointer/hideScreenMagnifier 逻辑**

在 `StatusBar.swift:216-221`，将：

```swift
.onTapGesture {}
.onHover { hovering in
    isHovering = hovering
    hideMousePointer = hovering
    hideScreenMagnifier = hovering
}
```

改为：

```swift
.onHover { hovering in
    isHovering = hovering
    if !isMacOS27 {
        hideMousePointer = hovering
        hideScreenMagnifier = hovering
    }
}
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/ViewModel/StatusBar.swift
git commit -m "fix: menu bar mini mode buttons always visible on macOS 27 (FB23329983)"
```

---

### Task 7: 修复 occlusionState 失效（FB23349447）

**Files:**
- Modify: `QuickRecorder/ViewModel/StatusBar.swift:138-155`

**Interfaces:**
- Consumes: Task 1 的 `isMacOS27`
- Produces: 修复后的浮动控制面板显示逻辑

- [ ] **Step 1: 修改浮动控制面板逻辑**

在 `StatusBar.swift:142-154`，将 `onReceive(updateTimer)` 中 occlusionState 相关逻辑替换为：

```swift
.onReceive(updateTimer) { t in
    recordingLength = SCContext.getRecordingLength()
    let timePassed = Date.now.timeIntervalSince(SCContext.startTime ?? t)
    if SCContext.autoStop != 0 && timePassed / 60 >= CGFloat(SCContext.autoStop) { SCContext.stopRecording() }
    
    if isMacOS27 {
        // macOS 27: occlusionState unreliable, use visibleFrame to detect menu bar auto-hide
        let mainPanelVisible = NSApp.windows.contains(where: { $0.title == "QuickRecorder".local && $0.isVisible })
        if mainPanelVisible {
            NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.close()
            return
        }
        guard let screen = SCContext.getScreenWithMouse() else { return }
        let menuBarVisible = screen.visibleFrame.maxY < screen.frame.maxY
        if SCContext.streamType != nil && !menuBarVisible && !(NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.isVisible ?? false) {
            let width = getStatusBarWidth()
            let wX = (screen.frame.width - width) / 2
            let contentView = NSHostingView(rootView: StatusBarItem())
            contentView.frame = NSRect(x: wX, y: screen.visibleFrame.maxY, width: width, height: 24)
            controlPanel.setFrame(contentView.frame, display: true)
            controlPanel.contentView = contentView
            controlPanel.makeKeyAndOrderFront(nil)
        }
    } else {
        // macOS 26-: original occlusionState logic
        if let visible = statusBarItem.button?.window?.occlusionState.contains(.visible) {
            if visible { NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.close(); return }
            if SCContext.streamType != nil && !visible && !(NSApp.windows.first(where: { $0.title == "Recording Controller".local })?.isVisible ?? false) {
                guard let screen = SCContext.getScreenWithMouse() else { return }
                let width = getStatusBarWidth()
                let wX = (screen.frame.width - width) / 2
                let contentView = NSHostingView(rootView: StatusBarItem())
                contentView.frame = NSRect(x: wX, y: screen.visibleFrame.maxY, width: width, height: 24)
                controlPanel.setFrame(contentView.frame, display: true)
                controlPanel.contentView = contentView
                controlPanel.makeKeyAndOrderFront(nil)
            }
        }
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: Commit**

```bash
git add QuickRecorder/ViewModel/StatusBar.swift
git commit -m "fix: use visibleFrame for menu bar visibility detection on macOS 27 (FB23349447)"
```

---

### Task 8: 修复 NSGlassContainerView 点击拦截

**Files:**
- Modify: `QuickRecorder/QuickRecorderApp.swift:201-206`（`applicationWillFinishLaunching` 开头）

**Interfaces:**
- Consumes: Task 1 的 `isMacOS26`
- Produces: `enableGlassContainerClickThrough()` 函数

- [ ] **Step 1: 添加 swizzle 函数**

在 `QuickRecorderApp.swift` 的 `AppDelegate` class 末尾（`EscPanel` 定义之前），添加：

```swift
// TODO: Remove when Apple fixes NSGlassContainerView hitTest (FB pending)
func enableGlassContainerClickThrough() {
    guard let cls = NSClassFromString("NSGlassContainerView") else { return }
    let originalSelector = #selector(NSView.hitTest(_:))
    guard let originalMethod = class_getInstanceMethod(cls, originalSelector) else { return }
    
    let block: @convention(block) (NSView, NSPoint) -> NSView? = { view, point in
        let result = view.hitTest(point)
        // If hit test returns the glass container itself, return nil to let clicks pass through
        if result === view { return nil }
        return result
    }
    
    let newImp = imp_implementationWithBlock(block)
    let swizzledSelector = sel_registerName("qr_hitTest:")
    
    if class_addMethod(cls, swizzledSelector, newImp, method_getTypeEncoding(originalMethod)) {
        let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)!
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
```

- [ ] **Step 2: 在启动时调用**

在 `applicationWillFinishLaunching` 中，`statusBarItem` 初始化之后（约第 265 行 `statusBarItem.button?.image = NSImage()` 之后），添加：

```swift
if isMacOS26 || isMacOS27 {
    enableGlassContainerClickThrough()
}
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/QuickRecorderApp.swift
git commit -m "fix: swizzle NSGlassContainerView hitTest for click-through on macOS 26+"
```

---

### Task 9: 移除空 onTapGesture + StatusBarItem 尺寸适配

**Files:**
- Modify: `QuickRecorder/ViewModel/StatusBar.swift:216, 233-234`
- Modify: `QuickRecorder/QuickRecorderApp.swift:434-444`

**Interfaces:**
- Consumes: Task 1 的 `isMacOS27`
- Produces: 修复后的 StatusBarItem 交互和尺寸

- [ ] **Step 1: 移除空 onTapGesture**

在 `StatusBar.swift:216`，删除 `.onTapGesture {}` 行（已在 Task 6 中修改了 onHover 部分，此处确认 onTapGesture 已移除）。

注意：Task 6 Step 2 的修改中已经移除了 `.onTapGesture {}`，此步骤确认即可。

- [ ] **Step 2: 添加 macOS 27 StatusBarItem 尺寸分支**

在 `StatusBar.swift:233-234`，将：

```swift
let iconView = NSHostingView(rootView: StatusBarItem().padding(.top, isMacOS14 ? -2 : -1))
iconView.frame = NSRect(x: 0, y: 1, width: getStatusBarWidth(), height: isMacOS14 ? 22 : 21)
```

改为：

```swift
let topPadding: CGFloat = isMacOS27 ? -2 : (isMacOS14 ? -2 : -1)
let barHeight: CGFloat = isMacOS27 ? 22 : (isMacOS14 ? 22 : 21)
let iconView = NSHostingView(rootView: StatusBarItem().padding(.top, topPadding))
iconView.frame = NSRect(x: 0, y: 1, width: getStatusBarWidth(), height: barHeight)
```

注：macOS 27 初始值参考 macOS 26/14 的 `-2`/`22`，实测后可微调。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/ViewModel/StatusBar.swift
git commit -m "fix: remove empty onTapGesture, add macOS 27 status bar sizing"
```

---

### Task 10: 主面板 Liquid Glass 适配（ContentView）

**Files:**
- Modify: `QuickRecorder/ViewModel/ContentView.swift:34-36, 290-293, 304`

**Interfaces:**
- Consumes: Task 5 的 `qrGlassBackground()`
- Produces: 主面板 Glass 背景

- [ ] **Step 1: 修改主面板背景**

在 `ContentView.swift:34-36`，将：

```swift
Color.clear
    .background(.ultraThinMaterial)
    .environment(\.controlActiveState, .active)
```

改为：

```swift
Color.clear
    .qrGlassBackground(cornerRadius: 14)
    .environment(\.controlActiveState, .active)
```

注意：`qrGlassBackground` 内部已处理 cornerRadius，外部不再需要 `.cornerRadius(14)`。第 47 行的 `.cornerRadius(14)` 保留（它作用于包含 SurpriseView 的 ZStack）。

- [ ] **Step 2: 修改 SelectorView hover 高亮**

在 `ContentView.swift:290-293`，将：

```swift
.background( .primary.opacity(backgroundOpacity) )
```

改为：

```swift
if #available(macOS 26, *) {
    .qrGlassBackground(tint: .primary.opacity(0.15), cornerRadius: 8, interactive: true)
} else {
    .background(.primary.opacity(backgroundOpacity))
}
```

由于 `@ViewBuilder` 中不能直接用 `if #available` 包裹 modifier，改为：

```swift
.background(
    Group {
        if #available(macOS 26, *) {
            Color.clear.qrGlassBackground(tint: .primary.opacity(0.15), cornerRadius: 8, interactive: true)
        } else {
            Color.primary.opacity(backgroundOpacity)
        }
    }
)
```

实际上更简洁的方式是直接在 `qrGlassBackground` 中处理。修改 SelectorView 的 body，将 `.background(.primary.opacity(backgroundOpacity))` 替换为：

```swift
.qrGlassBackground(tint: .primary.opacity(backgroundOpacity > 0.01 ? 0.15 : 0.0001), cornerRadius: 8, interactive: true)
```

这样低版本回退为 `background(tint.opacity(0.8))`，高版本为 Glass effect。

- [ ] **Step 3: 修改 CountdownView 背景**

在 `ContentView.swift:304`，将：

```swift
Color.mypurple.environment(\.colorScheme, .dark)
```

改为：

```swift
Color.clear
    .qrGlassBackground(tint: .mypurple, cornerRadius: 10, interactive: true)
    .environment(\.colorScheme, .dark)
```

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: Commit**

```bash
git add QuickRecorder/ViewModel/ContentView.swift
git commit -m "feat: adopt Liquid Glass for main panel and countdown view"
```

---

### Task 11: 菜单栏控件 Liquid Glass 适配（StatusBar）

**Files:**
- Modify: `QuickRecorder/ViewModel/StatusBar.swift:32-35, 163-169, 177-185`

**Interfaces:**
- Consumes: Task 5 的 `qrGlassBackground()`
- Produces: 菜单栏控件 Glass 背景

- [ ] **Step 1: 修改录制中背景**

在 `StatusBar.swift:32-35`，将：

```swift
Rectangle()
    .fill(Color.mypurple)
    .shadow(color: .black.opacity(0.3), radius: 4)
    .cornerRadius(4)
```

改为：

```swift
Rectangle()
    .fill(Color.clear)
    .qrGlassBackground(tint: .mypurple, cornerRadius: 4, interactive: true)
```

- [ ] **Step 2: 修改 camera 按钮背景**

在 `StatusBar.swift:163-169`，将：

```swift
Rectangle()
    .fill(SCContext.isCameraRunning() ? Color.mygreen : .gray)
    .shadow(color: .black.opacity(0.3), radius: 4)
    .cornerRadius(4)
```

改为：

```swift
Rectangle()
    .fill(Color.clear)
    .qrGlassBackground(tint: SCContext.isCameraRunning() ? .mygreen : .gray, cornerRadius: 4, interactive: true)
```

- [ ] **Step 3: 修改 idevice 按钮背景**

在 `StatusBar.swift:177-185`，将：

```swift
Rectangle()
    .fill(deviceWindow.isVisible ? Color.myblue : .gray.opacity(0.7))
    .shadow(color: .black.opacity(0.3), radius: 4)
    .cornerRadius(4)
```

改为：

```swift
Rectangle()
    .fill(Color.clear)
    .qrGlassBackground(tint: deviceWindow.isVisible ? .myblue : .gray.opacity(0.7), cornerRadius: 4, interactive: true)
```

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: Commit**

```bash
git add QuickRecorder/ViewModel/StatusBar.swift
git commit -m "feat: adopt Liquid Glass for status bar controls"
```

---

### Task 12: 预览窗口 + 区域选择器 Glass 适配

**Files:**
- Modify: `QuickRecorder/ViewModel/PreviewView.swift:25-28`
- Modify: `QuickRecorder/ViewModel/AreaSelector.swift:89`

**Interfaces:**
- Consumes: Task 5 的 `qrGlassBackground()`

- [ ] **Step 1: 修改 PreviewView 背景**

在 `PreviewView.swift:25-28`，将：

```swift
Color.clear
    .background(.ultraThickMaterial)
    .environment(\.controlActiveState, .active)
    .cornerRadius(6)
```

改为：

```swift
Color.clear
    .qrGlassBackground(cornerRadius: 6)
    .environment(\.controlActiveState, .active)
```

- [ ] **Step 2: 修改 AreaSelector 背景**

在 `AreaSelector.swift:89`，将：

```swift
Color(nsColor: NSColor.windowBackgroundColor)
    .cornerRadius(10)
```

改为：

```swift
Color.clear
    .qrGlassBackground(cornerRadius: 10)
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/ViewModel/PreviewView.swift QuickRecorder/ViewModel/AreaSelector.swift
git commit -m "feat: adopt Liquid Glass for preview window and area selector"
```

---

### Task 13: 设置窗口 NavigationSplitView + Glass 适配

**Files:**
- Modify: `QuickRecorder/ViewModel/SettingsView.swift:14-39`

**Interfaces:**
- Consumes: Task 1 的 `isMacOS26`
- Produces: NavigationSplitView 版本的设置窗口

- [ ] **Step 1: 修改 SettingsView 结构**

在 `SettingsView.swift:17-39`，将 `body` 中的 `NavigationView` 替换为：

```swift
var body: some View {
    if #available(macOS 26, *) {
        NavigationSplitView {
            List(selection: $selectedItem) {
                NavigationLink(value: "General") {
                    Label("General", image: "gear")
                }
                NavigationLink(value: "Recorder") {
                    Label("Recorder", image: "record")
                }
                NavigationLink(value: "Output") {
                    Label("Output", image: "film")
                }
                NavigationLink(value: "Hotkey") {
                    Label("Hotkey", image: "hotkey")
                }
                NavigationLink(value: "Blocklist") {
                    Label("Blocklist", image: "blacklist")
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
        } detail: {
            switch selectedItem {
            case "General": GeneralView()
            case "Recorder": RecorderView()
            case "Output": OutputView()
            case "Hotkey": HotkeyView()
            case "Blocklist": BlocklistView()
            default: GeneralView()
            }
        }
        .frame(width: 600, height: 512)
    } else {
        NavigationView {
            List(selection: $selectedItem) {
                NavigationLink(destination: GeneralView(), tag: "General", selection: $selectedItem) {
                    Label("General", image: "gear")
                }
                NavigationLink(destination: RecorderView(), tag: "Recorder", selection: $selectedItem) {
                    Label("Recorder", image: "record")
                }
                NavigationLink(destination: OutputView(), tag: "Output", selection: $selectedItem) {
                    Label("Output", image: "film")
                }
                NavigationLink(destination: HotkeyView(), tag: "Hotkey", selection: $selectedItem) {
                    Label("Hotkey", image: "hotkey")
                }
                NavigationLink(destination: BlocklistView(), tag: "Blaoklist", selection: $selectedItem) {
                    Label("Blocklist", image: "blacklist")
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
        }.frame(width: 600, height: 512)
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: Commit**

```bash
git add QuickRecorder/ViewModel/SettingsView.swift
git commit -m "feat: adopt NavigationSplitView for settings on macOS 26+"
```

---

### Task 14: ContentViewNew Glass 适配

**Files:**
- Modify: `QuickRecorder/ViewModel/ContentViewNew.swift`

**Interfaces:**
- Consumes: Task 5 的 `qrGlassBackground()`
- Produces: ContentViewNew Glass 背景

- [ ] **Step 1: 修改 ContentViewNew 背景**

在 `ContentViewNew.swift` 中，为外层 ZStack 添加 Glass 背景。当前代码没有显式背景（依赖 NSWindow 的 `backgroundColor = .clear`），在 macOS 26+ 上需要添加 Glass 效果。

在 `ContentViewNew.swift:28` 的 `ZStack {` 之后，最内层添加背景：

找到 `ContentViewNew` 的 `body` 中最外层的 `ZStack {`，在其 `}.padding(10)` 的闭包结束后，添加 Glass 背景修饰符：

```swift
// 在 .padding(10) 之后添加
.qrGlassBackground(cornerRadius: 14)
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: Commit**

```bash
git add QuickRecorder/ViewModel/ContentViewNew.swift
git commit -m "feat: adopt Liquid Glass for popover main panel"
```

---

### Task 15: 其他选择器窗口 Glass 适配

**Files:**
- Modify: `QuickRecorder/ViewModel/ScreenSelector.swift`
- Modify: `QuickRecorder/ViewModel/WinSelector.swift`
- Modify: `QuickRecorder/ViewModel/AppSelector.swift`
- Modify: `QuickRecorder/ViewModel/iDeviceSelector.swift`

**Interfaces:**
- Consumes: Task 5 的 `qrGlassBackground()`

- [ ] **Step 1: 定位所有需要替换的背景模式**

Run: `grep -n "Rectangle()" QuickRecorder/ViewModel/ScreenSelector.swift QuickRecorder/ViewModel/WinSelector.swift QuickRecorder/ViewModel/AppSelector.swift QuickRecorder/ViewModel/iDeviceSelector.swift`

确认每个文件中 `Rectangle().fill(...)` + `.cornerRadius(...)` 的位置。

- [ ] **Step 2: 逐个替换为 qrGlassBackground**

对每个文件中的 `Rectangle().fill(color).cornerRadius(r)` 模式，替换为：

```swift
Rectangle()
    .fill(Color.clear)
    .qrGlassBackground(tint: color, cornerRadius: r)
```

对于不需要 tint 的纯背景（如 `.fill(Color.gray.opacity(0.1))`），使用：

```swift
Color.clear
    .qrGlassBackground(cornerRadius: r)
```

具体替换点：
- `ScreenSelector.swift:67-69`：`Rectangle().fill(Color.gray.opacity(0.1)).cornerRadius(5)` → `Color.clear.qrGlassBackground(cornerRadius: 5)`
- `WinSelector.swift:112-114`：同理
- `AppSelector.swift:62-64`：同理
- `iDeviceSelector.swift:79`：`RoundedRectangle(cornerRadius: 5).fill(...)` → 检查具体颜色后替换

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/ViewModel/ScreenSelector.swift QuickRecorder/ViewModel/WinSelector.swift QuickRecorder/ViewModel/AppSelector.swift QuickRecorder/ViewModel/iDeviceSelector.swift
git commit -m "feat: adopt Liquid Glass for selector windows"
```

---

### Task 16: QmaPlayer + VideoEditor Glass 适配

**Files:**
- Modify: `QuickRecorder/ViewModel/QmaPlayer.swift`
- Modify: `QuickRecorder/ViewModel/VideoEditor.swift`

**Interfaces:**
- Consumes: Task 5 的 `qrGlassBackground()`

- [ ] **Step 1: 替换 QmaPlayer 中的背景**

在 `QmaPlayer.swift` 中，将以下位置的 `Rectangle().fill(...).cornerRadius(...)` 替换为 `qrGlassBackground`：

- `:49-50`：进度条背景
- `:70-71`：按钮背景
- `:88-89`：控制面板背景
- `:111-112`：音量条背景
- `:207-212`：轨道面板背景
- `:259-264`：时间轴背景
- `:272-273`：滑块背景

对每个位置，模式为：
```swift
// 原模式
Rectangle().fill(someColor).cornerRadius(r)
// 替换为
Rectangle().fill(Color.clear).qrGlassBackground(tint: someColor, cornerRadius: r)
```

- [ ] **Step 2: 替换 VideoEditor 中的背景**

在 `VideoEditor.swift:142-144`，将 `Rectangle().fill(...).cornerRadius(5)` 替换为 `qrGlassBackground` 模式。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/ViewModel/QmaPlayer.swift QuickRecorder/ViewModel/VideoEditor.swift
git commit -m "feat: adopt Liquid Glass for QmaPlayer and VideoEditor"
```

---

### Task 17: 浮动窗口 Glass 化

**Files:**
- Modify: `QuickRecorder/ViewModel/CameraOverlayer.swift:191, 232`
- Modify: `QuickRecorder/QuickRecorderApp.swift:279-310`

**Interfaces:**
- Consumes: Task 5 的 `qrGlassBackground()`

- [ ] **Step 1: 修改 CameraOverlayer 背景**

在 `CameraOverlayer.swift:191` 和 `:232`，将 `RoundedRectangle(cornerRadius: 5).fill(...)` 替换为 `qrGlassBackground` 模式。

- [ ] **Step 2: 修改 controlPanel 窗口配置**

在 `QuickRecorderApp.swift:298-304`，controlPanel 的 contentView 在 StatusBar.swift 的 Task 11 中已处理 Glass 背景。确认窗口配置无需额外修改（`backgroundColor = .clear` 保持）。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/ViewModel/CameraOverlayer.swift QuickRecorder/QuickRecorderApp.swift
git commit -m "feat: adopt Liquid Glass for camera overlay and floating windows"
```

---

### Task 18: 关于页面与归属声明

**Files:**
- Modify: `QuickRecorder/ViewModel/SettingsView.swift`

**Interfaces:**
- Consumes: Task 13 的 SettingsView 结构
- Produces: About 区块

- [ ] **Step 1: 在 GeneralView 底部添加关于区块**

在 `SettingsView.swift` 的 `GeneralView` 中，找到最后一个 `SGroupBox` 之后，添加：

```swift
SGroupBox(label: "About") {
    VStack(alignment: .leading, spacing: 8) {
        Text("QuickRecorder Fork")
            .font(.headline)
        Text("Based on [lihaoyun6/QuickRecorder](https://github.com/lihaoyun6/QuickRecorder)")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("Fork: [liudicy/Luma](https://github.com/liudicy/Luma)")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("Version 1.7.0 (170)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: Commit**

```bash
git add QuickRecorder/ViewModel/SettingsView.swift
git commit -m "feat: add about section with fork attribution"
```

---

### Task 19: README 更新

**Files:**
- Modify: `README.md`
- Modify: `README_zh.md`

**Interfaces:**
- 无

- [ ] **Step 1: 更新 README.md**

在 `README.md` 标题下方添加 fork 说明：

```markdown
> **Note:** This is a fork of [lihaoyun6/QuickRecorder](https://github.com/lihaoyun6/QuickRecorder), adapted for macOS 27 with Liquid Glass design and bug fixes.
```

在 `## Installation and Usage` 部分，更新 Homebrew 安装命令为 fork 的 tap（如果有的话），或标注为从 Releases 下载。

- [ ] **Step 2: 更新 README_zh.md**

在 `README_zh.md` 标题下方添加对应的 fork 说明（中文）。

- [ ] **Step 3: Commit**

```bash
git add README.md README_zh.md
git commit -m "docs: update README with fork information"
```

---

### Task 20: App 图标重设计

**Files:**
- Modify: `QuickRecorder/Assets.xcassets/AppIcon.appiconset/`

**Interfaces:**
- 无

- [ ] **Step 1: 生成新图标**

基于当前图标特征（紫色渐变圆角矩形 + 白色半透明同心圆环），按 Liquid Glass 设计标准生成新图标。使用 ImageGen 工具生成 1024x1024 主图标，然后缩放到所有必需尺寸。

设计要点：
- 圆角矩形底板（macOS 27 收敛后的圆角弧度，约 22.5%）
- 紫色渐变基底（#5756CF → #6261EA）
- 白色半透明同心圆环（录制指示器）居中
- 玻璃质感：顶部高光 + 底部反射
- 整体透明度层次：底板不透明 → 圆环半透明 → 中心点更透明

- [ ] **Step 2: 生成所有尺寸**

从 1024x1024 缩放生成：16, 32, 64, 128, 256, 512 @1x/@2x。

```bash
# 使用 sips 缩放
sips -z 16 16 icon_1024.png --out icon_16x16.png
sips -z 32 32 icon_1024.png --out icon_16x16@2x.png
# ... 以此类推
```

- [ ] **Step 3: 替换 Assets.xcassets 中的图标文件**

将生成的图标文件替换到 `QuickRecorder/Assets.xcassets/AppIcon.appiconset/` 中，保持文件名不变。

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: Commit**

```bash
git add QuickRecorder/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: redesign app icon with Liquid Glass style"
```

---

### Task 21: ScreenCaptureKit 兼容性检查

**Files:**
- Modify: `QuickRecorder/RecordEngine.swift`

**Interfaces:**
- 无

- [ ] **Step 1: 编译并检查 deprecation warnings**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "warning:.*deprecated"`

记录所有 deprecation warning。

- [ ] **Step 2: 处理废弃 API**

对每一个 deprecation warning，查找替代 API 并用 `#available` 分支处理。常见项：
- `SCShareableContent.getExcludingDesktopWindows` → 检查 macOS 27 是否有新签名
- `SCStreamConfiguration` 相关属性 → 检查是否有新 preset

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`，无新增 deprecation warning。

- [ ] **Step 4: Commit**

```bash
git add QuickRecorder/RecordEngine.swift
git commit -m "fix: address ScreenCaptureKit deprecation warnings on macOS 27 SDK"
```

---

### Task 22: appcast.xml 更新

**Files:**
- Modify: `appcast.xml`

**Interfaces:**
- Consumes: Task 2 的版本号（1.7.0 build 170）
- Produces: 更新后的 appcast

- [ ] **Step 1: 更新 appcast.xml**

在 `appcast.xml` 中添加新版本条目，更新下载 URL 为 fork 仓库的 release 地址。

- [ ] **Step 2: Commit**

```bash
git add appcast.xml
git commit -m "chore: update appcast for v1.7.0"
```

---

### Task 23: 全量编译验证

**Files:**
- 无

**Interfaces:**
- Consumes: 所有前面任务的改动

- [ ] **Step 1: Clean build**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Debug clean build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`，无 error，无新增 warning。

- [ ] **Step 2: Release build**

Run: `xcodebuild -project QuickRecorder.xcodeproj -scheme QuickRecorder -configuration Release build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`。

---

## Self-Review Checklist

- [x] Spec 4.1.1 版本检测常量 → Task 1
- [x] Spec 4.1.2 Xcode 项目配置 → Task 2
- [x] Spec 4.1.3 Sparkle 更新配置 → Task 4
- [x] Spec 4.1.4 Bundle ID 修改 → Task 2 + Task 3
- [x] Spec 4.1.5 关于页面与归属声明 → Task 18 + Task 19
- [x] Spec 4.1.6 App 图标重设计 → Task 20
- [x] Spec 4.2.1 onHover 失效修复 → Task 6
- [x] Spec 4.2.2 occlusionState 失效修复 → Task 7
- [x] Spec 4.2.3 NSGlassContainerView 点击穿透 → Task 8
- [x] Spec 4.2.4 移除空 onTapGesture → Task 9 (Step 1)
- [x] Spec 4.2.5 StatusBarItem 尺寸适配 → Task 9 (Step 2)
- [x] Spec 4.3.1 qrGlassBackground extension → Task 5
- [x] Spec 4.3.2 主面板 ContentView → Task 10
- [x] Spec 4.3.3 菜单栏控件 StatusBar → Task 11
- [x] Spec 4.3.4 预览窗口 PreviewView → Task 12
- [x] Spec 4.3.5 区域选择器 AreaSelector → Task 12
- [x] Spec 4.3.6 设置窗口 SettingsView → Task 13
- [x] Spec 4.3.7 浮动窗口 → Task 17
- [x] Spec 4.3.8 倒计时面板 CountdownView → Task 10 (Step 3)
- [x] Spec 4.3.9 其他选择器 → Task 15 + Task 16
- [x] Spec 4.3.10 透明度验证 → 需实机测试（不在代码任务中）
- [x] Spec 4.4.1 ScreenCaptureKit 兼容性 → Task 21
- [x] Spec 4.4.2 Presenter Overlay → 需实机测试（不在代码任务中）
- [x] Spec 4.4.3 多版本测试矩阵 → 需实机测试（不在代码任务中）
- [x] Spec 4.4.4 版本号 → Task 2
- [x] appcast.xml → Task 22
- [x] 全量编译验证 → Task 23
