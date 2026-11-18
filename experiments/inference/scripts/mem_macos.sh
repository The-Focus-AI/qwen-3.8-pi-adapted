#!/usr/bin/env bash
# Print approx residency bytes for a llama-server PID or process name match.
# Usage: mem_macos.sh <pid>   OR   mem_macos.sh --name llama-server
set -euo pipefail
if [[ "${1:-}" == "--name" ]]; then
  pid=$(pgrep -x "${2:?}" | head -1 || true)
else
  pid=${1:?pid}
fi
[[ -z "${pid:-}" ]] && { echo 0; exit 0; }
# phys_footprint is the best unified-memory proxy on macOS
foot=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
# rss is KB; also try footprint via memory_pressure / footprint if available
if command -v footprint >/dev/null 2>&1; then
  bytes=$(footprint -p "$pid" 2>/dev/null | awk '/phys_footprint/{print $NF; exit}')
  if [[ -n "${bytes:-}" ]]; then echo "$bytes"; exit 0; fi
fi
# fallback: RSS KB * 1024 (underestimates GPU wired on some OS versions)
echo $(( ${foot:-0} * 1024 ))
