#!/usr/bin/env bash
# Autoscaling demo. Hits the CPU-burning /work endpoint hard enough to push
# average CPU utilization past the HPA's 60% target, then gets out of the
# way so you can watch `kubectl get hpa -n aiops-homelab -w` add replicas,
# and again ~30s after load stops to watch it scale back down.
set -euo pipefail
NS=aiops-homelab
URL="http://localhost:8081/work"

if ! command -v k6 >/dev/null 2>&1; then
  echo "k6 not found. Falling back to a crude curl-based load generator (less accurate)." >&2
  echo "For the real thing: https://k6.io/docs/get-started/installation/" >&2
  echo "==> Hammering $URL for 90s with 20 parallel curl loops"
  for _ in $(seq 1 20); do
    ( while true; do curl -s -o /dev/null "$URL"; done ) &
  done
  trap 'kill $(jobs -p) 2>/dev/null' EXIT
  echo "==> In another terminal, run: kubectl get hpa -n $NS -w"
  sleep 90
  exit 0
fi

cat > /tmp/aiops-homelab-load.js <<'EOF'
import http from 'k6/http';
export const options = { vus: 20, duration: '90s' };
export default function () {
  http.get(__ENV.TARGET_URL);
}
EOF

echo "==> Open another terminal now and run: kubectl get hpa -n $NS -w"
echo "==> Generating load against $URL for 90s..."
TARGET_URL="$URL" k6 run /tmp/aiops-homelab-load.js
echo "==> Load stopped. HPA's scaleDown stabilization window is 30s -- give it a minute to settle back down."
