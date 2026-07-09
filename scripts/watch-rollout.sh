#!/usr/bin/env bash
# Thin wrapper -- exists so `make status` / docs can point to one obvious
# command for "what is my rollout doing right now."
set -euo pipefail
kubectl argo rollouts get rollout aiops-app -n aiops-homelab --watch
