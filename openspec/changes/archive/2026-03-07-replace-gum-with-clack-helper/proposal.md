## Why

目前 `gum` 以獨立 binary 的形式進入版本控制與 AppImage 打包流程，造成下載、校驗、artifact 驗證與跨流程維護成本。專案既有的 TUI 已經建立 Bun-based build/runtime 路徑，因此將 CLI prompt 互動收斂到 Bun helper 更能簡化依賴模型並降低 `gum` 的維護負擔。

## What Changes

- 以 Bun + `@clack/prompts` 建立獨立的 CLI prompt helper bundle，提供 Zig core 呼叫的互動入口。
- 將 history 單選、history 多選刪除、sound setup 互動流程從 `gum` 改為 prompt helper，並改用 JSON 作為 Zig 與 helper 之間的結果交換格式。
- 移除 `gum` binary、下載腳本、AppImage bundling 與相關驗證規則。
- 簡化互動架構：取消純 Zig fallback，改為將 prompt flow 正式視為 Bun runtime 的一部分。

## Capabilities

### New Capabilities
- `cli-prompt-helper`: 定義 Bun/Clack prompt helper 的 artifact 位置、子命令介面、JSON 回傳契約與取消/錯誤語義。

### Modified Capabilities
- `history-duration-selection`: 將 `list` 互動從 `gum` + 純文字 fallback 改為透過 prompt helper 完成。
- `list-delete-mode`: 將 `list --delete` 的多選刪除流程改為透過 prompt helper 完成。
- `sound-setup-cli`: 將 `--setup-sound` 的互動模式改為透過 prompt helper 完成。
- `appimage-packaging-workflow`: 移除 `gum` runtime artifact、下載腳本與 verify 規則，改為打包 prompt helper bundle。

## Impact

- `core/src/main.zig` 的 prompt spawn、取消判斷與錯誤處理邏輯。
- `tui/` 的 build pipeline、相依套件與 bundle 產物結構。
- `packaging/appimage/` 的 dependency setup、artifact copy、verify 與文件。
- OpenSpec 中與 history selection、delete mode、sound setup、AppImage packaging 相關的規格。
