#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "Usage: validate-required-gate.sh <detect-result> <required> <heavy-result> <platform>" >&2
  exit 2
fi

detect_result="$1"
required="$2"
heavy_result="$3"
platform="$4"

if [[ "${detect_result}" != "success" ]]; then
  echo "${platform} change detection failed: ${detect_result}" >&2
  exit 1
fi

case "${required}" in
  true)
    if [[ "${heavy_result}" != "success" ]]; then
      echo "${platform} validation was required but finished with: ${heavy_result}" >&2
      exit 1
    fi
    ;;
  false)
    if [[ "${heavy_result}" != "skipped" ]]; then
      echo "${platform} validation was not required but heavy job finished with: ${heavy_result}" >&2
      exit 1
    fi
    ;;
  *)
    echo "${platform} detector returned an invalid required value: ${required}" >&2
    exit 1
    ;;
esac

echo "${platform} required gate passed (required=${required}, heavy=${heavy_result})."

