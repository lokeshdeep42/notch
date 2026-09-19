#!/usr/bin/env bash
# Builds a debug app and launches it, replacing any running copy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pkill -x Sill 2>/dev/null || true
CONFIG="${CONFIG:-debug}" "$ROOT/Scripts/build.sh"
open "$ROOT/build/Sill.app"
echo "Logs: log stream --predicate 'subsystem == \"app.sill.Sill\"' --level debug"
