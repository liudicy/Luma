<p align="center">
  <img src="img/luma-icon.png" width="112" alt="Luma 应用图标">
</p>
<h1 align="center">Luma</h1>
<p align="center">简洁、原生的 macOS 录屏工具。</p>
<p align="center"><a href="README.md">English</a> · <a href="https://github.com/liudicy/Luma/releases">下载版本</a> · <a href="https://github.com/liudicy/Luma/issues">反馈问题</a></p>

录制整个屏幕、一个窗口、某个应用，或你框选的一小块区域。Luma 将录制入口放进一个轻巧的面板，支持系统声音、麦克风与菜单栏控制，让录屏随手可用。

## 一个小面板，常用功能都在

<p align="center"><img src="img/screenshots/launcher-zh.png" width="1000" alt="Luma 录制主面板"></p>

- **自由选择来源**：屏幕、区域、窗口、应用、系统声音或受支持的移动设备。
- **同时录下声音**：无需虚拟声卡即可捕获系统声音，可加入麦克风，并保留独立音轨。
- **随时控制录制**：原生菜单栏暂停、继续、停止，也可使用浮动控制器、快捷键与定时停止。
- **调整录制效果**：H.264 / HEVC 编码、画质与帧率设置、摄像头叠加、鼠标高亮及放大镜。
- **方便收尾**：录制预览、视频裁剪和自定义保存目录。
- **贴近系统界面**：macOS 26 及以上采用 Liquid Glass，较旧系统使用材质背景。

## 界面预览

| 录制选项 | 录制控制 |
| :---: | :---: |
| <img src="img/screenshots/recording-settings-zh.png" width="520" alt="Luma 录制设置"> | <img src="img/screenshots/recording-menu-zh.png" width="240" alt="Luma 暂停状态下的原生录制菜单"> |

截图来自 macOS 27.0.1 上实际运行的 Luma 1.7.1，使用简体中文界面。

当前版本修复了权限处理流程，用原生菜单替换依赖悬停的菜单栏控制，修正暂停前后的音视频时间轴，并等待文件保存完成后再释放录制状态。H.265 小贴士会记住用户选择。已通过的验证及尚待验收的场景见[验证记录](docs/verification.md)。

## 开始录制

1. 打开 **Luma**，选择录制来源。
2. 根据提示在系统设置中允许「**屏幕与系统音频录制**」。使用麦克风或摄像头时再授予对应权限。
3. 选择目标并开始。点击菜单栏录制图标和计时，可暂停、继续或停止；选择「**显示录制控制器**」可打开浮动控制器。
4. 文件保存到你指定的目录，默认为桌面。

### 安装

当前源码版本为 **1.7.1**。可分发安装包发布后会列在 [Releases](https://github.com/liudicy/Luma/releases)。下载时请核对版本名称与说明，旧 QuickRecorder 安装包不包含本次 Luma 修改。也可以按下方步骤自行构建签名版本。

最低部署版本为 **macOS 12.3**。系统声音需要 macOS 13 及以上，演讲者前置需要 macOS 14 及以上，Liquid Glass 需要 macOS 26 及以上。编译需要 **Xcode 26 或更新版本**。旧系统、Intel 真机和外接录制设备仍需更多实测，最低部署版本不等于完整兼容承诺。

### 已开启权限，但仍提示无法录制

建议只保留一个安装副本，并固定放在 `/Applications/Luma.app`。在「**系统设置 → 隐私与安全性 → 屏幕与系统音频录制**」中启用 Luma；系统要求时，退出并重新打开应用。

本地构建请保持 Apple 签名身份一致。混用签名与无签名副本，可能导致已保存的授权失效，即使设置中的开关仍然开启。Luma 不会自动反复重试被拒绝的请求，也不会在拒绝授权后强制退出。

## 从源码构建

```sh
git clone https://github.com/liudicy/Luma.git
cd Luma
./Scripts/build_and_check_signing.sh
open build/signed-DerivedData/Build/Products/Release/Luma.app
```

脚本先对公开证书执行代码签名信任及在线 OCSP 撤销检查，再构建签名 Release 应用，不会运行证书测试程序。在 Xcode 中使用时，请在 **Signing & Capabilities** 中选择自己的开发团队。脚本不会创建证书，也不会为分发版本执行公证。`--reset-tcc` 会显式重置屏幕权限；`--prove` 是需要交互的重编译验证。

Xcode 项目及 target 保留 `QuickRecorder` 名称，应用标识保留 `com.liudicy.QuickRecorder`，以延续本分支的设置和授权身份。生成的应用名称为 **Luma**。Swift Package Manager 根据 `Package.resolved` 解析锁定的依赖。

```sh
# 运行暂停及音视频时间轴回归检查。
./Scripts/test_recording_timeline.sh
# 根据矢量绘制源码重新生成全部图标尺寸。
swift Scripts/generate_icon.swift
```

## 参与贡献

欢迎[提交问题](https://github.com/liudicy/Luma/issues)，请附上应用及 macOS 版本、安装或签名方式、录制模式、音频设置和复现步骤，并说明是否发生在暂停继续或变更权限之后。请避免上传包含隐私的录屏。

## 开源声明

Luma 是基于 [lihaoyun6](https://github.com/lihaoyun6) 及其贡献者创作的 [QuickRecorder](https://github.com/lihaoyun6/QuickRecorder) 独立维护的分支，继续采用 **GNU AGPL 第 3 版**。原始 [LICENSE](LICENSE) 全文及源码版权声明均予以保留；Luma 的修改与新图标采用相同协议。

[NOTICE](NOTICE) 记录项目来源及包含 Azayaka 衍生代码的说明，[THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) 收录依赖许可证与版权信息。这三个文件同时随应用打包。本项目维护地址为 [liudicy/Luma](https://github.com/liudicy/Luma)。
