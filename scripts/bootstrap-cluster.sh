#!/usr/bin/env bash
# Creates the local kind cluster and installs the control-plane add-ons the
# rest of the repo depends on: metrics-server (HPA needs it), Argo Rollouts
# (progressive delivery + auto-rollback), Argo CD (GitOps sync).
# Called by `make up` -- not usually run directly.
set -euo pipefail
cd "$(dirname "$0")/.."

if kind get clusters 2>/dev/null | grep -q "^aiops-homelab$"; then
  echo "==> kind cluster 'aiops-homelab' already exists, skipping creation"
else
  echo "==> Creating kind cluster"
  kind create cluster --config k8s/kind-cluster.yaml
fi

kubectl cluster-info --context kind-aiops-homelab

echo "==> Installing metrics-server (required for HPA)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# kind's kubelet uses a self-signed cert; metrics-server needs --kubelet-insecure-tls
# in local dev clusters (never do this in production).
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}
]' 2>/dev/null || true

echo "==> Installing Argo Rollouts controller"
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "==> Installing Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> Waiting for metrics-server, argo-rollouts, argocd-server to be ready (this can take a few minutes on first run)"
kubectl wait --for=condition=available --timeout=180s deployment/metrics-server -n kube-system || true
kubectl wait --for=condition=available --timeout=180s deployment/argo-rollouts -n argo-rollouts || true
kubectl wait --for=condition=available --timeout=240s deployment/argocd-server -n argocd || true

echo
echo "==> Cluster ready. Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(secret not found yet -- argocd-server may still be starting, retry: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo
echo "Port-forward the Argo CD UI with:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "  open https://localhost:8443  (user: admin)"
