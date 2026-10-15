# QuickRecorder macOS 27 适配与 Liquid Glass 全面改造设计规格

- 日期：2026-10-15
- 状态：待评审
- 范围：macOS 27 兼容性修复 + Liquid Glass 全面适配 + 菜单栏交互 Bug 修复 + Fork 分发配置

## 1. 背景与目标

QuickRecorder 是一款基于 ScreenCaptureKit 的 macOS 屏幕录制工具，原作者已停止维护。本 fork 的目标是让它在 macOS 27 上原生、稳定、美观地运行。

### 1.1 核心目标

1. **修复菜单栏交互 Bug**：暂停/停止按钮在 macOS 27 上点击无响应或不显示。
2. **全面采用 Liquid Glass**：用 Xcode 27 SDK 编译后，系统强制 Liquid Glass 渲染（opt-out key 被忽略），所有 UI 表面需主动适配。
3. **保持 macOS 12.3+ 向后兼容**：所有新 API 调用用 `#available` 守卫，低版本回退到现有方案。
4. **Fork 分发配置**：Sparkle 更新地址改为 fork 仓库。

### 1.2 非目标

- 不迁移到 Swift 6 语言模式（保持 Swift 5 模式 + Xcode 27 SDK 编译）。
- 不重构录制引擎核心架构（RecordEngine / SCContext 的录制逻辑不变）。
- 不新增功能，仅做适配和修复。

## 2. 现状分析

### 2.1 项目概况

| 属性 | 当前值 |
|------|--------|
| 最低部署目标 | macOS 12.3 |
| Swift 版本 | 5.0 |
| Xcode 版本 | 16 (LastUpgradeCheck = 1600) |
| 版本号 | 1.6.9 (build 169) |
| Bundle ID | com.lihaoyun6.QuickRecorder |
| 更新机制 | Sparkle, SUFeedURL 指向原作者仓库 |

### 2.2 关键文件清单

| 文件 | 职责 | 需改动 |
|------|------|--------|
| QuickRecorderApp.swift | App 入口、AppDelegate、窗口配置、版本常量 | 是 |
| SCContext.swift | 录制上下文、暂停/停止逻辑 | 是（状态同步） |
| RecordEngine.swift | 录制引擎、SCStream 配置 | 检查（deprecation） |
| ViewModel/StatusBar.swift | 菜单栏 UI + 交互 | 是（核心 Bug） |
| ViewModel/ContentView.swift | 主面板 UI | 是（Glass） |
| ViewModel/ContentViewNew.swift | Popover 版主面板 | 是（Glass） |
| ViewModel/SettingsView.swift | 设置窗口 | 是（Glass + NavigationSplitView） |
| ViewModel/PreviewView.swift | 录制预览弹窗 | 是（Glass） |
| ViewModel/AreaSelector.swift | 区域选择面板 | 是（Glass） |
| ViewModel/ScreenSelector.swift | 屏幕选择器 | 是（Glass） |
| ViewModel/WinSelector.swift | 窗口选择器 | 是（Glass） |
| ViewModel/AppSelector.swift | 应用选择器 | 是（Glass） |
| ViewModel/iDeviceSelector.swift | 移动设备选择器 | 是（Glass） |
| ViewModel/CameraOverlayer.swift | 摄像头悬浮窗 | 是（Glass） |
| ViewModel/QmaPlayer.swift | QMA 音频播放器 | 是（Glass） |
| ViewModel/VideoEditor.swift | 视频裁剪器 | 是（Glass） |
| ViewModel/ScreenMagnifier.swift | 屏幕放大镜 | 检查 |
| ViewModel/MousePointer.swift | 鼠标高亮 | 检查 |
| Info.plist | Sparkle 配置 | 是（URL + Key） |

### 2.3 现有版本检测

```swift
// QuickRecorderApp.swift:19-21
let isMacOS12 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 12
let isMacOS14 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 14
let isMacOS15 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 15
```

缺失 macOS 26/27 检测。代码中大量 `isMacOS12 ? A : B` 和 `isMacOS14 ? A : B` 硬编码分支。

**版本常量风格说明**：`isMacOS12/14/15` 用 `==` 是因为旧版本分支逻辑互斥（每个版本有独立的 padding/尺寸常量）。新增的 `isMacOS27` 将使用 `>=` 以自动覆盖未来版本，这是有意为之——macOS 28+ 应自动继承 macOS 27 的适配逻辑，无需每次手动添加新常量。

