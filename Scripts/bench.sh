#!/usr/bin/env bash
# Idle-cost benchmark: the product's headline number.
# Usage: Scripts/bench.sh [seconds]   (default 120). Leave the notch collapsed and the mouse still.
# Run with sudo to add powermetrics energy numbers.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DURATION="${1:-120}"
INTERVAL=5

PID="$(pgrep -x Sill || true)"
if [ -z "$PID" ]; then
  open "$ROOT/build/Sill.app"
  sleep 5
  PID="$(pgrep -x Sill)"
fi

SAMPLES=$(( DURATION / INTERVAL ))
echo "Sampling Sill (pid $PID) for ${DURATION}s. Hands off the mouse; keep the notch collapsed."

# The first `top` sample has no CPU delta, so take one extra and skip it.
top -l $(( SAMPLES + 1 )) -s "$INTERVAL" -pid "$PID" -stats pid,cpu,idlew,mem \
  | awk -v pid="$PID" '$1 == pid { n++; if (n > 1) { cpu += $2; w[n] = $3; mem = $4 } }
      END {
        if (n < 2) { print "not enough samples"; exit 1 }
        printf "Average CPU:      %.3f%%\n", cpu / (n - 1)
        printf "Idle wakeups:     first %s, last %s (per-sample counter from top)\n", w[2], w[n]
        printf "Memory (top MEM): %s\n", mem
      }'

RSS_KB="$(ps -o rss= -p "$PID" | tr -d ' ')"
echo "RSS:              $(( RSS_KB / 1024 )) MB"
echo "Budget:           CPU <= 0.1%, RSS < 80 MB, wakeups ~0"

if [ "$(id -u)" = "0" ]; then
  echo "powermetrics (energy impact):"
  powermetrics --samplers tasks --show-process-energy -i 5000 -n 6 | grep -E "^Name|Sill" || true
fi
