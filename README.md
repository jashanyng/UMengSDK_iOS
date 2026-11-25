# UMengSDK_iOS

为友盟（UMeng）iOS SDK 提供 Swift Package Manager 支持。友盟官方只提供 CocoaPods 与手动集成，本仓库以 SwiftPM 二进制目标直接引用**友盟官方下载地址**上的制品（不转存任何二进制），供多个 iOS 项目共用。

## 包含内容

| 产品 | 包含组件 | 说明 |
| --- | --- | --- |
| `UMCommon` | `UMCommon`（基础库）+ `UMDevice`（随附组件） | 自动声明系统库 `sqlite3`、`z`、`CoreTelephony`、`SystemConfiguration` |

- 最低要求：iOS 15，Swift tools 5.9（Xcode 15 及以上）。
- 暂不包含 `UMAPM`、推送、分享等其他组件。

## 版本规则

- **封装版本（tag）= 基础库 `UMCommon` 的版本**，例如 `7.7.0`（不带 `v` 前缀），发布后不可变。
- 每个封装版本随附的 `UMDevice` 版本见 [CHANGELOG.md](CHANGELOG.md) 与对应 GitHub Release 说明。
- 依据与取舍见 [ADR-0001](docs/adr/0001-package-version-follows-umcommon.md)、[ADR-0002](docs/adr/0002-reference-official-artifacts-only.md)；术语见 [GLOSSARY.md](GLOSSARY.md)。

## 接入

闭源 SDK 建议用 `exact` 锁定，升级时显式修改版本号：

```swift
dependencies: [
    .package(url: "https://github.com/jashanyng/UMengSDK_iOS.git", exact: "7.7.0")
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "UMCommon", package: "UMengSDK_iOS")
    ])
]
```

Xcode 工程：File → Add Package Dependencies…，输入 `https://github.com/jashanyng/UMengSDK_iOS.git`，Dependency Rule 选 “Exact Version”。

```swift
import UMCommon

UMConfigure.initWithAppkey("<AppKey>", channel: "<渠道>")
```

注意事项：

- **`-ObjC`**：友盟手动集成文档要求在 App target 的 `OTHER_LDFLAGS` 中添加 `-ObjC`。SwiftPM 不允许远程依赖使用 `unsafeFlags`，本包无法代为添加，请在使用方工程中自行配置。
- **隐私合规**：请在用户同意隐私政策后再调用 `UMConfigure.initWithAppkey`，并在 App Store 隐私声明中包含友盟收集的数据。官方制品自带 `PrivacyInfo.xcprivacy`。
- **网络**：首次解析会从友盟官方阿里云 OSS 下载制品，CI 或离线环境需能访问 `umplus-sdk-download.oss-cn-shanghai.aliyuncs.com`。

## 维护：发布新版本

友盟发布新的 `UMCommon` 后，由维护者人工执行：

1. 运行 `scripts/bump.sh <UMCommon 版本> [UMDevice 版本]`（省略 `UMDevice` 版本时取 CocoaPods trunk 最新正式版本）。脚本会下载官方制品、计算校验值、改写 `Package.swift`、在 `CHANGELOG.md` 插入一行，并运行 `scripts/verify.sh`。
2. 按脚本最后打印的命令提交、推送 `main`、打 tag 并创建 GitHub Release。
3. 在使用方项目中把 `exact` 版本改为新版本并验证。

- 仅 `UMDevice` 单独更新时不发布新版本，随下一次 `UMCommon` 发版一并带上。
- 任何时候都可运行 `scripts/verify.sh` 复核当前声明的官方制品仍可下载、校验值与签名一致；push 与 PR 会由 GitHub Actions 自动运行同一脚本。
