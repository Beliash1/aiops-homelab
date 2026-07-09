# Resume bullets

Everything below is written to be true only *after* you've actually run the
demos and can speak to them in an interview -- don't paste these in until
you've done `make demo` at least once and modified something yourself (see
`docs/LEARNING-ROADMAP.md` Phase 1). An interviewer asking "walk me through
what happens when a canary fails" should get a real answer, not a recital.

## Projects section entry

**AI-Augmented DevOps Pipeline (Personal Project)** — [github link]
`Kubernetes · Argo Rollouts · Argo CD · GitHub Actions · Docker · Ollama/LLM`

Pick 3-4 of these, don't use all of them -- a project with 8 bullets reads
as padded:

- Designed and built a GitOps CI/CD pipeline (GitHub Actions → GHCR → Argo
  CD) deploying a containerized service to a local Kubernetes cluster,
  with pull-based sync so the deploy target never needs an exposed API
- Implemented progressive delivery with Argo Rollouts, using a canary
  strategy with automated health analysis that aborts and reverts a bad
  deploy without manual intervention
- Configured Kubernetes self-healing (liveness/readiness probes) and
  horizontal autoscaling (HPA on CPU utilization), and validated both with
  chaos/load-test scripts
- Built LLM-backed operational tooling (log triage, deployment status
  summarization, incident-draft generation) on a swappable local
  (Ollama)/hosted (Claude API) backend, demonstrating practical AIOps
  patterns without overstating autonomy -- the tooling drafts, a human
  decides
- Wrote a fully reproducible, one-command environment bootstrap
  (Docker, kind, Helm, Argo Rollouts, Argo CD, Ollama) for a repeatable
  local Kubernetes homelab

## Skills section additions

Only list what you can back up if asked a follow-up question:

`Kubernetes` `Docker` `GitHub Actions` `GitOps` `Argo CD` `Argo Rollouts`
`Horizontal Pod Autoscaling` `CI/CD` `Progressive Delivery` `Ollama` `LLM
integration (API + local inference)` `Infrastructure automation`

Do **not** list `MLOps`, `Model Training`, `PyTorch/TensorFlow` etc. unless
you go through Phase 2 of the roadmap and actually touch model
serving/training -- those keywords get tested specifically in AI-native
company interviews and an unsupported claim there is worse than not
claiming it.

## Summary/headline line (adjust to your actual years of experience)

> DevOps Engineer with hands-on experience building GitOps CI/CD pipelines,
> Kubernetes progressive-delivery workflows, and LLM-integrated operational
> tooling; transitioning toward AI/Platform Infrastructure roles.

## When your existing resume is uploaded

Once you share your current resume, the right next step is to rewrite your
*existing* job history bullets (not just add a new project) using the
same "what you built, what mechanism it used, what the measurable effect
was" structure as above -- most DevOps resumes under-describe automation
work that's actually more relevant to AI infrastructure roles than it
looks at first glance (anything involving Kubernetes, IaC, CI/CD pipeline
design, or monitoring/observability is directly transferable and should be
reframed, not hidden under a generic "maintained infrastructure" line).
