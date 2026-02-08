# quit-on-q Delta Specification

## MODIFIED Requirements

### Requirement: 單鍵 q 立即退出

系統 SHALL 在互動式 stdin（TTY）下，使用者按下單一字元 `q` 時透過 HTTP POST 請求通知 Server 停止，並關閉 TUI client；此行為在計時進行中與計時結束後一致。

#### Scenario: 計時進行中按下 q

- **WHEN** 使用者在倒數進行中按下單一字元 `q`（無換行輸入）
- **THEN** TUI 發送 `POST http://localhost:8080/stop` 請求，關閉 SSE connection，並退出程式

#### Scenario: 計時結束後按下 q

- **WHEN** 使用者在倒數結束後按下單一字元 `q`（無換行輸入）
- **THEN** TUI 發送 `POST http://localhost:8080/stop` 請求並退出程式

#### Scenario: Server 已停止時按下 q

- **WHEN** 使用者按下 `q` 但 Server 已不可達（無法連接或已關閉）
- **THEN** TUI 記錄錯誤到 stderr 但仍正常退出（不阻塞使用者退出）
