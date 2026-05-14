#!/usr/bin/env bash
# Real-app K8s e2e for jac-scale microservice mode:
#   build image -> deploy via KubernetesMicroserviceTarget -> wait for
#   rollout -> hit gateway -> verify per-service routing -> optional
#   Ingress check -> rolling-restart zero-downtime assertion.
#
# Usage: bash k8s_microservice_real_e2e.sh <PROJECT_DIR>
#
# Env: IMAGE_TAG (default jac-microservice-e2e:dev), NAMESPACE (jac-e2e),
# USE_MINIKUBE (1), REGISTRY (unset, set for remote-cluster push).

set -euo pipefail

PROJECT_DIR="${1:-}"
if [ -z "${PROJECT_DIR}" ] || [ ! -d "${PROJECT_DIR}" ]; then
    echo "Usage: $0 <PROJECT_DIR>" >&2
    exit 1
fi
PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"
if [ ! -f "${PROJECT_DIR}/jac.toml" ]; then
    echo "FAIL: ${PROJECT_DIR}/jac.toml not found" >&2
    exit 1
fi

IMAGE_TAG="${IMAGE_TAG:-jac-microservice-e2e:dev}"
NAMESPACE="${NAMESPACE:-jac-e2e}"
USE_MINIKUBE="${USE_MINIKUBE:-1}"
REGISTRY="${REGISTRY:-}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCKERFILE_TEMPLATE="${REPO_ROOT}/jac-scale/scripts/Dockerfile.microservice"
DOCKERIGNORE_TEMPLATE="${REPO_ROOT}/jac-scale/scripts/dockerignore.microservice"
DOCKERFILE_EXP_TEMPLATE="${REPO_ROOT}/jac-scale/scripts/Dockerfile.microservice.exp"

# Use the experimental (local-source) Dockerfile when inside the jaseci
# repo; PyPI lags the K-track code so PR-time CI must install from source.
USE_LOCAL_SOURCE=0
if [ -f "${REPO_ROOT}/jac/jaclang/__init__.py" ] \
   && [ -f "${REPO_ROOT}/jac-scale/jac_scale/__init__.py" ]; then
    USE_LOCAL_SOURCE=1
fi

