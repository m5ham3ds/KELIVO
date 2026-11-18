# Kelivo — Android Edition

本仓库快照仅用于 Android 开发与 APK 构建。项目保留 Flutter/Dart 共享代码、Android 原生 Kotlin/Java 代码及 Android 资源；不包含 iOS、Windows、Linux、macOS 或 Web 应用目标。

## GitHub Actions 构建

推送新的 commit 或更新 Pull Request 时，**Android ARM64 Build & Comprehensive Report** 会自动运行；默认构建 `release`。也可以在 Actions 中手动运行并选择 `release` 或 `debug`。构建目标仅为 `arm64-v8a`。成功时上传 APK 和 SHA-256；无论构建成功或失败，报告 Job 都会尽力上传 `KELIVO_BUILD_REPORT.md` 和完整日志。

工具链：Flutter 3.47.6、Java 17、Android NDK 28.2.13676358、CMake 3.22.1。详细说明见 `ANDROID_BUILD_AR.md` 与 `ANDROID_ONLY_AUDIT.md`。

## 支持的界面语言

Kelivo 支持 English、Arabic（阿拉伯语，RTL 从右向左）、简体中文和繁體中文。当前阿拉伯语已覆盖 4,696 条应用消息中的 97.49%；技术标识符、协议名称、服务商品牌、代码示例及少量专业文本保留原始写法。CI 会检查语言键和占位符一致性。详情见 `docs/localization/ARABIC_STATUS.md`。

## License

See `LICENSE` and the license notices retained with vendored dependencies.
