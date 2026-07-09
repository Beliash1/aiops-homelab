# aiops-homelab

A one-command, local, AI-augmented DevOps pipeline you run on your own
Ubuntu machine to learn (by actually operating) the stack behind the phrase
"AI Infrastructure Engineer": CI/CD, containerization, Kubernetes,
progressive delivery with automated rollback, autoscaling, self-healing,
and LLM-based operational tooling (log analysis, deployment assistant,
incident response).

Nothing here is a toy simulation -- `make chaos` really kills a real pod in
a real (local) Kubernetes cluster and you watch the real controller fix it.
`make rollback` really ships a broken image through a real canary rollout
and watches it really get aborted automatically. The AI scripts really call
an LLM (free, local, via Ollama by default) with real `kubectl` output.

## What you end up able to say you've done

- Built a CI/CD pipeline (GitHub Actions) that tests, containerizes, and
  ships a service to GHCR on every push
- Implemented GitOps continuous delivery with Argo CD (pull-based, not
  push-based -- and can explain why that distinction matters)
- Configured progressive delivery (canary) with automated rollback based on
  live health analysis, using Argo Rollouts
- Configured Kubernetes self-healing (liveness/readiness probes) and
  horizontal autoscaling (HPA) and can demonstrate both live
- Built LLM-backed operational tooling: automated log triage, a deployment
  status assistant, and an incident-drafting tool, with a swappable local
  (Ollama) / hosted (Claude API) backend

See `docs/RESUME-BULLETS.md` for these written as actual resume lines, and
`docs/LEARNING-ROADMAP.md` for a phased plan to actually absorb the
concepts instead of just running commands.

## Quick start

```bash
git clone <your fork of this repo>
cd aiops-homelab

./setup.sh          # one-time: installs docker, kubectl, kind, helm,
                     # argo rollouts, argocd, k6, ollama -- idempotent,
                     # safe to re-run

# log out / back in (or `newgrp docker`) if this is docker's first install,
# then:

make up              # creates the local kind cluster + installs
                      # metrics-server, Argo Rollouts, Argo CD
make deploy           # builds the sample app and deploys it via Argo Rollouts
make status            # see what's running

make demo               # guided tour: self-healing, autoscaling,
                         # rollback, AI tooling -- with narration
```

Every `make` target is self-documenting -- run `make` with no arguments (or
open the `Makefile`) to see the full list with descriptions.

## Architecture, in one paragraph

Code changes push to GitHub -> GitHub Actions tests, builds a Docker image,
pushes it to GHCR, and commits the new image tag into
`k8s/base/kustomization.yaml`. That commit is the entire interface between
CI and CD. Argo CD, running *inside* your local cluster, polls the repo and
applies the change -- this is why it's called GitOps: git is the source of
truth, and the cluster pulls toward it rather than being pushed into.
Applying the change means updating an Argo Rollouts `Rollout` object, which
runs a canary (25% traffic -> health-check analysis -> 50% -> 100%) and
aborts + reverts automatically if the analysis fails. Meanwhile an HPA
watches CPU and a liveness probe watches process health, independently of
all of the above. See `docs/ARCHITECTURE.md` for the full breakdown and a
diagram.

## Repo layout

```
app/            sample FastAPI service (the thing being deployed)
.github/workflows/ci.yml   CI: test -> build -> push -> bump manifest
k8s/            cluster config, Argo Rollout, Service, HPA, PDB, GitOps app
ai/             pluggable LLM provider + log analyzer, deploy assistant,
                incident responder
scripts/        demo scripts (chaos, load test) + cluster bootstrap
docs/           architecture, learning roadmap, resume bullets
```

## AI backend: free by default

`ai/llm_provider.py` defaults to **Ollama**, a local LLM runtime -- no API
key, no per-token cost, runs entirely on your laptop. `setup.sh` installs it
and pulls `llama3.1:8b` automatically.

If you later get access to the Anthropic API (separate from a claude.ai
subscription -- see `ai/llm_provider.py` for the distinction), set
`ANTHROPIC_API_KEY` and `LLM_BACKEND=claude` to switch. Nothing else in the
codebase needs to change -- that's what the provider abstraction is for.

## Requirements

- Ubuntu 22.04 or 24.04 (setup.sh targets this; other distros need manual
  package substitutions)
- 8GB+ RAM (Ollama's default model wants ~5GB, kind's 3 nodes want the rest)
- ~10GB free disk
- Internet access for setup.sh, GitHub, and GHCR (the cluster itself, once
  built, runs fully offline except for pulling from GHCR/GitHub)

## Cleaning up

```bash
make down    # delete the kind cluster
make clean   # also prune dangling docker images
```
