#!/usr/bin/env bash
# Fetches and builds ungive/mediaremote-adapter (BSD-3-Clause) at a pinned version.
# Needs git and cmake (brew install cmake).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="v0.7.7"
DEST="$ROOT/Vendor/mediaremote-adapter"

if [ ! -d "$DEST/.git" ]; then
  git clone --recursive --depth 1 --branch "$VERSION" https://github.com/ungive/mediaremote-adapter.git "$DEST"
fi
cmake -S "$DEST" -B "$DEST/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$DEST/build" --config Release

if [ ! -d "$DEST/build/MediaRemoteAdapter.framework" ]; then
  echo "error: MediaRemoteAdapter.framework not found under $DEST/build" >&2
  find "$DEST/build" -maxdepth 3 -name "*.framework" >&2 || true
  exit 1
fi
echo "mediaremote-adapter $VERSION ready"
