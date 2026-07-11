#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DETECTOR="${SCRIPT_DIR}/detect-relevant-changes.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ttc-ci-detector.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

case_index=0

run_case() {
  local path="$1"
  local platform="$2"
  local expected="$3"
  case_index=$((case_index + 1))
  local repo="${TEST_ROOT}/case-${case_index}"

  mkdir -p "${repo}"
  (
    cd "${repo}"
    git init -q
    git config user.name "CI Detector Test"
    git config user.email "ci-detector@example.invalid"
    printf 'base\n' > README.md
    git add README.md
    git commit -qm base
    local base_sha
    base_sha="$(git rev-parse HEAD)"

    mkdir -p "$(dirname -- "${path}")"
    printf 'changed\n' > "${path}"
    git add "${path}"
    git commit -qm change
    local head_sha
    head_sha="$(git rev-parse HEAD)"

    local actual
    actual="$("${DETECTOR}" "${base_sha}" "${head_sha}" "${platform}")"
    if [[ "${actual}" != "required=${expected}" ]]; then
      echo "FAIL: path=${path} platform=${platform} expected=${expected} actual=${actual}" >&2
      exit 1
    fi
  )
}

run_case "core/src/main.zig" linux true
run_case "core/src/main.zig" macos true
run_case "tui/src/app.tsx" linux true
run_case "tui/src/app.tsx" macos true
run_case "packaging/appimage/README.md" linux true
run_case "packaging/appimage/README.md" macos false
run_case "packaging/macos/README.md" linux false
run_case "packaging/macos/README.md" macos true
run_case ".github/workflows/tag-driven-appimage-release.yml" linux true
run_case ".github/workflows/tag-driven-appimage-release.yml" macos true
run_case "docs/notes.md" linux false
run_case "docs/notes.md" macos false

if "${DETECTOR}" "" "missing" linux >/dev/null 2>&1; then
  echo "FAIL: missing SHA must fail closed" >&2
  exit 1
fi
if "${DETECTOR}" "missing" "also-missing" linux >/dev/null 2>&1; then
  echo "FAIL: unavailable commits must fail closed" >&2
  exit 1
fi
if "${DETECTOR}" "a" "b" windows >/dev/null 2>&1; then
  echo "FAIL: unsupported platform must fail closed" >&2
  exit 1
fi

echo "CI change detector tests passed (${case_index} path cases + fail-closed cases)"

