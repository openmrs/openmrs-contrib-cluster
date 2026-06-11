#!/usr/bin/env bash
# lib.sh — shared helpers for openmrs bootstrap scripts
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR ]${RESET}  $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Spinner ─────────────────────────────────────────────────────────────────
_STEP_PID=""
_STEP_ACTIVE=false

_cleanup_spinner() {
  if [[ "$_STEP_ACTIVE" == true ]]; then
    [[ -n "$_STEP_PID" ]] && kill "$_STEP_PID" 2>/dev/null || true
    _STEP_PID=""
    _STEP_ACTIVE=false
  fi
}
trap _cleanup_spinner EXIT

_spinner() {
  local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local i=0
  while true; do
    printf "\r${GREEN}  %s${RESET} Working..." "${chars:$i:1}"
    i=$(( (i + 1) % ${#chars} ))
    sleep 0.1
  done
}

step() {
  echo -e "\n${BOLD}━━━  $*  ━━━${RESET}"
  _STEP_ACTIVE=true
  _spinner &
  _STEP_PID=$!
}

end_step() {
  [[ "$_STEP_ACTIVE" == false ]] && return
  _STEP_ACTIVE=false
  [[ -n "$_STEP_PID" ]] && kill "$_STEP_PID" 2>/dev/null || true
  wait "$_STEP_PID" 2>/dev/null || true
  _STEP_PID=""
  printf "\r${GREEN}  ✓${RESET} Done\n"
}

require_tools() {
  local missing=()
  for tool in "$@"; do
    command -v "$tool" &>/dev/null || missing+=("$tool")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "Missing required tools: ${missing[*]}"
}

require_docker() {
  docker info &>/dev/null || die "Docker daemon is not running. Start Docker and re-run."
}

ensure_namespace() {
  local ns="$1"
  kubectl get namespace "$ns" &>/dev/null || kubectl create namespace "$ns"
}

wait_crd() {
  local crd="$1" timeout="${2:-120}" elapsed=0
  echo -n "  ⏳ Waiting for CRD: ${crd}..."
  until kubectl get crd "$crd" &>/dev/null; do
    sleep 2
    elapsed=$((elapsed + 2))
    [[ $elapsed -ge $timeout ]] && { echo " timed out"; die "Timed out waiting for CRD $crd"; }
  done
  kubectl wait --for=condition=Established "crd/$crd" --timeout="${timeout}s" >/dev/null 2>&1 \
    || { echo " failed"; die "CRD $crd never reached Established state."; }
  echo -e " \033[32mready\033[0m"
}

wait_deployment() {
  local ns="$1" name="$2" timeout="${3:-180}"
  kubectl rollout status "deployment/$name" -n "$ns" --timeout="${timeout}s" \
    || die "Deployment $name in $ns did not become ready."
  success "Deployment ready: $name"
}

wait_statefulset() {
  local ns="$1" name="$2" timeout="${3:-180}"
  kubectl rollout status "statefulset/$name" -n "$ns" --timeout="${timeout}s" \
    || die "StatefulSet $name in $ns did not become ready."
  success "StatefulSet ready: $name"
}

helm_installed() {
  local release="$1" ns="$2"
  helm status "$release" -n "$ns" &>/dev/null
}

show_pods() {
  local ns="$1"
  kubectl get namespace "$ns" &>/dev/null || return
  echo ""
  kubectl get pods -n "$ns" 2>/dev/null || true
  echo ""
}

wait_pods_ready() {
  local ns="$1" timeout="${2:-900}" elapsed=0
  echo "  Waiting for all pods in $ns to be ready..."
  while [[ $elapsed -lt $timeout ]]; do
    local all_ready=true
    while IFS= read -r line; do
      local ready status
      ready=$(echo "$line" | awk '{print $2}')
      status=$(echo "$line" | awk '{print $3}')
      [[ "$status" == "Completed" ]] && continue
      local expected="${ready%/*}" actual="${ready#*/}"
      [[ "$expected" != "$actual" ]] && { all_ready=false; break; }
    done < <(kubectl get pods -n "$ns" --no-headers 2>/dev/null || true)
    $all_ready && { echo "  All pods ready."; return 0; }
    sleep 10
    elapsed=$((elapsed+10))
  done
  echo "  Timed out waiting for pods."
  return 1
}

ensure_registry() {
  if docker container inspect kind-registry &>/dev/null; then
    return 0
  fi
  docker run -d --restart=always -p 127.0.0.1:5001:5000 --name kind-registry registry:2 >/dev/null 2>&1
  # Wait for registry to become healthy
  for i in $(seq 1 15); do
    curl -s http://127.0.0.1:5001/v2/ >/dev/null 2>&1 && return 0
    sleep 1
  done
  die "Local Docker registry failed to start."
}

connect_registry() {
  local network="${1:-kind}"
  if docker inspect kind-registry --format '{{json .NetworkSettings.Networks}}' 2>/dev/null | grep -q "\"$network\""; then
    return 0
  fi
  docker network connect "$network" kind-registry 2>/dev/null || true
}

registry_push() {
  local img="$1"
  local registry="${2:-localhost:5001}"
  local dest="$registry/$img"
  docker tag "$img" "$dest" 2>/dev/null
  docker push "$dest" >/dev/null 2>&1 || {
    warn "Failed to push $img to local registry (pods will pull from Docker Hub)."
    return 1
  }
  return 0
}
