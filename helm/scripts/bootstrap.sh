#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib.sh"

CLUSTER_NAME="${CLUSTER_NAME:-kind}"
OPENMRS_NS="${OPENMRS_NS:-openmrs}"
OPENMRS_OPERATOR_NS="${OPENMRS_OPERATOR_NS:-openmrs-system}"
VALUES_FILE="${VALUES_FILE:-$HELM_DIR/kind-openmrs.yaml}"
SKIP_OPERATORS="${SKIP_OPERATORS:-false}"
SKIP_OPENMRS="${SKIP_OPENMRS:-false}"

KNOWN_IMAGES=(
  "mariadb:10.11"
  "openmrs/openmrs-reference-application-3-backend:nightly-0-core-2.8"
  "openmrs/openmrs-reference-application-3-frontend:nightly-0-core-2.8"
  "openmrs/openmrs-contrib-elasticsearch:8.15.3"
)

# ─────────────────────────────────────────────────────────────────────────
step "Preflight checks"
# ─────────────────────────────────────────────────────────────────────────
require_tools kind kubectl helm docker
require_docker
info "kind:    $(kind version 2>/dev/null | head -1)"
info "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null || echo 'unknown')"
info "helm:    $(helm version --short 2>/dev/null || echo 'unknown')"

# ─────────────────────────────────────────────────────────────────────────
step "Pre-pulling images (parallel)"
# ─────────────────────────────────────────────────────────────────────────
pull_pids=()
for img in "${KNOWN_IMAGES[@]}"; do
  (docker pull --platform linux/amd64 "$img" 2>&1 | sed 's/^/  /') &
  pull_pids+=($!)
done

info "Updating Helm dependencies..."
# Subchart dependencies must resolve before parent can bundle them
helm dependency update "$HELM_DIR/openmrs-backend" >/tmp/backend-dep-update.log 2>&1 || {
  warn "openmrs-backend dep update had issues:"
  cat /tmp/backend-dep-update.log
}

# Parent charts can run in parallel
helm dependency update "$HELM_DIR/openmrs" >/tmp/openmrs-dep-update.log 2>&1 &
dep_pid=$!
helm dependency update "$HELM_DIR/openmrs-operator" >/tmp/operator-dep-update.log 2>&1 &
operator_dep_pid=$!

wait "${pull_pids[@]}" || warn "Some image pulls failed (pods will pull on demand)."
success "Image pre-pull complete."

# ─────────────────────────────────────────────────────────────────────────
step "Local Docker registry"
# ─────────────────────────────────────────────────────────────────────────
ensure_registry
success "Local registry ready."

# ─────────────────────────────────────────────────────────────────────────
step "Kind cluster"
# ─────────────────────────────────────────────────────────────────────────
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  warn "Kind cluster '$CLUSTER_NAME' already exists — skipping creation."
else
  info "Creating Kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME" --config "$HELM_DIR/kind-config.yaml"
  success "Kind cluster '$CLUSTER_NAME' created."
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}" 2>/dev/null \
  || die "Cannot reach API server for context kind-${CLUSTER_NAME}."

wait "$dep_pid" 2>/dev/null || {
  warn "openmrs dep update had issues:"
  cat /tmp/openmrs-dep-update.log
}
wait "$operator_dep_pid" 2>/dev/null || {
  warn "openmrs-operator dep update had issues:"
  cat /tmp/operator-dep-update.log
}
success "Helm dependencies ready."

# ─────────────────────────────────────────────────────────────────────────
step "Pushing images to local registry"
# ─────────────────────────────────────────────────────────────────────────
connect_registry "$CLUSTER_NAME"
push_failed=0
for img in "${KNOWN_IMAGES[@]}"; do
  if docker image inspect "$img" &>/dev/null; then
    registry_push "$img" || push_failed=1
  fi
done

if [[ "$push_failed" -eq 1 ]]; then
  warn "Some images failed to push (pods will pull from registry)."
fi
success "Images cached in local registry."

# ─────────────────────────────────────────────────────────────────────────
step "openmrs-operator chart (operators + Traefik + infra)"
# ─────────────────────────────────────────────────────────────────────────
if [[ "$SKIP_OPERATORS" == "true" ]]; then
  warn "SKIP_OPERATORS=true — skipping operator chart."
