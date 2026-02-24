# tty-clock-timer Agent 指南

## OpenSpec 流程
所有變更透過 OpenSpec 管理。指令：`/opsx:new`、`/opsx:ff`、`/opsx:apply`、`/opsx:archive`。

## Zig std 查詢（必須遵守）
**必須先用本地 script，禁止推測或搜尋網路**：
- `bash .opencode/skill/zig-std-index/scripts/search.sh <keyword>`
- `bash .opencode/skill/zig-std-index/scripts/retrieve.sh <symbol>`

## 測試
`zig test <file> --test-filter "<pattern>"`

## Commit
英文、Conventional Commits

## 架構概覽
- `core/`：Zig，計時邏輯，stdin/stdout JSON IPC
- `tui/`：Node.js/Bun + OpenTUI，終端機渲染
- Build：`zig build` / `bun run build`

## 其他
- `core/` 與 `tui/` 工具鏈獨立
- 使用繁體中文，技術術語保留英文
