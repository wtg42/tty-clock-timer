## ADDED Requirements

### Requirement: 單鍵 q 立即退出
系統 MUST 在互動式 stdin（TTY）下，使用者按下單一字元 `q` 時立即結束程式，且不需要 Enter；此行為在計時進行中與計時結束後一致。

#### Scenario: 計時進行中按下 q
- **WHEN** 使用者在倒數進行中按下單一字元 `q`（無換行輸入）
- **THEN** 程式立即結束並停止計時更新

#### Scenario: 計時結束後按下 q
- **WHEN** 使用者在倒數結束後按下單一字元 `q`（無換行輸入）
- **THEN** 程式立即結束