### 2.4 现有毛玻璃实现

| 位置 | 当前方案 |
|------|----------|
| ContentView.swift:35 | `.background(.ultraThinMaterial)` |
| PreviewView.swift:26 | `.background(.ultraThickMaterial)` |
| StatusBar.swift:33 | `Rectangle().fill(Color.mypurple)` 纯色 |
| AreaSelector.swift:89 | `Color(nsColor: NSColor.windowBackgroundColor)` 纯色 |
| CountdownView (ContentView.swift:304) | `Color.mypurple` 纯色 |
| 各浮动窗口 | `backgroundColor = .clear` |

## 3. macOS 27 平台变化

### 3.1 NSStatusItem 系统级 Bug（Apple 已确认）

| Bug ID | 描述 | 影响 |
|--------|------|------|
| FB23329983 | NSStatusItem 内视图不再接收 hover/mouse-movement 事件 | `onHover` 失效 → mini 模式按钮不显示；`hideMousePointer`/`hideScreenMagnifier` 无法触发 |
| FB23330269 | `NSStatusItem.button?.highlight(true)` 无效 | 无法程序化设置高亮胶囊 |
| FB23349447 | `occlusionState` 不再反映菜单栏真实可见性 | 浮动控制面板显示/隐藏逻辑崩溃 |

### 3.2 NSGlassContainerView 点击拦截（macOS 26+）

Liquid Glass 引入的 `NSGlassContainerView` 的 `hitTest:` 返回自身而非穿透到下层 SwiftUI Button，导致 NSHostingView 内的按钮点击无响应。

社区 workaround：swizzle `hitTest:`，当命中结果为自身时返回 nil。

### 3.3 Liquid Glass 强制适配

用 Xcode 27 SDK（macOS 27 SDK）编译的 App，系统忽略 `UIDesignRequiresCompatibility` / 任何 opt-out key。所有标准控件自动按 Liquid Glass 渲染。自定义控件需手动接入 `.glassEffect()` API。

### 3.4 新 API

| API | 平台 | 用途 |
|-----|------|------|
| `.glassEffect(_:in:)` | SwiftUI, macOS 26+ | 给任意视图附加玻璃材质，支持 cornerRadius/tint/intensity |
| `GlassEffectContainer` | SwiftUI, macOS 26+ | 多玻璃元素合并容器 |
| `.glassEffect(.regular.tint(_:).interactive())` | SwiftUI, macOS 26+ | 带色调 + 交互弹动的玻璃 |

> **实施注意**：`.interactive()` 的部分文档来源标注其为 iOS-only。macOS 27 WWDC session 提到"点击时 Glass 轻微弹动"，但 API 签名可能与 iOS 不同。实施时先验证 `.interactive()` 在 macOS 26+ SDK 中的可用性；如不可用，macOS 上省略 `.interactive()`（仅 tint + cornerRadius），或查找 macOS 对应的交互修饰符。
| `NSControlEvents` | AppKit, macOS 27+ | 标准控件事件响应（替代 mouseDown 追踪） |
| `NSViewCornerConfiguration` | AppKit, macOS 27+ | 自适应圆角配置 |
| `NSTextSelectionManager` | AppKit, macOS 27+ | 文本选择手势 |
| `scrollEdgeEffectStyle` | SwiftUI, macOS 26+ | 滚动边缘效果（27 上 auto 解析为 hard edge） |

### 3.5 macOS 27 设计变化

- 玻璃透明度用户可调（设置 > 外观），使用系统 `.glassEffect()` 自动响应。
- 窗口圆角弧度比 macOS 26 收敛。
- 侧边栏恢复 attached（非浮动）样式 + icon tinting。
- 菜单栏图标精简。
- 新增 Glass 点击弹动效果（interactive）。

## 4. 设计方案

### 4.1 Phase 1：基础设施

#### 4.1.1 版本检测常量

在 QuickRecorderApp.swift 中新增：

```swift
let isMacOS26 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
let isMacOS27 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
```

保留现有 `isMacOS12/14/15`。所有新增的 macOS 26/27 分支使用这些常量或 `#available(macOS 26, *)` / `#available(macOS 27, *)`。

#### 4.1.2 Xcode 项目配置

