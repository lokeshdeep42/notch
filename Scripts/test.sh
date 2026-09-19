#!/usr/bin/env bash
# Runs the unit tests. Extra arguments go to `swift test` (e.g. --filter NotchStateTests).
set -euo pipefail
cd "$(dirname "$0")/.."
swift test "$@"
