#!/usr/bin/env bash
# Guided tour through every mechanism in the stack, back to back, with
# plain-English narration. This is what to run when someone says "show me
# what you built" -- including in an interview.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=aiops-homelab

pause() { echo; read -r -p "-- press enter to continue -- " _ || true; echo; }
section() { echo; echo "############################################################"; echo "# $1"; echo "############################################################"; }

section "1/5  Baseline: what's running"
kubectl get pods -n "$NS" -o wide
pause

section "2/5  Self-healing: kill a pod, watch it come back on its own"
echo "Mechanism: liveness probe (kubelet) + ReplicaSet controller. No AI involved -- this is plain Kubernetes."
./scripts/chaos-kill-pod.sh
pause

section "3/5  Autoscaling: generate load, watch replica count climb"
echo "Mechanism: HPA polling metrics-server every 15s against the /work endpoint's CPU usage."
./scripts/load-test.sh
pause

section "4/5  Progressive delivery + automated rollback: deploy a broken version on purpose"
echo "Mechanism: Argo Rollouts canary -> AnalysisTemplate queries /readyz -> aborts + reverts on failure. No human decided to roll back."
make rollback
pause

section "5/5  AI tooling: log analysis, deployment assistant, incident response"
echo "These use an LLM (local Ollama by default) to turn raw kubectl output into a plain-English summary/report."
python3 ai/log_analyzer.py || true
pause
python3 ai/deploy_assistant.py || true
pause
python3 ai/incident_responder.py || true

section "Done"
echo "Everything above ran off two inputs: 'git push' (CI/CD) and the commands in this script (day-2 ops)."
