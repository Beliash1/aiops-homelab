.PHONY: help setup up build deploy demo status logs ai-logs ai-assistant ai-incident \
        chaos load rollback reset-app monitoring down clean

.DEFAULT_GOAL := help

help:              ## Show this list (also runs if you just type `make`)
	@grep -E '^[a-zA-Z_-]+:.*## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup:            ## Install docker/kubectl/kind/helm/argo/ollama/k6 on this machine
	./setup.sh

up:                ## Create local kind cluster + install metrics-server, Argo Rollouts, Argo CD
	./scripts/bootstrap-cluster.sh

build:             ## Build the sample app image and load it into the kind cluster
	docker build -t aiops-app:dev ./app
	kind load docker-image aiops-app:dev --name aiops-homelab

deploy: build      ## Apply k8s manifests (Rollout, Service, HPA, PDB, AnalysisTemplate)
	kubectl apply -k k8s/base
	kubectl argo rollouts status aiops-app -n aiops-homelab --watch --timeout 120s || true

monitoring:        ## (Optional) install Prometheus + Grafana
	./scripts/bootstrap-monitoring.sh

status:            ## Show rollout, pods, hpa, svc at a glance
	@echo "--- Rollout ---"; kubectl argo rollouts get rollout aiops-app -n aiops-homelab || true
	@echo "--- Pods ---"; kubectl get pods -n aiops-homelab -o wide
	@echo "--- HPA ---"; kubectl get hpa -n aiops-homelab
	@echo "--- Service ---"; kubectl get svc -n aiops-homelab

logs:              ## Tail logs from every app pod
	kubectl logs -n aiops-homelab -l app=aiops-app -f --max-log-requests=10 --prefix

chaos:             ## Self-healing demo: kill a pod, watch Kubernetes recreate it
	./scripts/chaos-kill-pod.sh

load:              ## Autoscaling demo: generate load, watch the HPA scale replicas up
	./scripts/load-test.sh

rollback:          ## Auto-rollback demo: ship a real FAIL_MODE=unhealthy revision, watch Argo Rollouts abort it
	kubectl patch rollout aiops-app -n aiops-homelab --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/1/value","value":"unhealthy"}]'
	kubectl argo rollouts status aiops-app -n aiops-homelab --watch --timeout 90s || true
	kubectl argo rollouts get rollout aiops-app -n aiops-homelab

reset-app:         ## Restore the healthy baseline after make rollback
	kubectl apply -k k8s/base
	kubectl argo rollouts status aiops-app -n aiops-homelab --watch --timeout 60s || true

demo:              ## Guided tour: run every demo in sequence with explanations
	./scripts/run-demo.sh

ai-logs:           ## AI log analyzer: summarize recent logs/events, flag anomalies
	python3 ai/log_analyzer.py

ai-assistant:      ## AI deployment assistant: "what's the state of my deploy, what changed"
	python3 ai/deploy_assistant.py

ai-incident:       ## AI incident responder: gather context + draft an incident report
	python3 ai/incident_responder.py

down:              ## Delete the kind cluster (keeps images/config on disk)
	kind delete cluster --name aiops-homelab

clean: down        ## Also prune dangling docker images/build cache
	docker image prune -f