cleanup() {
    echo "=== cleanup ==="
    if [ -n "${PORT_FORWARD_PID:-}" ]; then
        kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    fi
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout=120s || true
    if [ "${USE_LOCAL_SOURCE}" != "1" ]; then
        rm -f "${PROJECT_DIR}/Dockerfile" "${PROJECT_DIR}/.dockerignore" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [ "${USE_LOCAL_SOURCE}" = "1" ]; then
    echo "=== local-source build (Dockerfile.microservice.exp) ==="
    PROJECT_REL="${PROJECT_DIR#${REPO_ROOT}/}"
    if [ "${PROJECT_REL}" = "${PROJECT_DIR}" ]; then
        echo "FAIL: PROJECT_DIR (${PROJECT_DIR}) is not under REPO_ROOT (${REPO_ROOT})" >&2
        exit 1
    fi
    BUILD_CWD="${REPO_ROOT}"
    BUILD_FILE="${DOCKERFILE_EXP_TEMPLATE}"
    BUILD_ARGS="--build-arg PROJECT_PATH=${PROJECT_REL}"
else
    echo "=== copy Dockerfile + .dockerignore into ${PROJECT_DIR} ==="
    cp "${DOCKERFILE_TEMPLATE}" "${PROJECT_DIR}/Dockerfile"
    cp "${DOCKERIGNORE_TEMPLATE}" "${PROJECT_DIR}/.dockerignore"
    BUILD_CWD="${PROJECT_DIR}"
    BUILD_FILE="${PROJECT_DIR}/Dockerfile"
    BUILD_ARGS=""
fi

if [ "${USE_MINIKUBE}" = "1" ]; then
    echo "=== build inside minikube's docker daemon ==="
    eval "$(minikube docker-env)"
    # shellcheck disable=SC2086
    docker build -f "${BUILD_FILE}" ${BUILD_ARGS} -t "${IMAGE_TAG}" "${BUILD_CWD}"
elif [ -n "${REGISTRY}" ]; then
    echo "=== build + push to ${REGISTRY} ==="
    FULL_IMAGE="${REGISTRY}/${IMAGE_TAG}"
    # shellcheck disable=SC2086
    docker build -f "${BUILD_FILE}" ${BUILD_ARGS} -t "${FULL_IMAGE}" "${BUILD_CWD}"
    docker push "${FULL_IMAGE}"
    IMAGE_TAG="${FULL_IMAGE}"
else
    echo "FAIL: USE_MINIKUBE=0 but REGISTRY unset" >&2
    exit 1
fi

echo "=== deploy via KubernetesMicroserviceTarget ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

cd "${PROJECT_DIR}"
python - <<PYEOF
import sys, jaclang  # noqa: F401
from jac_scale.microservices.k8s_target import KubernetesMicroserviceTarget
from jac_scale.targets.kubernetes.kubernetes_config import KubernetesConfig
from jac_scale.abstractions.config.app_config import AppConfig

target = KubernetesMicroserviceTarget(
    config=KubernetesConfig(
        app_name="jac-e2e",
        namespace="${NAMESPACE}",
        container_port=8000,
        python_image="${IMAGE_TAG}",
    ),
)
result = target.deploy(AppConfig(code_folder=".", app_name="jac-e2e", build=False))
if not result.success:
    print(f"deploy failed: {result.message}", file=sys.stderr)
    sys.exit(1)
print(f"deploy: {result.message}")
PYEOF

echo "=== wait for pods Ready ==="
dump_pod_state() {
    kubectl get pods -n "${NAMESPACE}" -o wide || true
    kubectl describe pods -n "${NAMESPACE}" || true
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp || true
    for app in gateway $(kubectl get pods -n "${NAMESPACE}" -l managed=jac-scale -o jsonpath='{.items[*].metadata.labels.app}' 2>/dev/null | tr ' ' '\n' | sort -u | grep -v '^gateway$' || true); do
        kubectl logs -n "${NAMESPACE}" -l "app=${app}" --tail=200 --all-containers=true || true
        kubectl logs -n "${NAMESPACE}" -l "app=${app}" --tail=200 --previous=true 2>/dev/null || true
    done
}

for dep in $(kubectl get deployments -n "${NAMESPACE}" -l managed=jac-scale -o name); do
    echo "  waiting on ${dep}..."
    if ! kubectl rollout status "${dep}" -n "${NAMESPACE}" --timeout=180s; then
        echo "FAIL: rollout for ${dep} did not complete in 180s"
        dump_pod_state
        exit 1
    fi
done

echo "=== port-forward gateway + curl /health ==="
GATEWAY_LOCAL_PORT="${GATEWAY_LOCAL_PORT:-18000}"
kubectl port-forward -n "${NAMESPACE}" svc/gateway-service "${GATEWAY_LOCAL_PORT}:8000" >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 2
if ! curl -fsS "http://localhost:${GATEWAY_LOCAL_PORT}/health" >/dev/null; then
    echo "FAIL: gateway /health did not return 200" >&2
    kubectl logs -n "${NAMESPACE}" -l app=gateway --tail=50 || true
    exit 1
fi
echo "  /health OK"

echo "=== verify per-service routing ==="
# 503 from the gateway means upstream service unreachable; 404/405 means
# we reached a healthy service that just doesn't have that walker.
ROUTES=$(python -c "
import tomllib
with open('${PROJECT_DIR}/jac.toml', 'rb') as f:
    cfg = tomllib.load(f)
for prefix in cfg.get('plugins', {}).get('scale', {}).get('microservices', {}).get('routes', {}).values():
    print(prefix)
")
for prefix in ${ROUTES}; do
    code=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:${GATEWAY_LOCAL_PORT}${prefix}/walker/__missing__" || echo "000")
    if [ "${code}" = "503" ] || [ "${code}" = "000" ]; then
        echo "FAIL: route ${prefix} got ${code} (gateway can't reach service)"
        exit 1
    fi
    echo "  ${prefix}/walker/__missing__ -> ${code}"
done

echo "=== optional Ingress test ==="
INGRESS_INFO=$(python - <<PYEOF
import tomllib
with open("${PROJECT_DIR}/jac.toml", "rb") as f:
    cfg = tomllib.load(f)
ing = cfg.get("plugins", {}).get("scale", {}).get("microservices", {}).get("ingress", {})
print(f"{int(bool(ing.get('enabled', False)))}|{str(ing.get('host', '')).strip()}")
PYEOF
)
INGRESS_ENABLED="${INGRESS_INFO%%|*}"
INGRESS_HOST="${INGRESS_INFO#*|}"

if [ "${INGRESS_ENABLED}" != "1" ] || [ "${USE_MINIKUBE}" != "1" ]; then
    echo "  skipping (ingress disabled or non-minikube)"
else
    if ! kubectl get ingress gateway-ingress -n "${NAMESPACE}" >/dev/null 2>&1; then
        echo "FAIL: ingress.enabled is true but gateway-ingress wasn't created"
        exit 1
    fi
    if ! kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller \
            --no-headers 2>/dev/null | grep -q "Running"; then
        echo "  WARN: nginx-ingress controller not running (minikube addons enable ingress); skipping"
    else
        MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "")
        HOST_HEADER="${INGRESS_HOST:-localhost}"
        # NGINX Ingress reloads upstream config a few seconds after a
        # Service's endpoints change - retry through that propagation lag.
        INGRESS_CODE="000"
        for attempt in $(seq 1 15); do
            INGRESS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
                -H "Host: ${HOST_HEADER}" "http://${MINIKUBE_IP}/health" || echo "000")
            [ "${INGRESS_CODE}" = "200" ] && break
            echo "  Ingress attempt ${attempt}/15 returned ${INGRESS_CODE}, retrying in 2s..."
            sleep 2
        done
        if [ "${INGRESS_CODE}" != "200" ]; then
            echo "FAIL: Ingress -> /health got '${INGRESS_CODE}' after 15 retries"
            kubectl describe ingress gateway-ingress -n "${NAMESPACE}" || true
            kubectl get endpoints gateway-service -n "${NAMESPACE}" -o yaml || true
            exit 1
        fi
        echo "  Ingress /health = 200"
    fi