- `MACOSX_DEPLOYMENT_TARGET`：保持 `12.3`。
- `SWIFT_VERSION`：保持 `5.0`（Swift 5 语言模式），用 Xcode 27 SDK 编译。
- `LastUpgradeCheck`：更新到 `1700`。
- 不启用 Swift 6 并发检查（避免大量 Sendable 改动）。

#### 4.1.3 Sparkle 更新配置

- `Info.plist` 的 `SUFeedURL` 改为 fork 仓库的 appcast.xml raw URL。
- `SUPublicEDKey` 用 fork 维护者的 EdDSA 公钥重新生成。
- `appcast.xml` 中的下载 URL 和版本号同步更新。

**EdDSA 密钥生成与保管**：使用 Sparkle 附带的 `generate_keys` 工具（位于 Sparkle 框架的 `bin/` 目录）生成密钥对。私钥自动存入 macOS Keychain（Sparkle 默认行为），公钥输出到终端，手动写入 `Info.plist` 的 `SUPublicEDKey`。私钥不可泄露，否则更新机制可被中间人攻击。

#### 4.1.4 Bundle ID 决策

当前 `PRODUCT_BUNDLE_IDENTIFIER = com.lihaoyun6.QuickRecorder`。Fork 分发面临选择：

| 方案 | 优点 | 缺点 |
|------|------|------|
| **保持原 Bundle ID** | 用户无需重新授权屏幕录制；偏好设置保留 | 与原版共存时 LaunchServices 混淆；两个 App 的 UserDefaults 共享同一域，设置互相干扰 |
| **修改 Bundle ID**（如 `com.<你的用户名>.QuickRecorder`） | 完全独立于原版；无冲突 | 用户需重新授权屏幕录制权限；所有偏好设置重置 |

**待用户决策**：是否修改 Bundle ID？如修改，需同步更新 `PRODUCT_BUNDLE_IDENTIFIER`、`Info.plist` 中的 `UTExportedTypeDeclarations` identifier、以及 `SCContext.swift` 中 `excludedApps` 列表对自身的排除引用。

### 4.2 Phase 2：菜单栏 Bug 修复

#### 4.2.1 修复 onHover 失效（FB23329983）

**文件**：StatusBar.swift

**问题**：`.onHover` 在 macOS 27 NSStatusItem 内不触发，`isHovering` 永远为 false。mini 模式下按钮只在 `isHovering == true` 时显示，导致暂停/停止按钮完全消失。

**方案**：

```swift
// macOS 27+：mini 模式始终显示按钮，不依赖 hover
// macOS 26-：保留原有 hover 展开/收起逻辑
if miniStatusBar {
    if isMacOS27 || isHovering {
        // 显示 stop/pause/camera 按钮
    } else {
        // 仅显示录制时间
    }
}
```

`hideMousePointer` / `hideScreenMagnifier` 在 macOS 27 上**不再基于 hover 隐藏**。原逻辑是"hover 菜单栏时隐藏"以避免它们出现在录制画面中；由于 macOS 27 hover 不可用，直接移除 hover 关联，接受鼠标高亮/放大镜可能短暂出现在录制画面中。这是系统限制下的合理取舍。

#### 4.2.2 修复 occlusionState 失效（FB23349447）

**文件**：StatusBar.swift:138-155

**问题**：`statusBarItem.button?.window?.occlusionState.contains(.visible)` 在 macOS 27 上不反映真实菜单栏可见性，浮动 "Recording Controller" 面板的显示/隐藏逻辑崩溃。

**方案**：macOS 27 上不再依赖 occlusionState。改为通过 `NSScreen` 的 `visibleFrame` 与 `frame` 高度差判断菜单栏是否被自动隐藏：

```swift
if isMacOS27 {
    // 仅在菜单栏被系统自动隐藏时才显示浮动控制面板
    // visibleFrame.maxY < frame.maxY 说明菜单栏占位（可见）；否则被自动隐藏
    if SCContext.streamType != nil && !mainPanelIsVisible && !menuBarIsVisible {
        showControlPanel()
    }
} else {
    // macOS 26-：保留原有 occlusionState 逻辑
}
```

`mainPanelIsVisible` 通过检查 `NSApp.windows` 中是否存在标题为 "QuickRecorder" 的可见窗口来判断。`menuBarIsVisible` 通过 `NSScreen.main.visibleFrame.maxY < NSScreen.main.frame.maxY` 判断。

#### 4.2.3 修复 NSGlassContainerView 点击拦截

**文件**：QuickRecorderApp.swift（AppDelegate.applicationWillFinishLaunching）

