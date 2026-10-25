	ARGOCD_VERSION ?= v2.13.3
CLUSTER = gitops

.PHONY: up down

up:
	kind create cluster --config bootstrap/kind-config.yaml || true
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
	kubectl -n argocd rollout status deploy/argocd-applicationset-controller --timeout=300s
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	kubectl -n kube-system patch deploy metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
	for ns in staging production; do \
	  kubectl create namespace $$ns --dry-run=client -o yaml | kubectl apply -f - ; \
	  kubectl -n $$ns create secret generic app-secret --from-literal=API_KEY=$$(openssl rand -hex 16) --dry-run=client -o yaml | kubectl apply -f - ; \
	done
	kubectl apply -f bootstrap/root-app.yaml
	@echo "ArgoCD admin password:"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

down:
	kind delete cluster --name $(CLUSTER)
