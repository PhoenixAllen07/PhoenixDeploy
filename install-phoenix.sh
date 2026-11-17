#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v powershell.exe >/dev/null 2>&1; then
  echo 'Run this launcher in Git Bash on the Windows PC receiving the applications.' >&2
  exit 1
fi
WIN_DIR="$(cygpath -w "$HERE")"
exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${WIN_DIR}\\Install-PhoenixApps.ps1"
