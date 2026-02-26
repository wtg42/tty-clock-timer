# sound-playback Specification

## Purpose
TBD - synced from change sound-setup.

## Requirements

### Requirement: 計時完畢播放音效
TUI MUST 在收到 `timer_finished` 事件且有音效設定時，非同步呼叫設定的播放器播放音效檔。播放失敗 MUST 靜默忽略，不影響計時主流程與畫面。

#### Scenario: 有音效設定時播放
- **WHEN** 計時完畢且音效設定中有有效的播放器與音效檔路徑
- **THEN** TUI MUST 以 `Bun.spawn([player, file])` fire-and-forget 方式非同步播放音效

#### Scenario: 無音效設定時靜默
- **WHEN** 計時完畢但無音效設定（用戶未執行 `--setup-sound`）
- **THEN** TUI MUST 不嘗試播放任何音效，正常顯示完畢動畫

#### Scenario: 播放失敗靜默忽略
- **WHEN** 音效播放的 spawn 呼叫失敗（播放器不存在、音效檔不存在等）
- **THEN** TUI MUST 不顯示錯誤訊息，繼續正常顯示完畢動畫
