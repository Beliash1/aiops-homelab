"""
Shared helpers for pulling raw context out of the cluster via kubectl
subprocess calls. Kept deliberately dumb (no k8s python client, no auth
magic) so it works with whatever kubeconfig/context you already have active
-- same as running kubectl by hand. Every ai/*.py script imports this
instead of re-implementing subprocess calls three times.
"""
import subprocess

NAMESPACE = "aiops-homelab"


def _run(cmd: list[str], timeout: int = 20) -> str:
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        )
        if result.returncode != 0:
            return f"[command failed: {' '.join(cmd)}]\n{result.stderr.strip()}"
        return result.stdout.strip()
    except FileNotFoundError:
        return "[kubectl not found on PATH -- install it via ./setup.sh]"
    except subprocess.TimeoutExpired:
        return f"[command timed out: {' '.join(cmd)}]"


def is_error(s: str) -> bool:
    """True only for OUR OWN error placeholders above -- deliberately not
    a generic startswith('[') check, because kubectl --prefix output
    legitimately starts with '[pod/name/container]' on success too."""
    return s.startswith("[command failed:") or s.startswith("[kubectl not found") or s.startswith("[command timed out:")


def recent_logs(lines: int = 60) -> str:
    return _run([
        "kubectl", "logs", "-n", NAMESPACE, "-l", "app=aiops-app",
        f"--tail={lines}", "--all-containers", "--prefix",
    ])


def recent_events(limit: int = 20) -> str:
    # kubectl get has no --limit flag -- cap by trimming the returned text instead
    return _run([
        "kubectl", "get", "events", "-n", NAMESPACE,
        "--sort-by=.lastTimestamp",
        "-o", "custom-columns=TIME:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message",
    ])[-1500:]  # crude cap -- CPU-only local inference is slow to prompt-eval, keep this tight


def pod_status() -> str:
    return _run(["kubectl", "get", "pods", "-n", NAMESPACE, "-o", "wide"])


def describe_pod(pod_name: str) -> str:
    return _run(["kubectl", "describe", "pod", pod_name, "-n", NAMESPACE])


def first_pod_name() -> str | None:
    out = _run([
        "kubectl", "get", "pods", "-n", NAMESPACE, "-l", "app=aiops-app",
        "-o", "jsonpath={.items[0].metadata.name}",
    ])
    return out if out and not out.startswith("[") else None


def rollout_status() -> str:
    return _run(["kubectl", "argo", "rollouts", "get", "rollout", "aiops-app", "-n", NAMESPACE])


def hpa_status() -> str:
    return _run(["kubectl", "get", "hpa", "-n", NAMESPACE])


def recent_git_log(n: int = 5) -> str:
    return _run(["git", "log", f"-{n}", "--oneline"], timeout=10)


def git_diff_stat(n: int = 1) -> str:
    return _run(["git", "diff", f"HEAD~{n}", "HEAD", "--stat"], timeout=10)
