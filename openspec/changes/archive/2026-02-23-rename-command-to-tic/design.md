## Context

`tty-clock-timer` 二進制命名冗長，降低終端使用體驗。專案已確定極簡主義風格定位，需重命名為 `tic`。目前二進制名稱在 Zig build 配置、打包腳本、文檔和幫助文本中各處出現。

## Goals / Non-Goals

**Goals:**
- 將所有二進制構建輸出與命令引用從 `tty_clock_timer` 改為 `tic`
- 更新所有文檔示例、幫助訊息、AppImage 打包指令
- 確保 AppImage 中的二進制名稱也是 `tic`

**Non-Goals:**
- 提供向後兼容的別名（`tty-clock-timer` 作為舊名稱仍可使用）
- 支援多個命令別稱

## Decisions

### Decision 1: 二進制名稱改為 `tic`
**Why**: 短、有記憶點、符合極簡主義品牌定位
**Alternatives Considered**:
- `tty-timer`: 仍有 "tty-" 前綴，冗長
- `countdown`: 過於描述性，不符合簡潔風格
- 保留 `tty-clock-timer`: 違反簡潔目標

### Decision 2: 更新 Zig build.zig 中的產出名稱
**Why**: build 系統是權威源，所有後續文檔和打包都從此衍生
**Approach**: 修改 `build.zig` 的二進制輸出目標

### Decision 3: AppImage 中的二進制路徑保持契約
**Why**: 現有 `artifact-contract.md` 定義 `usr/bin/tty_clock_timer`，改為 `usr/bin/tic`
**Approach**: 更新打包腳本和契約文檔

## Risks / Trade-offs

| 風險 | 緩解 |
|------|------|
| 用戶升級後找不到舊命令 | 在文檔和 CHANGELOG 中明確標示 Breaking Change；提供遷移說明 |
| 現有腳本引用 `tty-clock-timer` 會破壞 | 同上；鼓勵用戶在升級前更新腳本 |
| 打包流程中遺漏某處引用 | 構建完後檢查所有產物確認名稱一致 |

## Migration Plan

1. 修改 Zig `build.zig` 二進制名稱
2. 更新 `core/src/main.zig` 中的幫助文本中的示例
3. 更新 README.md 中的所有命令示例
4. 更新 `packaging/appimage/artifact-contract.md` 和打包腳本
5. 驗證 AppImage 中的二進制名確實是 `tic`
6. 測試端到端功能

## Open Questions

- 要不要保留 symlink `tty-clock-timer → tic` 以向後兼容？（目前設計不提供）
