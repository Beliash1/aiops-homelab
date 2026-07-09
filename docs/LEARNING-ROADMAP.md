# Learning roadmap: DevOps → AI Infrastructure / Platform Engineer

This maps this repo to a phased plan, plus what comes after it. Researched
in July 2026 against current job-market sources (linked at the bottom) --
worth re-checking every few months since this space moves fast.

## Where you're starting from

Straight "DevOps Engineer" listings are getting more competitive and
increasingly filtered by ATS keyword-matching against AI/platform terms --
which matches what you're seeing with applications going unanswered. The
fix isn't a different job title so much as demonstrable, specific skills
that show up in the resume bullets and, better, in a project a recruiter or
hiring manager can actually look at. That's what this repo is for.

## Phase 1 (this repo): infrastructure foundations, AI-augmented

**Goal:** be able to talk fluently, with a working example, about CI/CD,
containerization, Kubernetes, progressive delivery, self-healing,
autoscaling, and GitOps -- and show one concrete way AI tooling plugs into
operations (not replaces it).

- [ ] `./setup.sh` + `make up` + `make deploy` -- get the stack running
- [ ] `make demo` once, straight through, reading the narration
- [ ] Re-run each demo individually and read the relevant file *before*
      running it: `k8s/base/rollout.yaml` before `make rollback`,
      `k8s/base/hpa.yaml` before `make load`, etc. Running a demo without
      reading the manifest that drives it is the difference between having
      done this and being able to explain it.
- [ ] Break something on purpose that isn't in the demo scripts -- e.g. set
      `FAIL_MODE=slow` and watch what changes vs. `unhealthy` vs. `crash`
      (see `docs/ARCHITECTURE.md`'s probe table). Predict the behavior
      before you trigger it; that's the actual learning, not the running.
- [ ] Read `docs/ARCHITECTURE.md`'s "why pull-based GitOps" and "why Argo
      Rollouts instead of a Deployment" sections until you could explain
      both from memory
- [ ] Modify one thing yourself: change the canary steps in
      `k8s/base/rollout.yaml` (e.g. add a 10% first step), or add a new
      `FAIL_MODE` to `app/main.py` and wire a demo around it

**Time estimate:** 1-2 weeks of evenings, most of it in the "read + predict
+ verify" loop above, not the initial setup.

## Phase 2: AI-specific infrastructure (4-8 months, part-time)

This is the part that's genuinely new relative to classic DevOps, and
where the job market source below is specific: DevOps/SRE background
covers roughly half of what an AI infrastructure/platform role wants. The
other half:

1. **Model serving** -- learn one framework: **vLLM** is the current
   recommendation (also TGI, Triton). Concretely: serve an open model
   (e.g. via vLLM on a GPU box, or CPU-mode for learning) and put it behind
   the kind of Kubernetes deployment you already know how to build from
   Phase 1.
2. **Vector databases** -- pick one: pgvector (if you already know
   Postgres, cheapest path), Qdrant, Weaviate, or Pinecone (managed).
   Enough to explain what embeddings are stored for and query one.
3. **LLM gateway pattern** -- a routing/observability layer in front of
   multiple LLM backends. LiteLLM is the common open-source choice. This
   is architecturally the same "provider abstraction" idea as
   `ai/llm_provider.py` in this repo, just productionized.
4. **Evaluation frameworks** -- Promptfoo or DeepEval, for testing LLM
   outputs the way you'd unit-test code. This is the piece classic DevOps
   backgrounds most often skip, and it's what turns "I called an LLM API"
   into "I can verify an LLM-backed system behaves correctly."
5. **LLM-specific observability** -- token usage, latency, cost per
   request, prompt/response logging. Extends the Prometheus/Grafana you
   already set up in `make monitoring`.

**Concrete next project** once Phase 1 is solid: extend this repo's
`ai/llm_provider.py` into an actual LiteLLM gateway deployed *in* the kind
cluster (not run as a local script), with a Promptfoo eval suite in CI
that has to pass before the gateway config changes deploy. That single
extension touches all five items above and reuses everything from Phase 1.

## Phase 3: positioning and the job search itself

- Target titles: **Platform Engineer**, **AI/ML Infrastructure Engineer**,
  **DevOps Engineer (AI/LLMOps)** -- not pure **MLOps Engineer** unless you
  also pick up Phase 2's model-serving/training-pipeline side seriously.
  MLOps postings usually expect hands-on model deployment/monitoring
  experience (PyTorch/TensorFlow-adjacent); AI Infrastructure/Platform
  postings weight Kubernetes, IaC, and distributed-systems experience more
  heavily -- closer to where you already are.
- Put this repo on your resume and GitHub with a live description of what
  it demonstrates, not just a link (see `docs/RESUME-BULLETS.md`).
- Reported salary bands for the target track: roughly $145K-$250K for
  entry-to-mid, $180K-$250K typical mid/senior, scaling higher at AI-native
  companies -- useful context for calibrating your search and any
  negotiation, though treat any single source's numbers as directional,
  not a quote for your specific market or country.

## Staying current

This field moves fast enough that specific tool recommendations age in
months, not years. Re-run a search like "AI platform engineer skills
[current year]" every quarter or so rather than treating this document as
permanent. A few things worth tracking on an ongoing basis: the CNCF
landscape (cncf.io/landscape) for what's graduating from experimental to
standard, and job postings for your two or three target titles -- read the
requirements sections directly rather than trend articles, since postings
reflect what's actually being hired for right now.

---

Sources consulted for this roadmap (July 2026):
- [The AI Platform Engineer Career Path (2026)](https://jobsbyculture.com/blog/ai-platform-engineer-career-path-2026)
- [ML Infrastructure Engineer vs MLOps Engineer: Key Differences in 2026](https://www.secondtalent.com/resources/ml-infrastructure-engineer-vs-mlops-engineer-key-differences/)
