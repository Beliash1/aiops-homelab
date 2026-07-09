#!/usr/bin/env python3
"""
AI log analyzer.

What it actually automates: pulling logs + recent events for the app,
handing them to an LLM with instructions to think like an SRE, and printing
a short triage summary instead of you scrolling through `kubectl logs`
by hand. Run it any time, but it's most interesting right after one of the
demo scripts (chaos-kill-pod.sh, load-test.sh, `make rollback`) so there's
something worth summarizing.

Usage:
    python3 ai/log_analyzer.py
    make ai-logs
"""
import sys

from llm_provider import complete, backend_name, LLMError
import k8s_context as k8s

SYSTEM_PROMPT = """You are an SRE assistant reviewing logs and Kubernetes \
events for a small demo service called aiops-app. Be concise and concrete.

Structure your answer as:
1. Summary (1-2 sentences: is anything currently wrong?)
2. Anomalies (bullet list of anything unusual in the logs/events -- \
restarts, non-2xx responses, readiness/liveness failures, warnings. If \
nothing is unusual, say so plainly, don't invent problems.)
3. Likely cause (only if anomalies were found)
4. Suggested next command (one concrete kubectl/argo command to investigate \
or fix further, or 'none needed' if healthy)

Do not pad the answer with generic Kubernetes advice unrelated to what's in \
the provided logs/events."""


def main() -> int:
    print(f"[log_analyzer] LLM backend: {backend_name()}")
    print("[log_analyzer] Pulling recent logs and events from the cluster...\n")

    logs = k8s.recent_logs()
    events = k8s.recent_events()
    pods = k8s.pod_status()

    if k8s.is_error(logs) and k8s.is_error(events):
        print("Could not reach the cluster. Is it running? Try: make up && make deploy")
        print(f"\n{logs}\n{events}")
        return 1

    prompt = f"""=== Pod status ===
{pods}

=== Recent events (sorted by time) ===
{events}

=== Recent application logs (last 200 lines, all pods) ===
{logs}
"""

    try:
        analysis = complete(SYSTEM_PROMPT, prompt)
    except LLMError as e:
        print(f"[log_analyzer] {e}", file=sys.stderr)
        return 1

    print("=" * 70)
    print("AI LOG ANALYSIS")
    print("=" * 70)
    print(analysis)
    print("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())
