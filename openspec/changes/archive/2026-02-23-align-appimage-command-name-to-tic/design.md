## Context

目前 `tic` 命令重命名已在 core 與 AppImage 打包主流程落地，但驗證腳本與 desktop entry 尚有舊命名 `tty_clock_timer`。這使得 CI verify 以不存在路徑作檢查而失敗，也讓 AppImage 的 desktop 啟動入口與系統命名規格不一致。

本次變更屬於「命名一致性修正」，影響範圍跨 OpenSpec 規格、打包產物驗證腳本與 desktop integration 設定。

## Goals / Non-Goals

**Goals:**
- 將 AppImage verify 的 core binary 檢查路徑與實際產物對齊為 `AppDir/usr/bin/tic`。
- 將 AppImage desktop entry 的 `Exec` 值改為 `tic`，與命令命名規範一致。
- 更新對應規格敘述，避免未來維護再引入 `tty_clock_timer` 舊路徑。

**Non-Goals:**
- 不變更 core binary 本體或 CLI 行為。
- 不調整 AppImage 結構、打包工具鏈或 release pipeline 階段順序。
- 不處理非 AppImage 範圍內的歷史命名殘留（例如舊 archive 變更文件）。

## Decisions

### 決策一：以現有 artifact contract 為唯一真實來源
- 決策：所有驗證與 desktop 啟動命名對齊 `packaging/appimage/artifact-contract.md` 已定義的 `usr/bin/tic`。
- 原因：contract 已明確定義 AppImage 內 core binary 唯一入口，避免腳本與打包流程各自維護不同命名。
- 替代方案：回退打包流程到 `tty_clock_timer`。不採用，因為會與 `cli-command-naming` 規格衝突並逆轉既有重命名成果。

### 決策二：以規格修正驅動腳本修正
- 決策：先更新 `appimage-packaging-workflow` 與 `cli-command-naming` delta specs，再依規格修正驗證與 desktop 設定。
- 原因：此次問題本質是「規格與實作不同步」，先補規格可避免僅修腳本但後續再度漂移。
- 替代方案：僅改腳本，不改 spec。短期可修 CI，但長期缺乏守護，容易回歸。

## Risks / Trade-offs

- [Risk] 舊版文件或外部使用者仍以 `tty_clock_timer` 啟動 AppImage → Mitigation：在 release 文件補充命名變更，並讓 verify 直接檢查 `tic`。
- [Risk] 部分測試或自動化仍硬編碼舊路徑 → Mitigation：以本次規格變更作為對齊依據，後續修正依賴腳本。
- [Trade-off] 將命名修正聚焦於 AppImage 範圍，未一次清理所有歷史文檔 → Mitigation：後續可另立 docs-only change 做全域清理。
