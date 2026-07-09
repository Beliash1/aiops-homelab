"""
Sample service deployed by the pipeline.

This is intentionally small: its only job is to give the rest of the stack
(CI/CD, Argo Rollouts, HPA, the AI tooling) something real to build, break,
and heal. Two things make it useful as a teaching tool:

1. /healthz and /readyz are separate, matching how Kubernetes distinguishes
   liveness (is the process alive?) from readiness (can it serve traffic?).
2. FAIL_MODE (an env var you flip in a deployment) lets you deliberately
   break readiness or burn CPU on demand, so you can watch self-healing,
   auto-rollback, and autoscaling actually trigger instead of taking them
   on faith.
"""
import os
import time
import random
import logging
from datetime import datetime, timezone

from fastapi import FastAPI, Response, status

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("aiops-homelab-app")

APP_VERSION = os.getenv("APP_VERSION", "dev")
FAIL_MODE = os.getenv("FAIL_MODE", "none")  # none | unhealthy | crash | slow
START_TIME = time.time()

app = FastAPI(title="aiops-homelab-app", version=APP_VERSION)


@app.get("/")
def root():
    log.info("request served path=/ version=%s", APP_VERSION)
    return {
        "service": "aiops-homelab-app",
        "version": APP_VERSION,
        "fail_mode": FAIL_MODE,
        "uptime_seconds": round(time.time() - START_TIME, 1),
        "time": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/work")
def do_work():
    """Burns CPU so the load-test script can trigger the HPA."""
    n = random.randint(200_000, 800_000)
    total = 0
    for i in range(n):
        total += i * i
    return {"crunched": n, "result_checksum": total % 997}


@app.get("/healthz")
def healthz(response: Response):
    """Liveness probe. Only 'crash' mode fails this -- k8s will restart the pod."""
    if FAIL_MODE == "crash":
        log.error("liveness check failing on purpose (FAIL_MODE=crash)")
        response.status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
        return {"status": "unhealthy", "reason": "FAIL_MODE=crash"}
    return {"status": "ok"}


@app.get("/readyz")
def readyz(response: Response):
    """Readiness probe. 'unhealthy' mode fails this -- k8s stops routing traffic
    to the pod but does NOT restart it, which is the distinction the demo is
    built to show."""
    if FAIL_MODE == "unhealthy":
        log.warning("readiness check failing on purpose (FAIL_MODE=unhealthy)")
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready", "reason": "FAIL_MODE=unhealthy"}
    if FAIL_MODE == "slow":
        time.sleep(3)
    return {"status": "ready"}


@app.get("/metrics-lite")
def metrics_lite():
    """Not real Prometheus metrics (kept out of scope on purpose) -- just enough
    JSON for the AI log analyzer / incident responder to reason about without
    needing the full monitoring stack running."""
    return {
        "version": APP_VERSION,
        "fail_mode": FAIL_MODE,
        "uptime_seconds": round(time.time() - START_TIME, 1),
    }
