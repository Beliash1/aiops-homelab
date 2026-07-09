# Architecture

## Diagram

```
 you: git push
      │
      ▼
 ┌─────────────────────────── GitHub (cloud) ───────────────────────────┐
 │  Actions: test → docker build → push to GHCR → bump image tag in      │
 │  k8s/base/kustomization.yaml → commit back to main                    │
 └───────────────────────────────┬───────────────────────────────────────┘
                                  │ (git poll, ~3 min, or instant via
                                  │  `argocd app sync`)
                                  ▼
 ┌───────────────────── your laptop: kind cluster ───────────────────────┐
 │                                                                        │
 │   Argo CD (in-cluster)  ──sync──▶  Argo Rollout (aiops-app)            │
 │                                          │                             │
 │                                          ▼                             │
 │                        canary: 25% → analysis → 50% → 100%             │
 │                                          │                             │
 │                              AnalysisTemplate polls /readyz            │
 │                              fails twice → automatic abort+revert      │
 │                                          │                             │
 │                                          ▼                             │
 │   HPA ──watches CPU──▶ scales replicas 2↔8      (independent loop)    │
 │   kubelet ──watches /healthz──▶ restarts crashed containers (independent) │
 │                                                                        │
 │   ai/log_analyzer.py, deploy_assistant.py, incident_responder.py       │
 │   ── kubectl subprocess calls ──▶ LLM (Ollama local, or Claude API) ──▶ │
 │      plain-English summaries, printed to your terminal                 │
 └────────────────────────────────────────────────────────────────────────┘
```

## Why pull-based GitOps instead of GitHub Actions running `kubectl apply` directly

A GitHub-hosted runner lives in GitHub's cloud. Your kind cluster lives on
your laptop, almost certainly behind NAT/a firewall with no public IP.
GitHub Actions has no way to reach in and run `kubectl apply` against it --
short of you exposing your home network to the internet, which you should
not do for a homelab.

Argo CD flips the direction: it runs *inside* your cluster and reaches
*out* to GitHub (which is public and reachable from anywhere) to check for
changes. This is the standard "pull-based" GitOps model used in real
production setups too, not just a workaround for the local-cluster case --
it's more secure in general, because the cluster never has to expose an API
endpoint to an external CI system. It's a good thing to be able to explain
in an interview: "why pull instead of push" is a real architecture question.

## Why Argo Rollouts instead of a plain Deployment

A plain Kubernetes `Deployment` will happily roll out a broken version to
100% of replicas -- it has no concept of "is this actually working," only
"did the new pods report Ready." If your new version has a logic bug that
doesn't affect the readiness probe, a Deployment ships it to everyone.

`Rollout` (from Argo Rollouts, a CNCF project) adds a canary step with an
`AnalysisTemplate` that continuously grades the new version against a real
signal (here, the `/readyz` endpoint, checked 4 times) before shifting more
traffic to it. If it fails, Argo Rollouts aborts and reverts on its own --
no one has to notice the problem, decide to roll back, and run the command.
`make rollback` in this repo deploys a genuinely broken image so you can
watch this happen instead of taking it on faith.

## The three independent self-healing/scaling loops

These are easy to conflate but are three separate Kubernetes mechanisms,
each watching something different:

| Mechanism | Watches | Reacts to | Demo |
|---|---|---|---|
| Liveness probe + kubelet | `/healthz` | crashed/hung process | `make chaos` (force-kills a pod) |
| Readiness probe + Service | `/readyz` | pod temporarily can't serve traffic | `FAIL_MODE=unhealthy` env var |
| HPA + metrics-server | CPU utilization | sustained load | `make load` |
| Argo Rollouts AnalysisTemplate | `/readyz`, sampled during canary | a *new deploy* being unhealthy | `make rollback` |

Being able to name which of these fires for a given failure mode is exactly
the kind of distinction that separates "I ran some YAML" from "I understand
what happened" in an interview.

## Where the AI tooling fits in -- and where it doesn't

The AI scripts (`ai/log_analyzer.py`, `deploy_assistant.py`,
`incident_responder.py`) do **not** replace any of the mechanisms above.
They sit one layer up: they read the *output* of those mechanisms (logs,
events, rollout/HPA status) and turn it into a human-readable summary. This
is a deliberate, honest boundary -- an LLM deciding to `kubectl delete pod`
or `kubectl rollout undo` on its own, unreviewed, is a bad idea in a real
environment, and `incident_responder.py`'s output says so explicitly
("suggested remediation... a human should verify before acting"). What
you're building here is *AIOps* (AI-assisted operations) rather than
autonomous ops, and that's the correct scope to describe on a resume too --
overclaiming "autonomous AI remediation" is the kind of thing that falls
apart in a follow-up interview question.
