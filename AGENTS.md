# UMengSDK_iOS 智能体协作说明

本仓库为友盟（UMeng）iOS SDK 的 SwiftPM 封装与分发仓库，属于与具体业务无关、可供多个 iOS 项目共用的第三方封装库。仓库只包含 `Package.swift`、维护脚本与文档，以 `binaryTarget(url:checksum:)` 引用友盟官方制品。

## 硬性约束

- **版本**：封装版本（tag）严格等于基础库 `UMCommon` 的版本，不带 `v` 前缀，发布后不可变；不得删除、移动或重打已发布的 tag（见 [ADR-0001](docs/adr/0001-package-version-follows-umcommon.md)）。
- **不转存二进制**：仓库与 GitHub Release 中不得提交或上传任何友盟 `.xcframework`、`.framework` 或压缩包，只能引用官方下载地址并校验 SHA-256（见 [ADR-0002](docs/adr/0002-reference-official-artifacts-only.md)）。
- **组件范围**：当前产品 `UMCommon` 只含 `UMCommon` 与随附组件 `UMDevice`；引入其他组件前须先与用户确认，发版节奏独立的组件优先另建仓库。
- **更新方式**：由用户人工触发，不建立定时轮询上游的自动化。升级使用 `scripts/bump.sh`；`Package.swift` 顶部的版本与校验值常量格式由脚本改写，不要改变其格式。
- **发布授权**：推送 `main`、打 tag、创建 GitHub Release 须获得用户明确授权。

## 验证

- 修改 `Package.swift`、脚本或 CI 后运行 `scripts/verify.sh`（校验清单、官方制品校验值/结构/签名/隐私清单、iOS Simulator 冒烟编译链接）。
- `.github/workflows/ci.yml` 在 push 到 `main` 与 PR 时运行同一脚本。

## 文档

- 使用与维护说明：[`README.md`](README.md)；版本对照：[`CHANGELOG.md`](CHANGELOG.md)。
- 文档与 Agent 规则使用简体中文；代码、命令、路径与标识符保持原样。

## Agent skills

### Issue tracker

本仓库的 Issue、规格说明与 Wayfinder 地图托管于 GitHub Issues（`jashanyng/UMengSDK_iOS`），通过 `gh` CLI 操作，不将外部 PR 作为分流入口（`**PRs as a request surface: no.**`）。详见 [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)。

### Triage labels

使用五个标准默认 triage 标签（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）。详见 [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md)。

### Domain docs

采用单上下文（single-context）布局：根目录 [`GLOSSARY.md`](GLOSSARY.md) 与 [`docs/adr/`](docs/adr/)。详见 [`docs/agents/domain.md`](docs/agents/domain.md)。
