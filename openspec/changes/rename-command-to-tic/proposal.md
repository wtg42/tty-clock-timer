## Why

終端工具的命令名越短越好，每次使用都要打 `tty-clock-timer` 會降低開發者體驗。`tic`（取自 "tick"）簡潔、易記、符合極簡主義風格，能讓工具更好用。

## What Changes

- 重命名二進制從 `tty_clock_timer` 改為 `tic`
- 更新 CLI 幫助文本中的所有命令示例
- 更新 README.md、打包腳本、AppImage 中的引用
- **BREAKING**: 現有使用 `tty-clock-timer` 或 `tty_clock_timer` 的用戶需要改用 `tic`

## Capabilities

### New Capabilities
- `cli-command-naming`: 短命令介面設計

### Modified Capabilities
- `cli-help-default-behavior`: help 文本中的命令名範例需從 `tty_clock_timer` 改為 `tic`

## Impact

- **二進制名稱**: Core binary 重命名
- **文檔**: README、幫助文本、示例都需更新
- **打包**: AppImage 構建腳本、Zig build 配置需調整
- **用戶遷移**: Breaking change，現有用戶需知會
