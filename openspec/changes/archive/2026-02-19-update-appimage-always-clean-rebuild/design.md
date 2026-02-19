## Context

目前 `package-appimage.sh` 只有在 `packaging/out/appimage/stage/usr/bin/tty_clock_timer` 不存在時才會觸發 `build-core.sh`，因此同一工作樹內若曾經建置過舊 binary，就可能在後續打包時被重用。這個行為在跨機器開發或切換分支後特別容易造成「程式碼已更新但 AppImage 仍是舊內容」的問題。

此外，既有流程雖然每次都會重新 `bun run build` 產出 TUI bundle，但 core 與 stage 目錄未強制 clean，造成打包輸入不是 deterministic。

## Goals / Non-Goals

**Goals:**
- 在每次執行 `package-appimage.sh` 時，固定清除專案內 build 產物並重建 core/TUI。
- 限制清理範圍在 repository 內（`core/`、`packaging/out/appimage/`、`tui/dist/`），避免影響使用者全域開發環境。
- 讓 manual release 與本地驗證流程都能穩定產出與當前 source tree 對齊的 AppImage。

**Non-Goals:**
- 不調整 AppImage 命名規則與版本策略。
- 不引入新的外部建置工具或 CI pipeline 變更。
- 不清除全域 cache（例如 Bun 全域快取或系統層級快取）。

## Decisions

- Decision: 將 `package-appimage.sh` 改為「先 clean、再 build、後 package」的固定流程。
  - Rationale: 直接在打包入口點強制一致流程，可避免呼叫端忘記先清理或重建。
  - Alternatives considered:
    - 僅調整 `build-core.sh` 強制重建：仍無法保證 stage/AppDir 舊檔案被清理。
    - 新增可選 flag（如 `--clean`）：預設路徑仍可能重現舊產物問題。

- Decision: 清理僅涵蓋 repo-local 產物（`core/zig-out`、`core/.zig-cache`、`packaging/out/appimage/stage`、`packaging/out/appimage/AppDir`、`tui/dist`）。
  - Rationale: 達成 deterministic build 同時避免破壞使用者全域環境與其他專案。
  - Alternatives considered:
    - 清除全域 Bun cache：可能導致不必要的套件重抓與網路不穩定風險。

- Decision: 保持 appimagetool 探測與輸出介面不變。
  - Rationale: 這次只修正產物新鮮度問題，避免擴大行為變更面。

## Risks / Trade-offs

- [建置時間增加] → 在文件明確標註這是為了確保產物正確性的刻意取捨。
- [I/O 與 CPU 負載增加] → 僅清理必要路徑，避免不必要的全域清理。
- [未來若新增其他中間產物路徑可能遺漏] → 在 README 中明確列出清理清單，變更時同步更新。

## Migration Plan

1. 更新 `package-appimage.sh`，加入 repo-local clean 步驟與強制重建流程。
2. 更新 `packaging/appimage/README.md` 的 manual release 說明，描述新預設行為與副作用。
3. 以 `APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/package-appimage.sh` 驗證可正常產出。
4. 以 `verify-artifact.sh` 驗證輸出檔案存在與命名正確。

Rollback:
- 若需回退，可還原 `package-appimage.sh` 與 README 至變更前版本，恢復舊的條件式 build 行為。

## Open Questions

- 目前無開放問題；如後續需兼顧速度，可再討論是否引入顯式 `--incremental` 模式。
