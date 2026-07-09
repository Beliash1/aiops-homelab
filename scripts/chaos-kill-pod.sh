#!/usr/bin/env bash
# Self-healing demo. Kubernetes' liveness probe + ReplicaSet controller do
# 100% of the work here -- this script just kills a pod and then watches,
# so you can SEE the mechanism instead of trusting it exists.
set -euo pipefail
NS=aiops-homelab

victim=$(kubectl get pods -n "$NS" -l app=aiops-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$victim" ]]; then
  echo "No aiops-app pods found. Run 'make deploy' first." >&2
  exit 1
fi

echo "==> Before: $(kubectl get pods -n "$NS" -l app=aiops-app --no-headers | wc -l) pods running"
kubectl get pods -n "$NS" -l app=aiops-app

echo
echo "==> Force-deleting pod: $victim"
kubectl delete pod "$victim" -n "$NS" --grace-period=0 --force

echo
echo "==> Watching the ReplicaSet controller replace it (ctrl-C to stop early)"
kubectl get pods -n "$NS" -l app=aiops-app -w &
watch_pid=$!
sleep 15
kill "$watch_pid" 2>/dev/null || true

echo
echo "==> After: replacement pod is running. Nobody paged, nobody ran kubectl create --"
echo "    the ReplicaSet noticed replica count dropped below desired and fixed it."
kubectl get pods -n "$NS" -l app=aiops-app
