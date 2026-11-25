# UMengSDK_iOS 智能体协作说明

本仓库为友盟（UMeng）iOS SDK 的 SwiftPM 封装与分发仓库。

## Agent skills

### Issue tracker

本仓库的 Issue、规格说明与 Wayfinder 地图托管于 GitHub Issues（`jashanyng/UMengSDK_iOS`），通过 `gh` CLI 操作，不将外部 PR 作为分流入口（`**PRs as a request surface: no.**`）。详见 [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)。

### Triage labels

使用五个标准默认 triage 标签（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）。详见 [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md)。

### Domain docs

采用单上下文（single-context）布局：根目录 `GLOSSARY.md` 与 `docs/adr/`（在术语或架构决策敲定时按需创建）。详见 [`docs/agents/domain.md`](docs/agents/domain.md)。
