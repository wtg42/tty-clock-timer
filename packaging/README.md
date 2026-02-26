# Packaging

This directory contains packaging and release assets for `tty-clock-timer`. The current distribution target is **AppImage** (Linux x86_64).

## Directory Layout

```text
packaging/
├── README.md            <- this document
├── appimage/            <- AppImage scaffold, scripts, and assets
│   ├── README.md        <- AppImage detailed docs
│   ├── artifact-contract.md
│   ├── checklist.md
│   ├── release.md
│   ├── verification.md
│   ├── assets/          <- .desktop and icon files
│   └── scripts/         <- build / package / verify scripts
├── tools/               <- external tools (for example, appimagetool)
└── out/                 <- build outputs (git-ignored)
    └── appimage/        <- AppImage and intermediate artifacts
```

## Environment Requirements

| Tool | Version | Description |
|------|------|------|
| `zig` | 0.16+ | Builds the core binary |
| `bun` | 1.x | Required on host (used to install/build TUI bundle during packaging) |
| `appimagetool` | - | Packages AppDir into `.AppImage` (auto-discovered or auto-downloaded by scripts) |
| `gum` | - | Required for runtime interactive list/setup flows (auto-downloaded and bundled) |

You can download `appimagetool` from [GitHub Releases](https://github.com/AppImage/appimagetool/releases).

## Quick Start

```bash
# 1. Package AppImage (includes dependency checks + core/tui build)
APPIMAGE_VERSION=0.1.0 ./packaging/appimage/scripts/package-appimage.sh

# 2. Verify artifact
APPIMAGE_VERSION=0.1.0 ./packaging/appimage/scripts/verify-artifact.sh
```

Optional (for isolated core build debugging):

```bash
./packaging/appimage/scripts/build-core.sh
```

Output path: `packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage`

## FAQ

### What if `appimagetool` cannot be found?

`setup-deps.sh` / `package-appimage.sh` resolve `appimagetool` in this order:
1. Path specified by the `APPIMAGETOOL_BIN` environment variable
2. `packaging/tools/appimagetool.AppImage`
3. `appimagetool` found in system `PATH`
4. Auto-download to `packaging/tools/appimagetool.AppImage` (v1.9.1)

Recommended: put the downloaded binary at `packaging/tools/appimagetool.AppImage` and mark it executable.

### Why does packaging still require host `bun`?

`package-appimage.sh` builds TUI from source (`tui/`) before assembling AppDir, so host `bun` is required at packaging time. The final AppImage runs bundled `index.js` + `libopentui.so` from AppDir via core/TUI contract.

### How is `gum` handled?

`setup-deps.sh` ensures `packaging/tools/gum/linux-x64/gum` exists and is executable (auto-download via `fetch-gum.sh` when missing). Packaging then bundles it into:

`usr/lib/tty-clock-timer/tools/gum/linux-x64/gum`

At runtime, `AppRun` exports `TTY_CLOCK_GUM_BIN` to that bundled path by default.

### How is `APPIMAGE_VERSION` used?

This environment variable controls output naming and version tags. If unset, it defaults to `dev`:

```bash
# Output: tty-clock-timer-dev-linux-x86_64.AppImage
./packaging/appimage/scripts/package-appimage.sh

# Output: tty-clock-timer-1.0.0-linux-x86_64.AppImage
APPIMAGE_VERSION=1.0.0 ./packaging/appimage/scripts/package-appimage.sh
```

### Can I delete the `out/` directory?

Yes. `packaging/out/` contains build artifacts and can be safely removed and rebuilt.

## Detailed Docs

- [AppImage packaging guide](appimage/README.md)
- [Release Playbook](appimage/release.md)
- [Artifact Contract](appimage/artifact-contract.md)
- [Packaging checklist](appimage/checklist.md)
- [Verification record](appimage/verification.md)
