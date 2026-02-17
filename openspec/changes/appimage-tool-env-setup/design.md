## Context

`package-appimage.sh` 使用 `APPIMAGETOOL_BIN` 環境變數定位 appimagetool，預設 fallback 為 `appimagetool`（假設全域安裝）。但專案將工具放在 `packaging/tools/appimagetool.AppImage` 並以 gitignore 排除，導致不設環境變數就無法打包。

## Goals / Non-Goals

**Goals:**
- 腳本自動探測專案內的 appimagetool，零設定即可打包
- 保留環境變數覆蓋機制，不影響既有用法

**Non-Goals:**
- 不自動下載 appimagetool
- 不改變工具的存放位置或 gitignore 規則

## Decisions

### 探測順序

採用三層 fallback：

1. `APPIMAGETOOL_BIN` 環境變數（使用者明確指定）
2. `packaging/tools/appimagetool.AppImage`（專案內工具）
3. PATH 上的 `appimagetool`（全域安裝）

**理由**：環境變數優先保持向後相容；專案內路徑優先於 PATH 因為版本可控。

### 共用邏輯

將探測邏輯抽為 shell function，在 `package-appimage.sh` 和 `verify-artifact.sh` 中各自內嵌（不額外建立 shared script），因為邏輯僅 10 行左右，不值得增加檔案。

## Risks / Trade-offs

- [Risk] 專案內工具不存在且未全域安裝 → 報錯訊息明確提示下載路徑與環境變數設定方式
