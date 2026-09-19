#!/usr/bin/env bash
# Builds Sill.app into ./build. Usage: Scripts/build.sh   (CONFIG=debug for a debug build)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
cd "$ROOT"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP="$ROOT/build/Sill.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN/Sill" "$APP/Contents/MacOS/Sill"
cp "$ROOT/App/Info.plist" "$APP/Contents/Info.plist"
for bundle in "$BIN"/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

# Now Playing helper (BSD-3-Clause). Built by Scripts/fetch-adapter.sh; optional.
ADAPTER="$ROOT/Vendor/mediaremote-adapter"
if [ -d "$ADAPTER/build/MediaRemoteAdapter.framework" ] && [ -f "$ADAPTER/bin/mediaremote-adapter.pl" ]; then
  cp -R "$ADAPTER/build/MediaRemoteAdapter.framework" "$APP/Contents/Frameworks/"
  cp "$ADAPTER/bin/mediaremote-adapter.pl" "$APP/Contents/Resources/mediaremote-adapter.pl"
  cp "$ADAPTER/LICENSE" "$APP/Contents/Resources/mediaremote-adapter-LICENSE.txt" 2>/dev/null || true
  echo "Bundled mediaremote-adapter"
else
  echo "note: mediaremote-adapter not built — Now Playing will use its fallback. Run Scripts/fetch-adapter.sh." >&2
fi

# Ad-hoc signature, inner components first. Release signing lives in docs/05-RELEASE.md.
if [ "${SKIP_SIGN:-0}" != "1" ]; then
  if [ -d "$APP/Contents/Frameworks/MediaRemoteAdapter.framework" ]; then
    codesign --force --sign - "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
  fi
  codesign --force --sign - "$APP"
fi

echo "Built $APP"
