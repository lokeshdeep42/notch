#!/usr/bin/env bash
# Idle-cost benchmark: the product's headline number.
# Usage: Scripts/bench.sh [seconds]   (default 120). Leave the notch collapsed and the mouse still.
# Run with sudo to add powermetrics energy numbers.
# Reports Sill itself AND its Now Playing helper (perl), because a helper process is part of the
# cost users see in their battery report.
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
HELPER="$(pgrep -f mediaremote-adapter.pl | head -1 || true)"

SAMPLES=$(( DURATION / INTERVAL ))
echo "Sampling for ${DURATION}s. Hands off the mouse; keep the notch collapsed."
echo "  Sill pid:   $PID"
echo "  helper pid: ${HELPER:-none (Now Playing off or using its fallback)}"

sample() {
  local pid="$1" label="$2"
  # The first `top` sample has no CPU delta, so take one extra and skip it.
  top -l $(( SAMPLES + 1 )) -s "$INTERVAL" -pid "$pid" -stats pid,cpu,idlew,mem \
    | awk -v pid="$pid" -v label="$label" '$1 == pid { n++; if (n > 1) { cpu += $2; w[n] = $3; mem = $4 } }
        END {
          if (n < 2) { printf "%s: not enough samples\n", label; exit 0 }
          printf "%-7s average CPU %.3f%% | idle wakeups (top IDLEW) first %s last %s | MEM %s\n",
                 label, cpu / (n - 1), w[2], w[n], mem
        }'
}

sample "$PID" "Sill" &
if [ -n "$HELPER" ]; then sample "$HELPER" "helper" & fi
wait

RSS_KB="$(ps -o rss= -p "$PID" | tr -d ' ')"
echo "Sill RSS: $(( RSS_KB / 1024 )) MB"
echo "Budget:   CPU <= 0.1% (Sill + helper), RSS < 80 MB, wakeups ~0 with media stopped"

if [ "$(id -u)" = "0" ]; then
  echo "powermetrics (energy impact):"
  powermetrics --samplers tasks --show-process-energy -i 5000 -n 6 | grep -E "^Name|Sill|perl" || true
fi
