# tty-clock-timer 協作指南

## OpenSpec 變更流程
所有功能/修正透過 OpenSpec 管理。常用指令：`/opsx:new`、`/opsx:ff`、`/opsx:apply`、`/opsx:archive`。

## Zig std 查詢（必須遵守）
遇到 Zig std 查詢，**必須先用本地 script**，禁止直接推測或搜尋網路：
- 模糊搜尋：`bash .opencode/skill/zig-std-index/scripts/search.sh <keyword>`
- 精確讀取：`bash .opencode/skill/zig-std-index/scripts/retrieve.sh <symbol>`

## 測試
`zig test <file> --test-filter "<pattern>"`

## Commit
英文、Conventional Commits（`feat:`、`fix:`、`docs:`、`refactor:`）

## 架構概覽
- `core/`：Zig，計時邏輯，透過 stdin/stdout JSON 訊息與 TUI 通訊
- `tui/`：Node.js/Bun + OpenTUI，終端機渲染
- Build：`zig build`（core）、`bun run build`（TUI bundle）
- Package：AppImage（`packaging/appimage/`）

## 其他
- `core/` 與 `tui/` 工具鏈獨立，請勿混用指令
- 回答使用**繁體中文**，技術術語保留英文