**问题**：macOS 26+ 的 NSGlassContainerView 拦截点击，SwiftUI Button 无响应。

**方案**：

```swift
if #available(macOS 26, *) {
    enableGlassContainerClickThrough()
}

func enableGlassContainerClickThrough() {
    guard let cls = NSClassFromString("NSGlassContainerView"),
          let method = class_getInstanceMethod(cls, #selector(NSView.hitTest(_:))) else { return }
    // swizzle hitTest: 当返回自身时返回 nil
    // ...
}
```

标注为临时方案，添加 `// TODO: Remove when Apple fixes NSGlassContainerView hitTest` 注释。建议加版本上限守卫（如仅在 macOS 26.0-27.x 生效），待 Apple 修复后移除。

#### 4.2.4 移除空 onTapGesture

**文件**：StatusBar.swift:216

**问题**：`.onTapGesture {}` 空手势处理器可能干扰子视图按钮点击。

**方案**：macOS 27 分支中移除。macOS 26- 保留（不确定是否有其他副作用）。

#### 4.2.5 StatusBarItem 尺寸适配

**文件**：StatusBar.swift:233-234, QuickRecorderApp.swift:434-444

**问题**：padding 和 frame 高度硬编码 `isMacOS14 ? -2 : -1` 和 `isMacOS14 ? 22 : 21`。macOS 27 菜单栏高度和 Liquid Glass 渲染可能不同。

**方案**：新增 `isMacOS27` 分支，初始值参考 macOS 26 实测结果调整。`getStatusBarWidth()` 中的宽度常量也需验证。

### 4.3 Phase 3：Liquid Glass 全面适配

#### 4.3.1 适配策略

所有 Glass 适配遵循统一模式：

```swift
// macOS 26+：Liquid Glass
if #available(macOS 26, *) {
    view.glassEffect(.regular.tint(tintColor).interactive(), in: .rect(cornerRadius: radius))
} else {
    // macOS 12-15：回退到现有方案
    view.background(.ultraThinMaterial) // 或纯色
}
```

封装为 View extension 减少重复：

```swift
extension View {
    @ViewBuilder
    func qrGlassBackground(tint: Color? = nil, cornerRadius: CGFloat = 8, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            var glass = Glass.regular
            if let tint { glass = glass.tint(tint) }
            if interactive { glass = glass.interactive() }
            self.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial).cornerRadius(cornerRadius)
        }
    }
}
```

#### 4.3.2 主面板（ContentView / ContentViewNew）

**ContentView.swift:34-36**：

```swift
// 现状
Color.clear.background(.ultraThinMaterial).environment(\.controlActiveState, .active)

// 改为
if #available(macOS 26, *) {
    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 14))
} else {
    Color.clear.background(.ultraThinMaterial).cornerRadius(14)
}
```

**SelectorView hover 高亮（ContentView.swift:290-293）**：

```swift
// 现状
.background(.primary.opacity(backgroundOpacity))

// macOS 26+ 改为
if #available(macOS 26, *) {
    .glassEffect(.regular.tint(.primary.opacity(0.15)).interactive(), in: .rect(cornerRadius: 8))
} else {
    .background(.primary.opacity(backgroundOpacity))
}
```

ContentViewNew.swift 同理。

#### 4.3.3 菜单栏控件（StatusBar）

**StatusBar.swift:32-35**（录制中背景）：

```swift
// 现状
Rectangle().fill(Color.mypurple).shadow(...).cornerRadius(4)

// macOS 26+ 改为
if #available(macOS 26, *) {
    Rectangle().fill(Color.clear)
        .glassEffect(.regular.tint(Color.mypurple).interactive(), in: .rect(cornerRadius: 4))
} else {
    Rectangle().fill(Color.mypurple).shadow(...).cornerRadius(4)
}
```

camera 按钮（StatusBar.swift:163-169）和 idevice 按钮（StatusBar.swift:177-185）同理，用 `.glassEffect(.regular.tint(color).interactive())`。

#### 4.3.4 预览窗口（PreviewView）

**PreviewView.swift:25-28**：

```swift
// 现状
Color.clear.background(.ultraThickMaterial).cornerRadius(6)

// macOS 26+ 改为
if #available(macOS 26, *) {
    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 6))
} else {
    Color.clear.background(.ultraThickMaterial).cornerRadius(6)
}
```

#### 4.3.5 区域选择器（AreaSelector）

