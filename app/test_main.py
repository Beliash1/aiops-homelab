"""Minimal test suite -- exists mainly so the CI pipeline has something real
to run in its 'test' stage before it ever builds an image. Run locally with:
    pip install -r requirements.txt pytest httpx
    pytest
"""
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_root():
    r = client.get("/")
    assert r.status_code == 200
    assert r.json()["service"] == "aiops-homelab-app"


def test_healthz_ok_by_default():
    r = client.get("/healthz")
    assert r.status_code == 200


def test_readyz_ok_by_default():
    r = client.get("/readyz")
    assert r.status_code == 200


def test_work_endpoint():
    r = client.get("/work")
    assert r.status_code == 200
    assert "crunched" in r.json()
