# Implementation Tasks

## 1. 準備與內容蒐集

- [x] 1.1 審查 `packaging/appimage/README.md` 現有內容
- [x] 1.2 審查 `packaging/appimage/artifact-contract.md` 與 runtime contract 規範
- [x] 1.3 確認相關規格檔案位置與內容（appimage-packaging-workflow, core-tui-artifact-contract, unix-socket-ipc-bridge）

## 2. README.md 內容更新

- [x] 2.1 確定新章節在文檔中的位置（「快速開始」之後、「開發指南」之前）
- [x] 2.2 撰寫 AppImage 簡介與發佈目的段落（2-3 句）
- [x] 2.3 撰寫 AppImage 運行環境契約概述，包含指向 artifact-contract.md 的連結
- [x] 2.4 撰寫 socket path 動態生成機制說明（與 unix-socket-ipc-bridge spec 對應）
- [x] 2.5 撰寫 AppImage 構建與驗證快速參考，指向 `packaging/appimage/` 詳細文檔

## 3. 文檔連結與導航

- [x] 3.1 確認所有相對連結有效（`./packaging/appimage/`）
- [x] 3.2 確認連結目標文檔在版本庫中存在且可訪問

## 4. 驗證與最終檢查

- [x] 4.1 確認新內容不與現有章節重複
- [x] 4.2 確認文檔總長度合理（新增 100-150 行左右）
- [x] 4.3 驗證 Markdown 格式正確（標題層級、列表、連結）
- [x] 4.4 在本地渲染 README.md 確認排版美觀
