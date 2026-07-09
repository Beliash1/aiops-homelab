#!/usr/bin/env python3
"""
AI incident responder.

The idea this demonstrates: when something breaks, the slow part usually
isn't fixing it, it's gathering context (which pod, since when, what
changed, what do the events say) before you can even start. This script
automates the gathering-and-first-draft step -- describe a failing pod,
pull events/logs, and have an LLM draft a structured incident note. It does
NOT take any remediation action on its own; a human still decides what to
actually do, and the draft says so explicitly.

Usage:
    python3 ai/incident_responder.py                 # auto-detect a bad pod
    python3 ai/incident_responder.py POD_NAME         # target a specific pod
    make ai-incident
"""
import sys
from datetime import datetime, timezone

from llm_provider import complete, backend_name, LLMError
import k8s_context as k8s

SYSTEM_PROMPT = """You are drafting a first-pass incident note for a small \
demo service called aiops-app running on Kubernetes. You are given a pod \
describe output, recent events, and recent logs. Write a structured draft:

## Incident Draft

**Severity guess:** (Low/Medium/High, with one line of justification)
**What's happening:** (2-3 sentences, plain English)
**Evidence:** (bullet the specific lines from events/describe/logs that \
support your read -- quote them, don't paraphrase evidence away)
**Suggested remediation:** (1-3 concrete commands, e.g. rollback, restart, \
scale -- these are SUGGESTIONS ONLY)
**Confidence:** (Low/Medium/High -- how sure are you given the evidence \
available)

End with exactly this line, verbatim: \
"This is an AI-generated first draft. A human should verify before acting."
"""


def main() -> int:
    target = sys.argv[1] if len(sys.argv) > 1 else None
    print(f"[incident_responder] LLM backend: {backend_name()}")

    if not target:
        target = k8s.first_pod_name()
        if not target:
            print("No pods found for app=aiops-app. Is anything deployed? Try: make deploy")
            return 1
        print(f"[incident_responder] No pod specified, auto-selected: {target}")

    print("[incident_responder] Gathering describe/events/logs...\n")
    describe = k8s.describe_pod(target)
    events = k8s.recent_events()
    logs = k8s.recent_logs(lines=60)

    prompt = f"""=== kubectl describe pod {target} ===
{describe}

=== Recent namespace events ===
{events}

=== Recent logs (last 100 lines) ===
{logs}
"""

    try:
        draft = complete(SYSTEM_PROMPT, prompt)
    except LLMError as e:
        print(f"[incident_responder] {e}", file=sys.stderr)
        return 1

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print("=" * 70)
    print(f"AI INCIDENT DRAFT -- {target} -- generated {timestamp}")
    print("=" * 70)
    print(draft)
    print("=" * 70)

    out_file = f"incident-{target}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.md"
    try:
        with open(out_file, "w") as f:
            f.write(f"# Incident draft: {target}\nGenerated: {timestamp}\n\n{draft}\n")
        print(f"\nSaved to ./{out_file}")
    except OSError as e:
        print(f"\n(Could not save draft to disk: {e})")

    return 0


if __name__ == "__main__":
    sys.exit(main())
