#!/usr/bin/env bash
# Optional: installs kube-prometheus-stack (Prometheus + Grafana). Not
# required for the core self-healing/rollback/autoscaling demos -- kubectl
# already shows you all of that directly -- but it gives the AI log
# analyzer real metrics/alerts to reason about instead of just raw logs,
# and it's a resume-relevant piece of the stack on its own.
set -euo pipefail
cd "$(dirname "$0")/.."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f k8s/monitoring/kube-prometheus-values.yaml \
  --wait --timeout 5m

kubectl apply -f k8s/base/servicemonitor.yaml

echo
echo "Grafana:    kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "            open http://localhost:3000  (user: admin / pass: admin)"
echo "Prometheus: kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
