## Context

目前 `package-appimage.sh` 第 41 行以 `cp -R "${TUI_SRC_DIR}"` 將整個 `tui/` 複製進 AppDir，包含 `node_modules`（~186MB）、test 檔案、`.gitignore` 等。TUI 使用 `bunfig.toml` 的 `preload = ["@opentui/solid/preload"]` 在執行時透過 Babel 做 Solid JSX 轉換。

`@opentui/solid` 已提供 `bun-plugin` export（`scripts/solid-plugin.ts`），可在 `Bun.build()` 建置時完成同樣的轉換。`@opentui/core` 透過 `bun:ffi` 載入 `@opentui/core-linux-x64/libopentui.so`（4.1MB），此 native binary 無法被 bundler inline。

## Goals / Non-Goals

**Goals:**
- 將 TUI 的 JS/TS 依賴打包為單一 bundle，消除 AppImage 對 `node_modules` 的依賴
- AppImage 產物大小從 ~190MB 降至 ~10MB
- 保持開發流程不變（`bun run dev` 仍用 preload 方式）

**Non-Goals:**
- 不使用 `bun build --compile`（standalone binary），保持彈性
- 不改變 core 與 TUI 之間的 IPC 協定
- 不處理跨平台（僅 linux-x64）

## Decisions

### Decision 1: 使用 `Bun.build()` API + solidTransformPlugin

使用 `@opentui/solid/bun-plugin` 提供的 plugin 搭配 `Bun.build()` 做建置時轉換。

**替代方案**：
- `bun build --compile`：產出 standalone binary，但 `bun:ffi` + `.so` 的支援不確定，風險較高
- 只排除 devDependencies：仍需帶 `node_modules`，效果有限

**理由**：Plugin 已存在且經過驗證（preload 版本天天在用），bundle 方式最乾淨。

### Decision 2: `libopentui.so` 作為外部檔案處理

`Bun.build()` 設定 `external: ["@opentui/core-linux-x64"]`（或等效處理），`.so` 檔案單獨複製到產物目錄。Bundle 執行時需能正確 resolve `.so` 路徑。

**理由**：Native binary 無法被 JS bundler 處理，必須作為外部資源。

### Decision 3: Build script 放在 `tui/build.ts`

新增 `tui/build.ts` 作為 build entry，可用 `bun run build` 觸發。產物輸出至 `tui/dist/`。

**理由**：與 TUI 原始碼同層，開發者可獨立測試 build 流程。

### Decision 4: `package-appimage.sh` 改為複製 build 產物

打包腳本改為：
1. 執行 `bun run build`（在 tui/ 下）
2. 複製 `tui/dist/` 內容至 AppDir
3. 單獨複製 `libopentui.so` 至 AppDir
4. 更新 `AppRun` 的 `TTY_CLOCK_TUI_ENTRY` 指向 bundle 檔案

## Risks / Trade-offs

- **[bun:ffi .so 路徑解析]** → 需驗證 bundle 後 `@opentui/core` 能否正確找到 `.so`。可能需在 build script 中做路徑重寫或用環境變數指定。
- **[OpenTUI 更新相容性]** → Bundle 鎖定了依賴版本，更新 OpenTUI 後需重新 build。這與目前行為一致（node_modules 也是鎖定版本）。
- **[Bundle 體積不確定]** → 實際 bundle 大小需建置後確認，預估數百 KB。
