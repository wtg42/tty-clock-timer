#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
LINUX_WORKFLOW="${ROOT_DIR}/.github/workflows/appimage-dry-run.yml"
MACOS_WORKFLOW="${ROOT_DIR}/.github/workflows/macos-dry-run.yml"
GATE="${SCRIPT_DIR}/validate-required-gate.sh"

ruby -e 'require "yaml"; ARGV.each { |path| YAML.parse_file(path) }' \
  "${LINUX_WORKFLOW}" "${MACOS_WORKFLOW}"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "${expected}" "${file}"; then
    echo "FAIL: ${file} does not contain: ${expected}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "${unexpected}" "${file}"; then
    echo "FAIL: ${file} unexpectedly contains: ${unexpected}" >&2
    exit 1
  fi
}

for workflow in "${LINUX_WORKFLOW}" "${MACOS_WORKFLOW}"; do
  assert_contains "${workflow}" "cancel-in-progress: true"
  assert_contains "${workflow}" "fetch-depth: 0"
  assert_contains "${workflow}" "if: always()"
  assert_contains "${workflow}" "contents: read"
  assert_contains "${workflow}" "detect-relevant-changes.sh"
  assert_contains "${workflow}" "validate-required-gate.sh"
  assert_not_contains "${workflow}" "contents: write"
  assert_not_contains "${workflow}" "    paths:"
done

assert_contains "${LINUX_WORKFLOW}" "name: appimage-required"
assert_contains "${LINUX_WORKFLOW}" "run: zig build test"
assert_contains "${LINUX_WORKFLOW}" "run: bun test --preload @opentui/solid/preload"
assert_contains "${LINUX_WORKFLOW}" "./packaging/appimage/scripts/package-appimage.sh"
assert_contains "${LINUX_WORKFLOW}" "./packaging/appimage/scripts/verify-artifact.sh"

assert_contains "${MACOS_WORKFLOW}" "name: macos-required"
assert_contains "${MACOS_WORKFLOW}" "run: zig build test"
assert_contains "${MACOS_WORKFLOW}" "run: bun test --preload @opentui/solid/preload"
assert_contains "${MACOS_WORKFLOW}" "./packaging/macos/scripts/verify-artifact.sh"
assert_contains "${MACOS_WORKFLOW}" "./packaging/macos/scripts/test-failures.sh"

"${GATE}" success true success Linux >/dev/null
"${GATE}" success false skipped Linux >/dev/null
"${GATE}" success true success macOS >/dev/null
"${GATE}" success false skipped macOS >/dev/null

for args in \
  "failure true skipped Linux" \
  "success true failure Linux" \
  "success true skipped macOS" \
  "success false success macOS" \
  "success invalid skipped Linux"; do
  if "${GATE}" ${args} >/dev/null 2>&1; then
    echo "FAIL: gate unexpectedly accepted: ${args}" >&2
    exit 1
  fi
done

echo "PR CI workflow and final-gate tests passed"

