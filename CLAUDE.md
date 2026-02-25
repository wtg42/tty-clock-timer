# tty-clock-timer 協作指南

## OpenSpec 變更流程
所有功能/修正透過 OpenSpec 管理。常用指令：`/opsx:new`、`/opsx:ff`、`/opsx:apply`、`/opsx:archive`。

## Zig 開發規則（必須遵守）
- 使用 **Zig master**，API 與穩定版不同，禁止憑記憶或網路推測
- 只使用 `std`，無第三方套件
- **動工前必須先完成準備**，否則停下：
  1. 用本地 script 確認 std 有哪些可用函數
     ```
     bash .opencode/skill/zig-std-index/scripts/search.sh <keyword>
     bash .opencode/skill/zig-std-index/scripts/retrieve.sh <symbol>
     ```
  2. 讀懂專案中類似的現有實作，理解慣用模式

## 架構與構建
- **Core**（Zig）：計時邏輯，透過 JSON-delimited stdin/stdout 與 TUI 通訊
- **TUI**（Node.js/Bun + OpenTUI v0.1.81+）：終端渲染，編譯成單一 JS bundle
- **Build**：`zig build`（core）、`bun run build`（TUI）
- **Package**：`packaging/appimage/scripts/package-appimage.sh`（自動化全流程）

## 必知事項
- `core/` 與 `tui/` 工具鏈獨立，勿混用指令
- TUI bundle 後 node_modules 不需包含（只含 index.js + platform-specific .so shim）
- Commit 用英文 Conventional Commits 格式（`feat:`、`fix:`、`docs:`、`refactor:`）
