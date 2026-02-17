## Why

目前專案雖有 Zig + Embedded Node.js SEA 架構，但缺少可重複、可交付的 AppImage 打包基礎，導致 Linux 使用者無法快速取得可直接執行版本。先建立 Linux x86_64 的最小可行發佈流程，能在不破壞既有 core 啟動 UI 模式下，縮短手動發版時間並降低整合風險。

## What Changes

- 建立 `packaging/appimage` 骨架與必要腳本介面，先支援 Linux x86_64。
- 定義 core 與 TUI runtime 之間的 artifact contract（執行檔、埋入/載入資產、啟動約定、路徑約定）。
- 明確化 AppImage 內執行時的 IPC socket path 產生規則，要求每次執行具唯一性並可清理。
- 保持由 core 負責啟動 UI 的既有責任邊界，不改為由外部腳本直接啟動 UI。
- 設定 MVP 驗收：產出可執行 AppImage，能完成 timer 與 key commands 的基本流程。
- 發版策略先採 manual release，不在此變更中引入完整自動化發版。

## Capabilities

### New Capabilities

- `appimage-packaging-workflow`: 定義 Linux x86_64 AppImage 打包骨架、輸入輸出、與 MVP 可執行產物要求。
- `core-tui-artifact-contract`: 定義 core 與 TUI runtime 在打包/執行時的 artifact 介面契約與啟動責任邊界。

### Modified Capabilities

- `unix-socket-ipc-bridge`: 調整 IPC socket path 要求為執行實例唯一且適用 AppImage 執行環境。

## Impact

- `packaging/` 新增 AppImage 相關目錄、腳本與文件。
- `core/` 可能需最小調整以符合 artifact contract 與 socket path 規範。
- `tui/` 可能需配合 runtime artifact 載入位置或啟動參數契約。
- 影響發版作業流程（先手動），但不直接引入 CI/CD 自動發版依賴。
