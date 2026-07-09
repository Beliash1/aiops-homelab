FROM python:3.12-slim AS base

WORKDIR /app

# Dependencies in their own layer so code edits don't invalidate the pip cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Non-root user -- basic image hardening, also what most CI security scanners check for
RUN useradd --no-create-home --uid 10001 appuser
USER 10001

ARG FAIL_MODE=none
ENV APP_VERSION="dev" \
    FAIL_MODE=${FAIL_MODE} \
    PYTHONUNBUFFERED=1

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2).status==200 else 1)"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
