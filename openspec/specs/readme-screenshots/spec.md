## ADDED Requirements

### Requirement: README 中顯示產品截圖

README.md 應在標題下方展示 tty-clock-timer 的運行截圖，幫助使用者快速理解產品外觀與功能。截圖應放在簡短的自我介紹之上，作為視覺錨點。

#### Scenario: 截圖在標題下方可見

- **WHEN** 使用者開啟 README.md
- **THEN** 標題「tty-clock-timer」下方應顯示計時中的截圖圖片（相對路徑 `./assets/screenshots/timer-running.png`）

#### Scenario: 圖片尺寸適當

- **WHEN** 截圖在 GitHub 或本地閱讀時
- **THEN** 圖片應縮放至適當寬度（不過寬也不過窄），適應 README 排版

#### Scenario: 圖片下有簡潔說明

- **WHEN** 截圖顯示時
- **THEN** 圖片下方應有一句簡潔說明：「簡潔清晰的終端介面」

### Requirement: 建立截圖存放目錄

系統應提供標準化的視覺資源目錄結構，用於存放 README 及其他文件的截圖和圖片。

#### Scenario: 目錄結構存在

- **WHEN** 專案根目錄檢視
- **THEN** 應存在 `assets/screenshots/` 目錄結構，用於存放產品截圖

#### Scenario: 準備待驗證

- **WHEN** 變更實施完成
- **THEN** 應使用相對路徑連結至 `assets/screenshots/timer-running.png`，待圖片檔案手動放置後驗證
