## 1. AppImage Packaging Skeleton

- [x] 1.1 建立 `packaging/appimage` 目錄骨架與 README，定義 Linux x86_64 目標與輸出位置
- [x] 1.2 新增手動打包腳本介面（build/package 分工）並固定輸入輸出參數
- [x] 1.3 補齊 AppImage 產物檢查清單（可執行、檔名、必要資產存在）

## 2. Core-TUI Artifact Contract

- [x] 2.1 撰寫 artifact contract 文件，定義 core binary、TUI runtime artifact、路徑解析與啟動參數
- [x] 2.2 在 core 啟動流程中對齊 contract 欄位與錯誤訊息（缺 artifact、入口無效）
- [x] 2.3 驗證 AppImage 路徑環境下仍由 core 啟動 UI，不新增平行啟動路徑

## 3. IPC Unique Socket Path

- [x] 3.1 設計並實作每次執行唯一的 socket path 產生策略（含可清理）
- [x] 3.2 調整 IPC 初始化/重啟流程，處理殘留 socket 與衝突情境
- [x] 3.3 新增或更新測試案例，覆蓋多實例不衝突與錯誤可診斷行為

## 4. MVP Verification for Runnable AppImage

- [x] 4.1 產出 Linux x86_64 AppImage，確認可啟動主流程
- [x] 4.2 執行手動驗收：timer 功能可用、key commands 可用
- [x] 4.3 記錄驗收結果與已知限制，回填至 packaging 文件

## 5. Manual Release Foundation

- [x] 5.1 定義 manual release 步驟與必要前置檢查
- [x] 5.2 定義 release artifact 命名與附帶資訊（版本、平台、檢核摘要）
- [x] 5.3 建立後續自動化銜接備註（僅文件，不實作 CI/CD）
