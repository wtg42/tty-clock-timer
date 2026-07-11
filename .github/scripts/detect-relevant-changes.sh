#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: detect-relevant-changes.sh <base-sha> <head-sha> <linux|macos>" >&2
}

if [[ "$#" -ne 3 ]]; then
  usage
  exit 2
fi

base_sha="$1"
head_sha="$2"
platform="$3"

if [[ -z "${base_sha}" || -z "${head_sha}" ]]; then
  echo "Error: base and head SHA are required." >&2
  exit 2
fi

case "${platform}" in
  linux | macos) ;;
  *)
    echo "Error: unsupported platform '${platform}'." >&2
    usage
    exit 2
    ;;
esac

if ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
  echo "Error: base commit is unavailable: ${base_sha}" >&2
  exit 1
fi
if ! git cat-file -e "${head_sha}^{commit}" 2>/dev/null; then
  echo "Error: head commit is unavailable: ${head_sha}" >&2
  exit 1
fi

changed_files="$(git diff --name-only "${base_sha}" "${head_sha}")" || {
  echo "Error: unable to compare ${base_sha}..${head_sha}." >&2
  exit 1
}

required=false
while IFS= read -r path; do
  [[ -z "${path}" ]] && continue

  case "${path}" in
    core/* | tui/* | .github/workflows/tag-driven-appimage-release.yml)
      required=true
      break
      ;;
  esac

  if [[ "${platform}" == "linux" ]]; then
    case "${path}" in
      packaging/appimage/* | .github/workflows/appimage-dry-run.yml | .github/scripts/detect-relevant-changes.sh | .github/scripts/detect-relevant-changes.test.sh)
        required=true
        break
        ;;
    esac
  else
    case "${path}" in
      packaging/macos/* | .github/workflows/macos-dry-run.yml | .github/scripts/detect-relevant-changes.sh | .github/scripts/detect-relevant-changes.test.sh)
        required=true
        break
        ;;
    esac
  fi
done <<< "${changed_files}"

echo "required=${required}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "required=${required}" >> "${GITHUB_OUTPUT}"
fi