else
  ensure_namespace "$OPENMRS_OPERATOR_NS"

  helm upgrade --install openmrs-operator "$HELM_DIR/openmrs-operator" \
    --namespace "$OPENMRS_OPERATOR_NS" \
    --wait \
    --timeout 10m0s

  info "Waiting for components to become ready..."

  # If Gateway API CRDs don't exist (e.g., older Kind version), install them
  GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.5.1}"
  for crd in gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io; do
    if ! kubectl get crd "$crd" &>/dev/null; then
      info "Gateway API CRDs not found — installing ${GATEWAY_API_VERSION}..."
      GATEWAY_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml"
      kubectl apply --server-side -f "$GATEWAY_URL" 2>/dev/null || kubectl apply -f "$GATEWAY_URL"
      break
    fi
  done

  for crd in \
    gateways.gateway.networking.k8s.io \
    httproutes.gateway.networking.k8s.io \
    gatewayclasses.gateway.networking.k8s.io \
    referencegrants.gateway.networking.k8s.io; do
    wait_crd "$crd"
  done
  success "Gateway API CRDs established."

  wait_deployment "$OPENMRS_OPERATOR_NS" openmrs-operator-mariadb-operator
  wait_crd "mariadbs.k8s.mariadb.com"
  success "MariaDB operator ready."

  wait_statefulset "$OPENMRS_OPERATOR_NS" elastic-operator
  wait_crd "elasticsearches.elasticsearch.k8s.elastic.co"
  success "ECK operator ready."

  wait_deployment "$OPENMRS_OPERATOR_NS" openmrs-operator-traefik
  success "Traefik ready."
  show_pods "$OPENMRS_OPERATOR_NS"
fi

# ─────────────────────────────────────────────────────────────────────────
step "OpenMRS (umbrella Helm chart)"
# ─────────────────────────────────────────────────────────────────────────
if [[ "$SKIP_OPENMRS" == "true" ]]; then
  success "Operators are ready."
  info "Run 'make deploy-openmrs' to deploy OpenMRS when you are ready."
  exit 0
fi

ensure_namespace "$OPENMRS_NS"
info "Deploying OpenMRS (this takes several minutes on first run)..."
echo ""

  helm upgrade --install openmrs "$HELM_DIR/openmrs" \
    --namespace "$OPENMRS_NS" \
    --values "$VALUES_FILE" \
    --timeout 15m0s &
helm_pid=$!

sleep 2
echo "  Initial pods:"
kubectl get pods -n "$OPENMRS_NS" 2>/dev/null || true
echo ""

while kill -0 "$helm_pid" 2>/dev/null; do
  sleep 5
done

wait "$helm_pid" || {
  error "OpenMRS Helm deployment failed."
  echo ""
  warn "=== Pod status ==="
  kubectl get pods -n "$OPENMRS_NS" || true
  echo ""
  warn "=== Recent events ==="
  kubectl get events -n "$OPENMRS_NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -25 || true
  echo ""
  warn "=== MariaDB CR status ==="
  kubectl get mariadb -n "$OPENMRS_NS" -o wide 2>/dev/null || true
  echo ""
  warn "=== Elasticsearch CR status ==="
  kubectl get elasticsearch -n "$OPENMRS_NS" -o wide 2>/dev/null || true
  exit 1
}

wait_pods_ready "$OPENMRS_NS" 900 || warn "Some pods are not yet ready — check 'kubectl get pods -n $OPENMRS_NS'"

# ─────────────────────────────────────────────────────────────────────────
step "Verify"
# ─────────────────────────────────────────────────────────────────────────
show_pods "$OPENMRS_NS"
show_pods "$OPENMRS_OPERATOR_NS"

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║       OpenMRS is ready!                          ║${RESET}"
echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════╣${RESET}"
echo -e "${GREEN}${BOLD}║${RESET}  OpenMRS web can be accessed via:              ${GREEN}${BOLD}║${RESET}"
echo -e "${GREEN}${BOLD}║${RESET}  http://localhost:8080/openmrs/spa/login       ${GREEN}${BOLD}║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
