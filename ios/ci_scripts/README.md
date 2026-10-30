# Xcode Cloud

## 当前状态

仓库已提供 `ci_post_clone.sh`，并已在 App Store Connect 创建
[`iOS TestFlight Tags`](https://appstoreconnect.apple.com/teams/79bb68aa-4ff2-44fc-9cec-842c94f87544/xcode-cloud/products/6430b856-1780-483f-8cf1-4a7037a949de/workflows/9DEAD3C1-0C37-4A4A-94EC-EA947CA5C2E9)。
云端产品名称为 `Runner`，关联 App `1Panel Pro`（App ID `6782614307`）。
自动触发条件仅包含 `testflight/` 前缀的标签，归档 Scheme 为 `Runner`，分发准备方式为
`App Store Connect`；固定 Xcode `26.6 (17F113)` 和 macOS Tahoe `26.5.1 (25F80)`。
保留手动分支构建入口。已配置 **TestFlight Internal Testing - iOS** 后置动作，
将 `Archive - iOS` 产物自动分发到现有“内测组”（配置时 3 名成员）。

需要打包时，先将代码推送到 `origin`，再推送指向该提交的
新 `testflight/*` 标签；标签对应提交必须包含构建脚本和共享 Xcode Cloud manifest。
接入时云端起始构建号设为 `18`，后续由 Xcode Cloud 递增；配置时 TestFlight 中可见的
最新版本为 `1.1.4 (14)`。

脚本从 `.fvmrc` 读取固定 Flutter 版本（当前为 `3.44.2`），使用项目已启用的
Swift Package Manager，安装 iOS 引擎、Dart 依赖及需要的 CocoaPods 依赖，
然后生成 Release 构建配置。使用 `CI_BUILD_NUMBER` 同步主 App 和两个 Widget
扩展的构建号；版本号来自 `pubspec.yaml`。归档和签名交给 Xcode Cloud。

如已有 SDK，可通过 `FLUTTER_ROOT` 指定路径用于本地验证；脚本会检查版本必须与
`.fvmrc` 一致。云端默认自行下载，无需配置这个变量。

## 创建工作流

1. 在 Xcode 打开 `ios/Runner.xcworkspace`，选择共享的 `Runner` Scheme。
2. 进入 **Integrate → Create Workflow**（旧版 Xcode 为
   **Product → Xcode Cloud → Create Workflow**），选择 App `1Panel Pro`，Bundle ID
   `cc.xjpz.monodash`，团队 `AGQDQFK98K`，仓库 `xjpz/1panel`。
   若 Apple 尚未获得该仓库的访问权限，需要仓库所有者完成授权。
3. 工作流名称设为 `iOS TestFlight Tags`；项目路径选
   `ios/Runner.xcworkspace`，Scheme 选 `Runner`。
4. 删除默认的 Branch Changes 条件，添加 **Tag Changes**，仅匹配以
   `testflight/` 开头的标签（支持模式输入时填写 `testflight/*`）。
   不添加分支、PR 或定时触发条件。
5. 添加 **Archive → iOS → Any iOS Device**，配置为 `Release`，
   分发准备方式选 **App Store Connect**。当前固定 Xcode `26.6` 和
   macOS Tahoe `26.5.1`；Flutter `3.44.2` 与该组合仍需首次云端归档验证。
6. 在 App 的 Xcode Cloud 设置中检查 **Next Build Number**，接入时初始化为 `18`。
   此值应大于 App Store Connect 中已有的最高构建号；后续同时使用本地和云端上传时，
   继续检查两种构建号是否冲突。
7. 在 **Post-Actions → TestFlight Internal Testing** 中选择现有内部测试组。
   2026-10-30 已按用户明确授权选择“内测组”（3 名成员），关联 `Archive - iOS` 产物并保存。
   外部测试组和 App Store 正式发布需要另外配置。
8. 保存后检查起始条件、归档动作、签名和测试组。此步骤不要求立即运行构建。

不需要把 Apple 密钥、签名证书或本机 Flutter 路径写入仓库，也无需额外的自定义环境变量。

## 触发和验收

以下命令会推送标签并触发真实云构建，应在代码已提交、推送且需要打包时执行：

```bash
git tag testflight/1.1.7-20261030.2
git push origin testflight/1.1.7-20261030.2
```

每次发布使用新标签，不要移动已使用的标签。标签名用于触发，App 版本仍以
`pubspec.yaml` 为准。所有操作均针对 `origin`，不要推送到 `upstream`。

第一次云构建需要确认：

- Post-clone 日志显示固定 Flutter 版本，且依赖锁文件没有变更。
- Swift 包解析成功，Archive 成功，三个 Bundle 的版本号与构建号一致。
- App、Widget 和 Intents 扩展使用正确的 App Groups / iCloud / Keychain 权限并通过签名。
- 如配置 TestFlight，构建处理完成且出现在所选内部测试组。

本地脚本检查或无签名构建不代表云端归档、TestFlight 分发或真机运行已通过。

2026-10-30 本地验证：在临时仓库副本中，使用固定版本 Flutter `3.44.2` 执行
post-clone 脚本（复用临时 SDK，`CI_BUILD_NUMBER=18`），依赖安装、Swift 包解析、
CocoaPods 安装和 Release 配置生成均通过，四个依赖锁文件没有变化。
未执行签名归档或上传。Shell 语法和无效构建号的提前失败检查也已通过。

## 首次安装 Flutter 时的版本解析

首个云端构建在 post-clone 阶段出现 `JSONDecodeError`。旧脚本将
`flutter --version --machine` 的标准输出直接交给 JSON 解析器；新 SDK 初始化期间的
进度输出可能出现在版本 JSON 之前，因此不能把整个输出流当作一个 JSON 文档。
脚本现先运行该命令，再读取 Flutter 生成的 `bin/cache/flutter.version.json`。
初始化失败仍立即退出，不会继续使用旧版本缓存。

可用以下命令运行隔离回归检查（模拟 SDK 输出，不联网、不签名、不上传）：

```bash
python3 -m unittest discover -s scripts/tests -p 'test_xcode_cloud_post_clone.py' -v
```

检查覆盖带初始化日志的新 SDK、已有缓存的 SDK、版本不匹配、初始化失败时存在旧缓存，
以及版本缓存损坏。实际云端归档和分发仍应以对应构建记录为准。

## 参考

- [Flutter 官方 Xcode Cloud 配置](https://docs.flutter.dev/deployment/cd#xcode-cloud)
- [Apple 首个 Xcode Cloud 工作流](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
- [Apple 自定义构建脚本](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