fi

# Zero-downtime rolling-restart assertion: hammer at 10 req/s while
# kubectl rollout restart runs; non-2xx (or non-accept_re) responses
# count as violations. Used for both gateway and a representative service.
run_zero_downtime_assertion() {
    local label="$1"
    local url="$2"
    local accept_re="$3"
    local deployment="$4"
    local host_header="${5:-}"
    local max_violation_pct="${6:-0}"

    echo "=== rolling restart [${label}]: hammer ${url}, max ${max_violation_pct}% violations of ${accept_re} ==="
    local log
    log=$(mktemp)
    (
        while true; do
            if [ -n "${host_header}" ]; then
                code=$(curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 \
                    -H "Host: ${host_header}" "${url}" 2>/dev/null || echo "000")
            else
                code=$(curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 \
                    "${url}" 2>/dev/null || echo "000")
            fi
            echo "${code}" >>"${log}"
            sleep 0.1
        done
    ) &
    local hammer_pid=$!
    trap 'kill '"${hammer_pid}"' 2>/dev/null || true; cleanup' EXIT

    kubectl rollout restart "deployment/${deployment}" -n "${NAMESPACE}"
    kubectl rollout status "deployment/${deployment}" -n "${NAMESPACE}" --timeout=180s

    kill "${hammer_pid}" 2>/dev/null || true
    wait "${hammer_pid}" 2>/dev/null || true
    sleep 1

    local total bad pct
    total=$(wc -l <"${log}" | tr -d ' ')
    bad=$(awk -v re="^(${accept_re})$" '$1 !~ re { print }' "${log}" | wc -l | tr -d ' ')
    if [ "${total}" -gt 0 ]; then
        pct=$(( (bad * 100 + total - 1) / total ))
    else
        pct=0
    fi
    echo "  ${label}: ${total} requests, ${bad} violations (${pct}%)"
    sort "${log}" | uniq -c | awk '{ printf "    %5d  %s\n", $1, $2 }'
    if [ "${pct}" -gt "${max_violation_pct}" ]; then
        echo "FAIL [${label}]: ${pct}% violations exceeds ${max_violation_pct}%"
        exit 1
    fi
}

# Phase 1: gateway rollout - direct /health, expect zero non-200.
run_zero_downtime_assertion "gateway" \
    "http://localhost:${GATEWAY_LOCAL_PORT}/health" "200" "gateway-deployment"

# Phase 2: service rollout via the first declared route. Allow 5%
# tolerance for transient endpoint-propagation noise.
FIRST_PREFIX=$(echo "${ROUTES}" | head -n1)
FIRST_SVC=$(python -c "
import tomllib
with open('${PROJECT_DIR}/jac.toml', 'rb') as f:
    cfg = tomllib.load(f)
for name, prefix in cfg.get('plugins', {}).get('scale', {}).get('microservices', {}).get('routes', {}).items():
    if prefix == '${FIRST_PREFIX}':
        print(name.replace('_', '-'))
        break
")
if [ -z "${FIRST_PREFIX}" ] || [ -z "${FIRST_SVC}" ]; then
    echo "  (no services declared; skipping service-rollout phase)"
elif [ "${INGRESS_ENABLED}" = "1" ] && [ "${USE_MINIKUBE}" = "1" ] && [ -n "${MINIKUBE_IP:-}" ]; then
    run_zero_downtime_assertion "service:${FIRST_SVC} (ingress)" \
        "http://${MINIKUBE_IP}${FIRST_PREFIX}/walker/__missing__" \
        "200|404|405" "${FIRST_SVC}-deployment" "${INGRESS_HOST:-localhost}" "5"
else
    run_zero_downtime_assertion "service:${FIRST_SVC} (port-forward)" \
        "http://localhost:${GATEWAY_LOCAL_PORT}${FIRST_PREFIX}/walker/__missing__" \
        "200|404|405|000" "${FIRST_SVC}-deployment" "" "5"
fi

echo "=== K8s microservice REAL e2e PASSED ==="
