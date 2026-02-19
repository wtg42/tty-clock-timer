## Context

**目前狀態**
- tty-clock-timer 使用 OpenTUI v0.1.79 搭配 Bun build + Solid JSX 轉換
- TUI bundle 策略已成熟：Bun plugin 處理 JSX 轉換、外部化原生 `.so`、產出獨立可執行檔
- 當前 AppImage 打包結合 Zig core + bundled TUI，大小已最佳化至 ~2.8MB

**升級背景**
- OpenTUI v0.1.80 發佈，包含穩定性改進（Grapheme 處理、input 緩衝、ScrollBox）
- 無官方宣告的 breaking changes
- 最低風險的升級類型（patch-level 穩定性修復）

## Goals / Non-Goals

**Goals:**
- 升級 `@opentui/core` 和 `@opentui/solid` 到 v0.1.80
- 驗證 build pipeline 在新版本中仍可正常工作
- 確保 TUI 基本功能（計時顯示、控制、鍵盤輸入）在新版本中無迴歸
- 驗證 AppImage 打包流程和最終產物的可用性

**Non-Goals:**
- 採用新的 OpenTUI API（HoverCursorStyle、DiffRenderable）
- 變更 build 策略或架構
- 性能最佳化或大小優化

## Decisions

### Decision 1: 升級流程 - 先驗證 build，再測試功能
**選擇**: 分階段驗證
- 第 1 步: 更新 package.json，執行 `bun install`
- 第 2 步: 執行 `bun run build`，驗證 bundle 成功產出
- 第 3 步: 測試基本 TUI 功能
- 第 4 步: 測試 AppImage 打包和執行

**理由**: 最小化升級失敗時的影響範圍。若 build 失敗，立即發現；若 bundle 成功但功能有問題，則問題隔離在 OpenTUI API。

**備選方案考慮**:
- 直接升級+全面測試：風險更高，無法隔離問題來源
- 逐個平台升級（Linux 先）：實踐上不必要，因為 OpenTUI 跨平台包均升級

### Decision 2: 原生包處理 - 維持外部化策略
**選擇**: 保持現有的 external native binding 設定
- build.ts 中的 external 列表保持不變（`@opentui/core-linux-x64` 等）
- Shim 生成邏輯保持不變（動態路徑解析）

**理由**: v0.1.80 未改變原生包命名和結構，無理由變更已驗證的策略。

**備選方案考慮**:
- 清理舊的 platform 包：可能漏掉某些 platform，風險更高

### Decision 3: 驗證範圍 - 重點在 bundle 和基本功能
**選擇**: 驗證清單
- ✓ Build 產出（bundle + .so + shim）
- ✓ JSX 轉換成功（無編譯錯誤）
- ✓ 時間顯示和更新
- ✓ 鍵盤控制（pause/resume/reset/quit）
- ✓ AppImage 執行（啟動、功能測試、大小對比）

**理由**: 專注於實際使用路徑，不測試已棄用或未使用的 API。

## Risks / Trade-offs

### Risk 1: Bun plugin API 改變
**風險**: v0.1.80 可能改變 `@opentui/solid/bun-plugin` 的 API，導致 build 失敗

**嚴重性**: 高（會完全阻擋升級）

**緩解**:
- 立即執行 build，若失敗檢查 plugin API 文件和發佈日誌
- 準備回滾至 v0.1.79 的方案（簡單：改 package.json + bun install）

### Risk 2: 原生包結構改變
**風險**: 新版本可能改變 `@opentui/core-*` 的命名或檔案位置

**嚴重性**: 中（可能導致 .so 複製失敗）

**緩解**:
- Build 完成後檢查 `tui/dist/` 中 `.so` 存在且大小合理
- 若缺失，檢查 node_modules 中原生包的實際路徑

### Risk 3: 隱藏的相容性問題
**風險**: v0.1.80 的 Grapheme/input 改進可能影響 TUI 渲染或鍵盤回應

**嚴重性**: 低（unlikely，但可能出現邊際情況）

**緩解**:
- 執行完整的 TUI 功能測試（倒計時、暫停、恢復、重設、結束）
- 若發現異常，詳細記錄並檢查 v0.1.80 的改變日誌

### Trade-off: 升級時間 vs 收益
**取捨**: 升級需要時間驗證，但穩定性改進的收益相對邊際

**決策**: 接受。依賴保持最新化是長期健康實踐。

## Migration Plan

### 執行步驟
1. **更新依賴**
   ```bash
   cd tui
   bun install
   ```

2. **驗證 build**
   ```bash
   bun run build
   # 檢查: dist/index.js, dist/libopentui.so, dist/node_modules/*/index.ts 存在
   ```

3. **測試 TUI 功能** (手動)
   - 啟動 tty-clock-timer（若有開發模式）
   - 驗證倒計時顯示
   - 測試鍵盤控制：p → paused, r → running, s → reset, q → quit

4. **測試 AppImage**
   ```bash
   cd packaging/appimage
   bash scripts/package-appimage.sh
   # 檢查: AppImage 產生，大小合理（~2.8MB±10%）
   ```

5. **執行應用**
   - 執行 AppImage，驗證 TUI 啟動
   - 快速功能檢查

### 回滾計劃
若升級失敗：
1. 還原 `tui/package.json` 至 v0.1.79
2. 執行 `bun install`
3. 重新 build

**預期回滾時間**: <5 分鐘

## Open Questions

- 是否應該測試所有 platform 的 build（Linux + macOS + Windows）？
  → 建議：先在開發環境測試，AppImage 只需 Linux 驗證
