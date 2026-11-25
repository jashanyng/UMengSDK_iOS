---
status: accepted
---

# ADR-0002：只引用友盟官方制品，不转存二进制

本仓库是公开仓库，而友盟 SDK 为闭源二进制，许可仅声明 “All rights reserved”，未授予第三方再分发权。我们决定：`Package.swift` 以 `binaryTarget(url:checksum:)` 直接引用友盟官方下载地址（阿里云 OSS `umplus-sdk-download.oss-cn-shanghai.aliyuncs.com`，即 CocoaPods 安装所用的同一地址）上的官方制品，并以 SHA-256 校验；**仓库、Release 附件中都不存放任何友盟二进制**。已在 Xcode 27.2 上验证 SwiftPM 可直接使用官方压缩包（即使其外层套有 `<组件>_<版本>/` 目录并带 `__MACOSX` 残留）。

## Considered Options

- **二进制提交到 git**：公开再分发；且 SwiftPM 会克隆完整历史，每版约 5.6 MB 的二进制持续累积，所有消费者都要承担。
- **二进制放 GitHub Release 附件**：仓库不膨胀、文件不可变，但仍是公开再分发。

## Consequences

- 若友盟下架某个旧版本制品，依赖该封装版本的项目将无法在全新环境解析；补救方式是升级到仍可下载的封装版本（实测数年前的 `UMCommon 7.1.0`、`UMDevice 2.0.0` 仍可下载）。
- 若友盟在同一地址替换文件，校验失败会阻断构建而不会引入被篡改的二进制；由于 tag 不可变（见 ADR-0001），只能通过发布新的封装版本恢复。
- `scripts/verify.sh` 会重新下载并核对已声明制品的校验值、结构、签名与隐私清单，可随时人工运行以发现上述情况。
- 官方压缩包内除真实的 `<组件>_<版本>/<组件>.xcframework` 外，还带有 `__MACOSX/<组件>_<版本>/<组件>.xcframework`（仅含 `._*` 资源叉文件）。Xcode 27.2 / 当前 SwiftPM 能正确选中真实框架；若旧版或未来工具链因此报“存在多个 xcframework”，由于官方制品不可修改，需要重新评估是否改为转存清理后的制品。
- 消费者首次构建需要能访问 GitHub 与阿里云 OSS；只有已有 SwiftPM 缓存时才能离线构建。
