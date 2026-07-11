# Packaging

This directory contains packaging and release assets for `tty-clock-timer`: **AppImage** for Linux x86_64 and a versioned **tarball** for macOS Apple Silicon.

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
├── macos/               <- macOS arm64 contract, launcher, and scripts
├── tools/               <- external tools (for example, appimagetool)
└── out/                 <- build outputs (git-ignored)
    ├── appimage/        <- AppImage and intermediate artifacts
    └── macos/           <- macOS tarball and intermediate artifacts
```

## Environment Requirements

| Tool | Version | Description |
|------|------|------|
| `zig` | master / 0.17-compatible | Builds the core binary |
| `bun` | 1.x | Required to install/build the TUI bundle and at runtime for both release artifacts; it is not embedded |
| `appimagetool` | - | Packages AppDir into `.AppImage` (auto-discovered or auto-downloaded by scripts) |

macOS packaging additionally requires a native Apple Silicon host (`Darwin arm64`). Linux x86_64 AppImage and macOS arm64 tarball releases both require Bun at runtime.

For a valid version tag, the release workflow builds, packages, and verifies both platforms before publishing either artifact. The resulting GitHub Release contains the Linux AppImage, macOS tarball, and a SHA-256 checksum for each.

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

For macOS Apple Silicon:

```bash
MACOS_VERSION=0.1.0 ./packaging/macos/scripts/package-macos.sh
MACOS_VERSION=0.1.0 ./packaging/macos/scripts/verify-artifact.sh
MACOS_VERSION=0.1.0 ./packaging/macos/scripts/test-failures.sh
```

Output path: `packaging/out/macos/tty-clock-timer-<version>-macos-arm64.tar.gz`

## FAQ

### What if `appimagetool` cannot be found?

`setup-deps.sh` / `package-appimage.sh` resolve `appimagetool` in this order:
1. Path specified by the `APPIMAGETOOL_BIN` environment variable
2. `packaging/tools/appimagetool.AppImage`
3. `appimagetool` found in system `PATH`
4. Auto-download to `packaging/tools/appimagetool.AppImage` (v1.9.1)

Recommended: put the downloaded binary at `packaging/tools/appimagetool.AppImage` and mark it executable.

### Why does packaging still require host `bun`?

`package-appimage.sh` builds TUI from source (`tui/`) before assembling AppDir, so host `bun` is required at packaging time. The final AppImage runs bundled `index.js`, `prompts/helper.js`, and `libopentui.so` from AppDir via core/TUI contract.

### How is the prompt helper handled?

`bun run build` produces a standalone prompt helper bundle at:

`tui/dist/prompts/helper.js`

Packaging copies that artifact into the AppImage runtime root at:

`usr/lib/tty-clock-timer/tui/prompts/helper.js`

At runtime, core resolves the helper from `APPDIR` or local `tui/dist/prompts/helper.js` fallbacks.

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
- [macOS packaging guide](macos/README.md)
- [macOS artifact contract](macos/artifact-contract.md)
