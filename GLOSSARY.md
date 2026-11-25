# UMengSDK_iOS

本仓库为友盟（UMeng）iOS SDK 提供 Swift Package Manager 支持，供多个 iOS 项目共用。

## Language

**组件（Component）**：
友盟以独立 CocoaPods pod 发布、拥有独立版本号的单个 SDK 单元，例如 `UMCommon`、`UMDevice`、`UMAPM`。
_Avoid_: 模块、子库、友盟 SDK（泛指时有歧义）

**基础库（Base Component）**：
组件 `UMCommon`，即友盟统计的必需核心组件，其版本号决定本仓库的封装版本。
_Avoid_: 主库、核心库

**封装版本（Package Version）**：
本仓库发布的 SwiftPM 版本 tag，严格等于该次发布所含基础库的版本号（不带 `v` 前缀），发布后不可变。
_Avoid_: 友盟版本、SDK 版本、库版本

**官方制品（Official Artifact）**：
友盟在其官方下载地址发布的某个组件某个版本的 zip 压缩包；本仓库只以地址与校验值引用，不转存。
_Avoid_: 官方包、二进制包、镜像

**随附组件（Bundled Component）**：
随某个封装版本一同发布的非基础库组件（当前为 `UMDevice`）；其单独更新不产生新的封装版本，随下一次基础库更新一并发布。
_Avoid_: 依赖库、附属库
