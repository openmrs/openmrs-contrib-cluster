#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CLUSTER_NAME="${CLUSTER_NAME:-kind}"
OPENMRS_OPERATOR_NS="${OPENMRS_OPERATOR_NS:-openmrs-system}"

step "Teardown: openmrs local cluster"
warn "This will delete Kind cluster '${CLUSTER_NAME}' and ALL local data (PVCs, secrets)."
read -r -p "  Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

if helm_installed openmrs-operator "$OPENMRS_OPERATOR_NS"; then
  helm uninstall openmrs-operator -n "$OPENMRS_OPERATOR_NS" 2>/dev/null
  kubectl delete namespace "$OPENMRS_OPERATOR_NS" --ignore-not-found 2>/dev/null
  success "openmrs-operator uninstalled."
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  kind delete cluster --name "$CLUSTER_NAME"
  success "Cluster '$CLUSTER_NAME' deleted."
else
  warn "Cluster '$CLUSTER_NAME' not found — nothing to delete."
fi

success "Teardown complete."