**AreaSelector.swift:89**：

```swift
// 现状
Color(nsColor: NSColor.windowBackgroundColor).cornerRadius(10)

// macOS 26+ 改为
if #available(macOS 26, *) {
    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 10))
} else {
    Color(nsColor: NSColor.windowBackgroundColor).cornerRadius(10)
}
```

#### 4.3.6 设置窗口（SettingsView）

**SettingsView.swift:18-38**：

```swift
// 现状
NavigationView { List(selection:...) { ... }.listStyle(.sidebar) }

// macOS 26+ 改为
if #available(macOS 26, *) {
    NavigationSplitView {
        List(selection: $selectedItem) { ... }
            .listStyle(.sidebar)
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
} else {
    NavigationView { ... }
}
```

窗口配置（QuickRecorderApp.swift:69-86 Settings scene）：
- macOS 27 上侧边栏自动获得 attached 样式 + icon tinting（系统行为，无需代码）。
- Settings scene 的 detail ScrollView / Form 上添加 `.scrollEdgeEffectStyle(.soft)`（macOS 26+），使侧边栏滚动边缘获得柔和过渡。

#### 4.3.7 浮动窗口 Glass 化

**QuickRecorderApp.swift:279-310** 中的窗口：

| 窗口 | 现状 | macOS 26+ 改造 |
|------|------|----------------|
| camWindow | backgroundColor = .clear | contentView 添加 .glassEffect() |
| deviceWindow | backgroundColor = .clear | contentView 添加 .glassEffect() |
| controlPanel | backgroundColor = .clear | contentView 添加 .glassEffect(.regular.tint(Color.mypurple)) |
| countdownPanel | backgroundColor = .clear | CountdownView 背景改为 .glassEffect(.regular.tint(Color.mypurple).interactive()) |
| previewWindow | backgroundColor = .clear | PreviewView 已处理（4.3.4） |

cornerRadius 值需匹配 macOS 27 收敛后的圆角弧度（实测调整，初始参考值比 macOS 26 减小 2-4pt）。

#### 4.3.8 倒计时面板（CountdownView）

**ContentView.swift:304**：

```swift
// 现状
Color.mypurple.environment(\.colorScheme, .dark)

// macOS 26+ 改为
if #available(macOS 26, *) {
    Color.clear.glassEffect(.regular.tint(Color.mypurple).interactive(), in: .rect(cornerRadius: 10))
        .environment(\.colorScheme, .dark)
} else {
    Color.mypurple.environment(\.colorScheme, .dark)
}
```

#### 4.3.9 其他选择器窗口

ScreenSelector、WinSelector、AppSelector、iDeviceSelector、QmaPlayer、VideoEditor 中所有 `Rectangle().fill(...)` + `.cornerRadius(...)` 背景模式，统一用 `qrGlassBackground()` extension 替换。

具体替换点（非穷举，实施时 grep `Rectangle()` + `.fill(` + `.cornerRadius(` 定位）：

- ScreenSelector.swift:67-69
- WinSelector.swift:112-114
- AppSelector.swift:62-64
- QmaPlayer.swift:49-50, 70-71, 88-89, 111-112, 207-212, 259-264, 272-273
- VideoEditor.swift:142-144
- iDeviceSelector.swift:79
- CameraOverlayer.swift:191, 232

#### 4.3.10 用户可调透明度验证

macOS 27 设置 > 外观中的玻璃透明度滑块，使用系统 `.glassEffect()` API 后自动响应。需在最高透明度（最毛玻璃）和最低透明度（最透明）下验证：

- 文字/图标对比度可读（WCAG AA 标准）。
- 录制时间数字在菜单栏各种透明度下清晰可见。
- 按钮图标在低透明度下不与桌面背景混淆。

如对比度不足，对关键文字/图标添加 `.shadow` 或半透明底板。

### 4.4 Phase 4：收尾与验证

#### 4.4.1 ScreenCaptureKit 兼容性

用 Xcode 27 SDK 编译，检查 RecordEngine.swift 中的 deprecation warning：

- `SCStreamConfiguration(preset: .captureHDRStreamLocalDisplay)`（macOS 15+）
- `filter.includeMenuBar`（macOS 14.2+）
- `conf.capturesAudio`（macOS 13+）
- `SCShareableContent.getExcludingDesktopWindows`（检查 macOS 27 是否有新替代）

如有废弃 API，用 `#available` 分支替换为新 API。

