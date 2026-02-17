# AppImage Artifact Checklist

## A. Build and Package Readiness

- [ ] `core/` 可成功 `zig build -Dtarget=x86_64-linux -Doptimize=ReleaseSafe`
- [ ] `tui/` runtime artifact 已可被打包（含 `src/index.tsx`）
- [ ] `appimagetool` 可在當前環境執行

## B. Artifact Integrity

- [ ] 產生 `packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage`
- [ ] AppImage 檔案具可執行權限 (`chmod +x`)
- [ ] 檔名符合 `tty-clock-timer-<version>-linux-x86_64.AppImage`

## C. Bundled Assets Presence

- [ ] `AppDir/usr/bin/tty_clock_timer` 存在且可執行
- [ ] `AppDir/usr/lib/tty-clock-timer/tui/src/index.tsx` 存在
- [ ] `AppDir/AppRun` 存在且會轉呼叫 core binary
- [ ] `.desktop` 與 icon 資產存在

## D. MVP Runnable Checks

- [ ] AppImage 可啟動主流程
- [ ] timer 倒數流程可運作
- [ ] key commands（`p`/`r`/`s`/`q`）可運作

## E. Verification Record

- [ ] 驗收結果與限制已回填 `packaging/appimage/verification.md`
