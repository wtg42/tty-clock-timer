# AppImage Packaging Foundation

This directory provides the Linux x86_64 AppImage packaging foundation for `tty-clock-timer`, supporting a tag-driven primary release flow with a manual fallback path.

## Target and Output

- Target platform: `linux-x86_64`
- AppImage output directory: `packaging/out/appimage/`
- AppImage file pattern: `tty-clock-timer-<version>-linux-x86_64.AppImage`

## Directory Layout

```text
packaging/appimage/
├── README.md
├── artifact-contract.md
├── checklist.md
├── release.md
├── verification.md
├── assets/
│   ├── tty-clock-timer.desktop
│   └── tty-clock-timer.svg
└── scripts/
    ├── build-core.sh              # build Zig core binary
    ├── setup-deps.sh              # guardrail checks with auto dependency fetch
    ├── package-appimage.sh        # package AppImage (guardrail flow integrated)
    ├── verify-artifact.sh
    ├── mvp-smoke.ts
    └── timer-smoke.ts
```

## Guardrails and Dependency Management

### Automatic Dependency Checks (`setup-deps.sh`)

On first run of `package-appimage.sh`, the script **automatically executes** `setup-deps.sh` to check and fetch dependencies:

1. **appimagetool**: checks in this priority order
    - Environment variable `APPIMAGETOOL_BIN` (explicit user override)
    - Local path `packaging/tools/appimagetool.AppImage`
    - System path (`command -v appimagetool`)
    - If none are available -> automatically downloads the latest supported version (1.9.1) to the local path

2. **TUI dependencies**: checks whether `tui/node_modules` exists
    - Missing -> automatically runs `bun install` (requires `bun` installed)
    - Present -> skips install and reports ready

### Incremental Build Strategy

`package-appimage.sh` uses a **repo-local clean rebuild** strategy: each run clears the paths below, then rebuilds core and TUI.

- `packaging/out/appimage/stage`
- `packaging/out/appimage/AppDir`
- `core/zig-out`
- `core/.zig-cache`
- `tui/dist`

This strategy does not clear global caches (for example, Bun's global cache). It increases per-run packaging time in exchange for consistent artifacts across machines and branches.

### Common Issues and Fixes

#### ❌ appimagetool download fails (404)

**Cause**: outdated version URL or network connectivity failure.

**Fix**:
```bash
# Option 1: point to a known-good local binary
export APPIMAGETOOL_BIN=/path/to/your/appimagetool
APPIMAGE_VERSION=1.0.0 ./packaging/appimage/scripts/package-appimage.sh

# Option 2: download latest supported version from GitHub
mkdir -p packaging/tools
wget -O packaging/tools/appimagetool.AppImage \
  https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
chmod +x packaging/tools/appimagetool.AppImage
```

#### ❌ TUI dependencies not installed

**Cause**: after cloning on a new machine, TUI `node_modules` is missing.

**Fix**: `package-appimage.sh` auto-runs `setup-deps.sh`, so no manual action is required.
Or run manually:
```bash
cd tui && bun install && cd ..
```

## Release Modes

### Tag-driven (Primary)

- Trigger: push version tag（`v*`）
 - Trigger: push version tag (`v*`)
- Workflow: `.github/workflows/tag-driven-appimage-release.yml`
- Output assets:
  - `tty-clock-timer-<version>-linux-x86_64.AppImage`
  - `tty-clock-timer-<version>-linux-x86_64.AppImage.sha256`
  - `release-metadata-<version>.json`

### Manual (Fallback)

When CI or environment issues make the tag-driven flow unavailable, maintainers can deliver the same version manually via the fixed interfaces below.

### 1) Build Core Artifact

```bash
./packaging/appimage/scripts/build-core.sh
```

- Fixed input: `core/` source tree
- Fixed output: `packaging/out/appimage/stage/usr/bin/ttc`
- Note: `package-appimage.sh` runs this step automatically; this command is mainly for isolated core artifact checks.

### 2) Package AppImage Artifact

```bash
APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/package-appimage.sh
```

- Fixed input:
  - `core/` source tree (clean rebuild is enforced by the script)
  - `tui/` runtime tree
  - `packaging/appimage/assets/*`
- Fixed output: `packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage`

### 3) Verify Artifact Checklist

```bash
APPIMAGE_VERSION=<version> ./packaging/appimage/scripts/verify-artifact.sh
```

- Checks aligned with `checklist.md`: executable bit, naming, and required assets.

Prompt helper artifact is bundled at `AppDir/usr/lib/tty-clock-timer/tui/prompts/helper.js`.

### 4) MVP Runtime Smoke (Optional)

```bash
TTY_CLOCK_TUI_CWD="$(pwd)/packaging/appimage/scripts" \
TTY_CLOCK_TUI_ENTRY="timer-smoke.ts" \
./packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage --seconds 5

TTY_CLOCK_TUI_CWD="$(pwd)/packaging/appimage/scripts" \
TTY_CLOCK_TUI_ENTRY="mvp-smoke.ts" \
./packaging/out/appimage/tty-clock-timer-<version>-linux-x86_64.AppImage --seconds 20
```

## References

- Artifact contract: `packaging/appimage/artifact-contract.md`
- Release playbook: `packaging/appimage/release.md`
- MVP verification record: `packaging/appimage/verification.md`
