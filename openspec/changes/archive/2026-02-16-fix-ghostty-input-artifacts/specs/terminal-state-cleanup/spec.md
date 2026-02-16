## ADDED Requirements

### Requirement: 程式退出後終端狀態必須還原
系統 MUST 在正常退出流程完成後還原終端互動狀態，使使用者可正常選取文字與繼續終端操作。

#### Scenario: 完成或手動退出後可正常選字
- **WHEN** 使用者在倒數期間或完成畫面退出程式
- **THEN** 退出後終端 MUST 保持可選取文字與正常輸入，不得殘留互動模式設定

### Requirement: 退出流程必須優先 graceful teardown
系統 MUST 優先執行 TUI 與 Core 的協調式收尾流程，僅在超時或不可恢復錯誤時才使用強制終止作為 fallback。

#### Scenario: quit 指令觸發協調式關閉
- **WHEN** 使用者送出 `quit` 命令
- **THEN** 系統 MUST 先完成 renderer/socket 清理，再結束進程；若清理逾時才可進入強制終止路徑
