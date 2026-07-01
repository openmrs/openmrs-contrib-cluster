SHELL        := /bin/bash
SCRIPTS      := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts

CLUSTER_NAME            ?= kind
OPENMRS_NS              ?= openmrs
OPENMRS_OPERATOR_NS     ?= openmrs-system

.PHONY: deploy deploy-operators deploy-openmrs teardown status logs help

deploy: ## Full bootstrap: Kind cluster + operators + OpenMRS (idempotent)
	@bash $(SCRIPTS)/bootstrap.sh

deploy-operators: ## Prerequisites only: Kind cluster + openmrs-operator chart
	@SKIP_OPENMRS=true bash $(SCRIPTS)/bootstrap.sh

deploy-openmrs: ## OpenMRS chart only: assumes operators are already running
	@SKIP_OPERATORS=true bash $(SCRIPTS)/bootstrap.sh

teardown: ## Delete the local Kind cluster (prompts for confirmation)
	@bash $(SCRIPTS)/teardown.sh

status: ## Pod summary across all namespaces
	@for ns in $(OPENMRS_NS) $(OPENMRS_OPERATOR_NS); do \
	  echo ""; echo "=== $$ns ==="; \
	  kubectl get pods -n $$ns 2>/dev/null || echo "  (not found)"; \
	done; \
	echo ""; echo "=== MariaDB CRs ==="; \
	kubectl get mariadb -A 2>/dev/null || echo "  (CRD not installed)"; \
	echo ""; echo "=== Elasticsearch CRs ==="; \
	kubectl get elasticsearch -A 2>/dev/null || echo "  (CRD not installed)"

logs: ## Stream openmrs-backend pod logs
	@kubectl logs -f -l app.kubernetes.io/name=openmrs-backend -n $(OPENMRS_NS) --max-log-requests=5

help: ## Print available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
