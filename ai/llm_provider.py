"""
Single pluggable entry point every ai/*.py script imports instead of talking
to an LLM API directly. That indirection is the point: it's a small, honest
example of a provider-abstraction pattern (same idea as e.g. LiteLLM), and
it's what lets this whole project run for free.

Backend selection (in priority order):
  1. LLM_BACKEND=ollama (default) -- local model via Ollama, $0 cost, needs
     `ollama serve` running and a model pulled (setup.sh does both).
  2. LLM_BACKEND=claude -- Anthropic API. Requires ANTHROPIC_API_KEY.
     NOTE: a claude.ai Pro/subscription login does NOT include API access --
     the API is billed separately, per token, at console.anthropic.com.
     Costs here are small (this project sends short prompts with
     claude-haiku-4-5), but it is not covered by a Pro subscription.

If ANTHROPIC_API_KEY is unset, everything falls back to Ollama automatically
-- you don't have to configure anything to run this project for free.
"""
import json
import os
import urllib.request
import urllib.error


OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.1:8b")
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-haiku-4-5")


class LLMError(RuntimeError):
    pass


def _backend() -> str:
    explicit = os.getenv("LLM_BACKEND")
    if explicit:
        return explicit
    return "claude" if os.getenv("ANTHROPIC_API_KEY") else "ollama"


def _call_ollama(system: str, prompt: str, timeout: int = 300) -> str:
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "system": system,
        "stream": False,
    }
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            return body.get("response", "").strip()
    except urllib.error.URLError as e:
        raise LLMError(
            f"Could not reach Ollama at {OLLAMA_URL} ({e}). "
            "Is it running? Try: ollama serve   (and in another terminal: ollama pull "
            f"{OLLAMA_MODEL})"
        ) from e


def _call_claude(system: str, prompt: str, timeout: int = 60) -> str:
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise LLMError(
            "LLM_BACKEND=claude but ANTHROPIC_API_KEY is not set. "
            "Get a key at console.anthropic.com (separate from a claude.ai "
            "subscription), then: export ANTHROPIC_API_KEY=sk-ant-..."
        )
    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 1024,
        "system": system,
        "messages": [{"role": "user", "content": prompt}],
    }
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            return "".join(block.get("text", "") for block in body.get("content", []))
    except urllib.error.HTTPError as e:
        raise LLMError(f"Claude API error {e.code}: {e.read().decode('utf-8', 'ignore')}") from e
    except urllib.error.URLError as e:
        raise LLMError(f"Could not reach api.anthropic.com ({e})") from e


def complete(system: str, prompt: str) -> str:
    """The one function everything else calls. Raises LLMError with an
    actionable message on failure instead of a bare traceback -- these
    scripts are meant to be run by a person still setting this up, not
    inside a service where a stack trace is fine."""
    backend = _backend()
    if backend == "ollama":
        return _call_ollama(system, prompt)
    if backend == "claude":
        return _call_claude(system, prompt)
    raise LLMError(f"Unknown LLM_BACKEND={backend!r}. Use 'ollama' or 'claude'.")


def backend_name() -> str:
    return _backend()


if __name__ == "__main__":
    # Quick smoke test: python3 ai/llm_provider.py
    print(f"Backend: {backend_name()}")
    try:
        out = complete(
            system="You are a terse infrastructure assistant.",
            prompt="In one sentence, what is a Kubernetes liveness probe for?",
        )
        print(f"Response: {out}")
    except LLMError as e:
        print(f"LLM call failed: {e}")
