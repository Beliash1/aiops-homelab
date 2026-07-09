#!/usr/bin/env bash
# One-command bootstrap for Ubuntu 22.04/24.04.
#
# Installs everything the rest of this repo assumes exists:
#   docker, kubectl, kind, helm, argo rollouts plugin, argocd CLI, k6, ollama
#
# Design choice: this script is IDEMPOTENT -- run it as many times as you
# want, it skips anything already installed. That matters because you'll
# probably run it once, reboot for the docker group change, and run it
# again.
#
# Usage:
#   chmod +x setup.sh && ./setup.sh
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log()  { echo -e "${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
warn() { echo -e "${YELLOW}!!${RESET} $*"; }

need_reboot_or_relogin=false

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script targets Ubuntu Linux. Detected: $(uname -s)." >&2
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) KARCH="amd64" ;;
  aarch64|arm64) KARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

log "Updating apt package index"
sudo apt-get update -qq

log "Installing base packages (curl, git, jq, ca-certificates)"
sudo apt-get install -y -qq curl git jq ca-certificates gnupg apt-transport-https lsb-release >/dev/null

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  need_reboot_or_relogin=true
else
  log "Docker already installed ($(docker --version))"
fi

# ---------------------------------------------------------------------------
# kubectl
# ---------------------------------------------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  log "Installing kubectl"
  KVER="$(curl -Ls https://dl.k8s.io/release/stable.txt)"
  curl -Lso /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/${KARCH}/kubectl"
  sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
else
  log "kubectl already installed ($(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -1))"
fi

# ---------------------------------------------------------------------------
# kind (local Kubernetes cluster)
# ---------------------------------------------------------------------------
if ! command -v kind >/dev/null 2>&1; then
  log "Installing kind"
  KIND_VERSION="v0.24.0"
  curl -Lso /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KARCH}"
  sudo install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind
  rm -f /tmp/kind
else
  log "kind already installed ($(kind version))"
fi

# ---------------------------------------------------------------------------
# Helm
# ---------------------------------------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  log "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null
else
  log "Helm already installed ($(helm version --short))"
fi

# ---------------------------------------------------------------------------
# Argo Rollouts kubectl plugin (progressive delivery / auto-rollback)
# ---------------------------------------------------------------------------
if ! kubectl argo rollouts version >/dev/null 2>&1; then
  log "Installing kubectl-argo-rollouts plugin"
  curl -Lso /tmp/kubectl-argo-rollouts \
    "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-${KARCH}"
  sudo install -o root -g root -m 0755 /tmp/kubectl-argo-rollouts /usr/local/bin/kubectl-argo-rollouts
  rm -f /tmp/kubectl-argo-rollouts
else
  log "kubectl-argo-rollouts already installed"
fi

# ---------------------------------------------------------------------------
# Argo CD CLI (GitOps continuous delivery)
# ---------------------------------------------------------------------------
if ! command -v argocd >/dev/null 2>&1; then
  log "Installing argocd CLI"
  curl -Lso /tmp/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${KARCH}"
  sudo install -o root -g root -m 0755 /tmp/argocd /usr/local/bin/argocd
  rm -f /tmp/argocd
else
  log "argocd CLI already installed"
fi

# ---------------------------------------------------------------------------
# k6 (load generator, used to trigger the HPA for the autoscaling demo)
# ---------------------------------------------------------------------------
if ! command -v k6 >/dev/null 2>&1; then
  log "Installing k6"
  sudo gpg -k >/dev/null 2>&1 || true
  sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69 2>/dev/null || true
  echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list >/dev/null
  sudo apt-get update -qq 2>/dev/null || true
  sudo apt-get install -y -qq k6 2>/dev/null || warn "k6 apt install failed -- see https://k6.io/docs/get-started/installation/ for manual install"
else
  log "k6 already installed"
fi

# ---------------------------------------------------------------------------
# Ollama (local, free LLM runtime -- powers ai/llm_provider.py by default)
# ---------------------------------------------------------------------------
if ! command -v ollama >/dev/null 2>&1; then
  log "Installing Ollama (local LLM runtime, no API costs)"
  curl -fsSL https://ollama.com/install.sh | sh
else
  log "Ollama already installed"
fi

log "Pulling default local model (llama3.1:8b -- ~4.7GB, needs 8GB+ RAM)"
if command -v ollama >/dev/null 2>&1; then
  (ollama list 2>/dev/null | grep -q "llama3.1:8b") || ollama pull llama3.1:8b || warn "Model pull failed -- run 'ollama pull llama3.1:8b' manually once the ollama service is up"
fi

# ---------------------------------------------------------------------------
# Python deps for the ai/ scripts
# ---------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  log "Installing Python dependencies for ai/ tooling"
  python3 -m pip install --break-system-packages -q -r "$(dirname "$0")/ai/requirements.txt" || \
    warn "pip install failed -- consider a venv: python3 -m venv .venv && source .venv/bin/activate && pip install -r ai/requirements.txt"
fi

echo
log "Bootstrap complete."
echo "Installed: docker, kubectl, kind, helm, kubectl-argo-rollouts, argocd, k6, ollama"
echo
if [[ "$need_reboot_or_relogin" == true ]]; then
  warn "Docker was just installed and your user was added to the 'docker' group."
  warn "Log out and back in (or run: newgrp docker) before continuing, otherwise 'docker ps' will fail with a permissions error."
fi
echo
echo "Next step:"
echo "  make up      # creates the local kind cluster + installs Argo Rollouts, Argo CD, metrics-server"
echo "  make deploy  # deploys the sample app through Argo Rollouts"
echo "  make demo    # runs the guided tour: self-healing, autoscaling, rollback, AI tooling"
