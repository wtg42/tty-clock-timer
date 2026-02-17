# README AppImage Documentation

此變更為純文檔更新，整合現有規格內容到主 README.md，不涉及新建或修改系統 capabilities。

## 現有相關規格

以下規格已定義，本變更將其內容摘要集成到主 README：

- `appimage-packaging-workflow`: 定義 Linux x86_64 AppImage 打包流程
- `core-tui-artifact-contract`: 定義 Core 與 TUI runtime 的 artifact contract
- `unix-socket-ipc-bridge`: 定義 Unix Domain Socket IPC 機制與唯一 socket path 生成

## 文檔整合原則

- 主 README 提供高層次總結與概述
- 詳細步驟與指南留在 `packaging/appimage/` 專用文檔
- 使用相對連結導航至詳細文檔，避免內容重複
