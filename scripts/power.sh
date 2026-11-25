#!/bin/sh
# Whole-system power for `byaku detect` vs idle, from the battery (includes camera/ISP).
# Run UNPLUGGED, fixed brightness, nothing else open. Do NOT run powermetrics at the same time.
# Usage: scripts/power.sh [runs=3] [seconds=120] [fps list="1 2 5"] [extra detect args]
#   With extra args (e.g. "--embed ml/models/sface.mlpackage"), each fps also gets an interleaved "<fps>e" setting
#   that runs detect with them, so the delta is measured in the same session.
set -eu
RUNS=${1:-3}; SECS=${2:-120}; FPS_LIST=${3:-"1 2 5"}; EXTRA=${4:-}
SETTINGS=$(for f in $FPS_LIST; do printf '%s ' "$f"; [ -n "$EXTRA" ] && printf '%se ' "$f"; done)
BIN=.build/release/byaku
swift build -c release >/dev/null
OUT=$(mktemp -d)

watts() {  # mean system draw in W over $1 seconds (InstantAmperage < 0 when discharging)
  i=0; while [ "$i" -lt "$1" ]; do
    # ioreg prints negative current as unsigned 64-bit; awk floats can't hold that exactly.
    ioreg -rn AppleSmartBattery | /usr/bin/python3 -c 'import re,sys; t=sys.stdin.read(); v=int(re.search(r"\"Voltage\" = (\d+)",t)[1]); a=int(re.search(r"\"InstantAmperage\" = (\d+)",t)[1]); a=a-2**64 if a>=2**63 else a; print(-v*a/1e6)'
    sleep 1; i=$((i+1))
  done | awk '{s+=$1} END{printf "%.3f\n", s/NR}'
}

ioreg -rn AppleSmartBattery | grep -q '"ExternalConnected" = No' || { echo "unplug the charger first" >&2; exit 1; }
for r in $(seq 1 "$RUNS"); do
  for setting in idle $SETTINGS; do
    if [ "$setting" = idle ]; then w=$(watts "$SECS"); fps_line="-"
    else
      case $setting in *e) args="--fps ${setting%e} $EXTRA";; *) args="--fps $setting";; esac
      # shellcheck disable=SC2086
      "$BIN" detect $args >"$OUT/log" 2>&1 & pid=$!
      sleep 5  # camera warm-up, excluded
      w=$(watts "$SECS"); kill "$pid"; wait "$pid" 2>/dev/null || true
      fps_line=$(awk -F'[= ]' '/delivered_fps/{d+=$2;p+=$4;n++} END{if(n)printf "sensor=%.1f processed=%.1f", d/n, p/n}' "$OUT/log")
    fi
    echo "run=$r setting=$setting watts=$w $fps_line" | tee -a "$OUT/results"
  done
done
echo "--- mean ± sd (W) and delta vs idle ---"
awk '{split($2,s,"=");split($3,w,"="); k=s[2]; n[k]++; sum[k]+=w[2]; sq[k]+=w[2]^2}
  END{for(k in n){m=sum[k]/n[k]; sd=sqrt(sq[k]/n[k]-m*m); mean[k]=m; sdv[k]=sd}
      for(k in n) printf "%-5s %.3f ± %.3f  delta=%+.3f\n", k, mean[k], sdv[k], mean[k]-mean["idle"]}' "$OUT/results" | sort
echo "raw: $OUT/results"
