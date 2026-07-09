#!/usr/bin/env python3
"""
AI deployment assistant.

Answers the two questions you actually ask after every deploy: "did it
work" and "what changed." Pulls the Argo Rollouts status, HPA state, recent
git history, and hands it to an LLM to turn into a plain-English status
report -- the kind of thing you'd otherwise type into a Slack update by
hand.

Usage:
    python3 ai/deploy_assistant.py
    make ai-assistant
"""
import sys

from llm_provider import complete, backend_name, LLMError
import k8s_context as k8s

SYSTEM_PROMPT = """You are a deployment assistant for a small demo service \
called aiops-app, deployed via Argo Rollouts (progressive canary delivery) \
on Kubernetes. Given rollout status, HPA status, pod status, and recent git \
history, answer in this structure:

1. Deploy status (Healthy / Progressing / Degraded / Paused -- pick one, \
   based on the rollout output, not a guess)
2. What changed (summarize the recent git commits in plain English)
3. Current scale (replica count from HPA/pods, and why -- e.g. 'at minimum, \
   no load' vs 'scaled up, under load')
4. If NOT healthy: the single most likely next action \
   (e.g. 'kubectl argo rollouts undo aiops-app -n aiops-homelab')

Be concrete and short. No generic filler about best practices."""


def main() -> int:
    print(f"[deploy_assistant] LLM backend: {backend_name()}")
    print("[deploy_assistant] Gathering rollout, HPA, and git context...\n")

    rollout = k8s.rollout_status()
    hpa = k8s.hpa_status()
    pods = k8s.pod_status()
    git_log = k8s.recent_git_log()

    if k8s.is_error(rollout) and k8s.is_error(pods):
        print("Could not reach the cluster. Is it running? Try: make up && make deploy")
        return 1

    prompt = f"""=== Argo Rollout status ===
{rollout}

=== HPA status ===
{hpa}

=== Pod status ===
{pods}

=== Recent git commits (this repo) ===
{git_log}
"""

    try:
        report = complete(SYSTEM_PROMPT, prompt)
    except LLMError as e:
        print(f"[deploy_assistant] {e}", file=sys.stderr)
        return 1

    print("=" * 70)
    print("AI DEPLOYMENT ASSISTANT")
    print("=" * 70)
    print(report)
    print("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())