#### 4.4.2 Presenter Overlay 兼容性

验证 CameraOverlayer.swift 中的 Presenter Overlay 功能在 macOS 27 上行为一致。

#### 4.4.3 多版本测试矩阵

| 测试项 | macOS 27 | macOS 26 | macOS 15 | macOS 14 | macOS 13 | macOS 12 |
|--------|----------|----------|----------|----------|----------|----------|
| 编译通过 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 |
| 录制/暂停/停止 | 必须 | 必须 | 回归 | 回归 | 回归 | 回归 |
| 菜单栏按钮点击 | 必须 | 必须 | 回归 | 回归 | 回归 | 回归 |
| 菜单栏 hover 交互 | N/A(系统Bug) | 回归 | 回归 | 回归 | 回归 | 回归 |
| Liquid Glass 视觉 | 必须 | 必须 | N/A | N/A | N/A | N/A |
| 浮动控制面板 | 必须 | 回归 | 回归 | 回归 | 回归 | 回归 |
| 设置窗口 | 必须 | 必须 | 回归 | 回归 | 回归 | 回归 |
| 预览弹窗 | 必须 | 必须 | 回归 | 回归 | 回归 | 回归 |

"必须" = 重点测试；"回归" = 确认不破坏；"N/A" = 不适用。

#### 4.4.4 版本号

- `MARKETING_VERSION`：`1.7.0`
- `CURRENT_PROJECT_VERSION`：`170`
- 更新 appcast.xml

## 5. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| NSGlassContainerView swizzle 被 Apple 修复后失效 | 点击穿透逻辑多余但无害 | 加版本上限守卫，定期复查 |
| macOS 27 beta API 变动 | 编译失败或行为异常 | 锁定 Xcode 27 正式版，beta 阶段不发布 |
| Swift 5 模式 + Xcode 27 SDK 的隐式行为变化 | 运行时异常 | 全版本回归测试 |
| Liquid Glass 在 NSHostingView 内动画卡顿 | 菜单栏控件视觉不流畅 | 减少 interactive() 使用，实测后决定 |
| macOS 12/13 测试环境难获取 | 低版本回归遗漏 | CI 虚拟机 + 社区测试反馈 |
| 用户可调透明度导致对比度不足 | 可读性问题 | 4.3.10 专项验证 |

## 6. 实施顺序

```
Phase 1（基础设施）
  ├── 1.1 版本检测常量
  ├── 1.2 Xcode 项目配置
  └── 1.3 Sparkle 更新配置
       │
Phase 2（菜单栏 Bug 修复）← 最高优先级
  ├── 2.1 onHover 失效修复
  ├── 2.2 occlusionState 失效修复
  ├── 2.3 NSGlassContainerView 点击穿透
  ├── 2.4 移除空 onTapGesture
  └── 2.5 StatusBarItem 尺寸适配
       │
Phase 3（Liquid Glass 适配）
  ├── 3.1 qrGlassBackground extension
  ├── 3.2 主面板
  ├── 3.3 菜单栏控件
  ├── 3.4 预览窗口
  ├── 3.5 区域选择器
  ├── 3.6 设置窗口
  ├── 3.7 浮动窗口
  ├── 3.8 倒计时面板
  ├── 3.9 其他选择器
  └── 3.10 透明度验证
       │
Phase 4（收尾）
  ├── 4.1 ScreenCaptureKit 兼容性
  ├── 4.2 Presenter Overlay 兼容性
  ├── 4.3 多版本测试
  └── 4.4 版本号与 appcast
```

Phase 2 可与 Phase 1 并行开始（2.3 依赖 1.1 的版本常量）。Phase 3 依赖 Phase 1 完成。Phase 4 依赖 Phase 2+3 完成。

## 7. 验收标准

1. 用 Xcode 27 编译无 error，无新增 deprecation warning（或已处理）。
2. macOS 27 上：录制/暂停/停止按钮点击正常响应，状态正确切换。
3. macOS 27 上：mini 模式始终显示按钮（不依赖 hover）。
4. macOS 27 上：浮动控制面板在录制中正确显示。
5. macOS 26+ 上：所有 UI 表面呈现 Liquid Glass 效果，响应系统透明度设置。
6. macOS 12-15 上：UI 回退到现有方案，功能不受影响。
7. Sparkle 更新检查指向 fork 仓库。
8. 版本号为 1.7.0 (build 170)。
