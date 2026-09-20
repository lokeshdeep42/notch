#!/usr/bin/env bash
# Headless smoke test: launch the built app, prove it survives, photograph it, quit it cleanly.
#
# Runs anywhere macOS runs, including a CI runner with no notch and one virtual display. It catches
# what the unit tests cannot see — crash on launch, a malformed Info.plist, a missing bundled
# resource, a helper process left behind on quit — and nothing more. It is NOT a substitute for
# docs/VERIFY-ON-MAC.md: no notch hardware means no notch geometry, no hover, no real energy figure.
#
# Usage: Scripts/smoke.sh [settle-seconds]   (default 12). Output lands in build/smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Sill.app"
OUT="$ROOT/build/smoke"
SETTLE="${1:-12}"
BUNDLE_ID="app.sill.Sill"

if [ ! -d "$APP" ]; then
  echo "error: $APP not built — run Scripts/build.sh first" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
pkill -x Sill 2>/dev/null || true

# Start from a known state, but skip onboarding: the screenshot should show the panel, not a
# first-run window, and an unattended run has nobody to click Skip.
defaults delete "$BUNDLE_ID" 2>/dev/null || true
defaults write "$BUNDLE_ID" HasCompletedOnboarding -bool YES

# Run the binary inside the bundle rather than `open`, so its stdout/stderr are ours to keep:
# an AppKit or SwiftUI fault usually prints there before anything reaches the unified log.
"$APP/Contents/MacOS/Sill" > "$OUT/stdout.log" 2>&1 &
PID=$!
echo "launched pid $PID — settling for ${SETTLE}s"
sleep "$SETTLE"

if ! kill -0 "$PID" 2>/dev/null; then
  STATUS=0
  wait "$PID" 2>/dev/null || STATUS=$?
  echo "FAIL: Sill exited within ${SETTLE}s (status $STATUS)" >&2
  echo "--- stdout/stderr ---" >&2
  sed -n '1,80p' "$OUT/stdout.log" >&2
  exit 1
fi
echo "PASS: still running after ${SETTLE}s"

# Indicative only: a VM's numbers are not the hardware budget in CLAUDE.md, but a tenfold
# regression would still show up here.
ps -o pid=,rss=,pcpu=,etime= -p "$PID" | tee "$OUT/ps.txt"
RSS_KB="$(ps -o rss= -p "$PID" | tr -d ' ')"
echo "RSS: $(( RSS_KB / 1024 )) MB (budget on hardware: < 80 MB)"

# The window server may not be reachable in every environment; a missing screenshot is not a
# failure, it just means this runner cannot show us the panel.
if screencapture -x "$OUT/screen.png" 2>"$OUT/screencapture.err"; then
  echo "captured $OUT/screen.png"
else
  echo "note: screencapture unavailable — $(tr -d '\n' < "$OUT/screencapture.err")"
fi

log show --predicate "subsystem == \"$BUNDLE_ID\"" --last 5m --info --debug \
  > "$OUT/sill.log" 2>/dev/null || echo "note: unified log unavailable"
if [ -s "$OUT/sill.log" ]; then
  echo "--- app log (last 20 lines) ---"
  tail -20 "$OUT/sill.log"
fi

# Clean quit, then the QA checklist's "no helper processes left behind" rule.
kill -TERM "$PID" 2>/dev/null || true
for _ in $(seq 1 20); do
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$PID" 2>/dev/null; then
  echo "FAIL: Sill ignored SIGTERM" >&2
  kill -9 "$PID" 2>/dev/null || true
  exit 1
fi

LEFTOVER="$(pgrep -fl 'mediaremote-adapter.pl' || true)"
if [ -n "$LEFTOVER" ]; then
  echo "FAIL: helper processes survived quit:" >&2
  echo "$LEFTOVER" >&2
  pkill -f 'mediaremote-adapter.pl' 2>/dev/null || true
  exit 1
fi

defaults delete "$BUNDLE_ID" 2>/dev/null || true
echo "smoke test passed: launched, ran ${SETTLE}s, quit cleanly, no helpers left behind"
