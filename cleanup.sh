#!/usr/bin/env bash
set -Eeuo pipefail

pkill -x ags 2>/dev/null || true
pkill -x awww-daemon 2>/dev/null || true

if command -v hyprpm >/dev/null 2>&1; then
	hyprpm disable hyprbars 2>/dev/null || true
fi
