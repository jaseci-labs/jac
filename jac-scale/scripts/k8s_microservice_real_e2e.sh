#!/usr/bin/env bash
# Real-app K8s e2e for jac-scale microservice mode (K9).
#
# Unlike `k8s_microservice_e2e.sh` (which uses python:3.12 as a
# placeholder image so pods CrashLoopBackOff), this script:
#   1. Builds a real image from a real jac-scale microservice project
#   2. Loads it into minikube (or pushes if you set REGISTRY env)
#   3. Deploys via the K-track pipeline
#   4. Waits for pods to ACTUALLY become ready (readinessProbe pass)
#   5. Curls the gateway through a port-forward
#   6. Triggers a rolling restart and verifies no requests are dropped
#   7. Tears down
#
# Usage:
#   bash jac-scale/scripts/k8s_microservice_real_e2e.sh <PROJECT_DIR>
#
# Example:
#   bash jac-scale/scripts/k8s_microservice_real_e2e.sh \
#       /home/user/projects/jaseci/jaseci/.local-docs/micr-s-example
#
# Requires:
#   - kubectl + a working cluster (minikube assumed; use `kind` or
#     remote with REGISTRY env to override)
#   - docker (or podman, alias docker=podman)
#   - jac + jac-scale[deploy] in the active Python env
#   - The PROJECT_DIR must have a jac.toml with
#     [plugins.scale.microservices].enabled = true and a non-empty
#     [plugins.scale.microservices.routes] table.
#
# Env overrides:
#   IMAGE_TAG         default: jac-microservice-e2e:dev
#   NAMESPACE         default: jac-e2e
#   USE_MINIKUBE      default: 1 (set to 0 to skip `minikube image load`
#                     and rely on docker push to a configured REGISTRY)
#   REGISTRY          default: unset; set to "myregistry.io/myorg"
#                     to push instead of using minikube's docker daemon

set -euo pipefail

PROJECT_DIR="${1:-}"
if [ -z "${PROJECT_DIR}" ] || [ ! -d "${PROJECT_DIR}" ]; then
    echo "Usage: $0 <PROJECT_DIR>" >&2
    echo "  PROJECT_DIR must be a directory with jac.toml" >&2
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

# Resolve the jac-scale repo root (for the Dockerfile template).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCKERFILE_TEMPLATE="${REPO_ROOT}/jac-scale/scripts/Dockerfile.microservice"
DOCKERIGNORE_TEMPLATE="${REPO_ROOT}/jac-scale/scripts/dockerignore.microservice"
if [ ! -f "${DOCKERFILE_TEMPLATE}" ]; then
    echo "FAIL: Dockerfile template not found at ${DOCKERFILE_TEMPLATE}" >&2
    exit 1
fi

cleanup() {
    echo "=== cleanup ==="
    if [ -n "${PORT_FORWARD_PID:-}" ]; then
        kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    fi
    kubectl delete namespace "${NAMESPACE}" \
        --ignore-not-found --timeout=120s || true
    # Remove the Dockerfile we copied in (don't pollute the user's tree).
    rm -f "${PROJECT_DIR}/Dockerfile" "${PROJECT_DIR}/.dockerignore" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== copy Dockerfile + .dockerignore into ${PROJECT_DIR} ==="
cp "${DOCKERFILE_TEMPLATE}" "${PROJECT_DIR}/Dockerfile"
cp "${DOCKERIGNORE_TEMPLATE}" "${PROJECT_DIR}/.dockerignore"

if [ "${USE_MINIKUBE}" = "1" ]; then
    echo "=== build image inside minikube's docker daemon ==="
    eval "$(minikube docker-env)"
    docker build -t "${IMAGE_TAG}" "${PROJECT_DIR}"
    # No push needed - the image is in minikube's daemon already.
elif [ -n "${REGISTRY}" ]; then
    echo "=== build + push to ${REGISTRY} ==="
    FULL_IMAGE="${REGISTRY}/${IMAGE_TAG}"
    docker build -t "${FULL_IMAGE}" "${PROJECT_DIR}"
    docker push "${FULL_IMAGE}"
    IMAGE_TAG="${FULL_IMAGE}"
else
    echo "FAIL: USE_MINIKUBE=0 but REGISTRY env is unset" >&2
    exit 1
fi

echo "=== deploy via KubernetesMicroserviceTarget ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

cd "${PROJECT_DIR}"
python - <<PYEOF
import sys

from jac_scale.microservices.k8s_target import KubernetesMicroserviceTarget
from jac_scale.targets.kubernetes.kubernetes_config import KubernetesConfig
from jac_scale.abstractions.config.app_config import AppConfig

# Use the project's actual jac.toml (no stubbing - real config).
target = KubernetesMicroserviceTarget(
    config=KubernetesConfig(
        app_name="jac-e2e",
        namespace="${NAMESPACE}",
        container_port=8000,
        # python_image is the fallback when build=False; with the real
        # image already loaded into minikube, set it directly so the
        # pod-spec references the right tag.
        python_image="${IMAGE_TAG}",
    ),
)

result = target.deploy(
    AppConfig(code_folder=".", app_name="jac-e2e", build=False)
)
if not result.success:
    print(f"deploy failed: {result.message}", file=sys.stderr)
    sys.exit(1)
print(f"deploy: {result.message}")
PYEOF

echo "=== wait for pods to become ready ==="
# Wait up to 3 minutes for ALL Deployments to roll out. Real readiness
# probes pass means the entrypoint dispatched, jac started, and
# /healthz responds.
for dep in $(kubectl get deployments -n "${NAMESPACE}" -l managed=jac-scale -o name); do
    echo "  waiting on ${dep}..."
    kubectl rollout status "${dep}" -n "${NAMESPACE}" --timeout=180s
done

echo "=== port-forward gateway + curl /health ==="
GATEWAY_LOCAL_PORT="${GATEWAY_LOCAL_PORT:-18000}"
kubectl port-forward -n "${NAMESPACE}" \
    svc/gateway-service "${GATEWAY_LOCAL_PORT}:8000" >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
# Give the port-forward a moment to bind.
sleep 2

if ! curl -fsS "http://localhost:${GATEWAY_LOCAL_PORT}/health" >/dev/null; then
    echo "FAIL: gateway /health did not return 200" >&2
    kubectl logs -n "${NAMESPACE}" -l app=gateway --tail=50 || true
    exit 1
fi
echo "  /health OK"

# Verify per-service routing. We don't know the user's endpoints
# specifically, so just check each service's path-prefix returns
# something other than 503 SERVICE_UNAVAILABLE (which would mean the
# gateway can't reach the service).
echo "=== verify per-service routing (gateway -> services) ==="
ROUTES=$(python -c "
import os
import tomllib
with open('${PROJECT_DIR}/jac.toml', 'rb') as f:
    cfg = tomllib.load(f)
routes = cfg.get('plugins', {}).get('scale', {}).get('microservices', {}).get('routes', {})
for name, prefix in routes.items():
    print(prefix)
")

for prefix in ${ROUTES}; do
    # Hit the prefix root + an obviously-not-a-route path; we don't
    # require a 200 (paths vary), but 503 means the upstream service
    # is unreachable, which is the failure we want to catch.
    code=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:${GATEWAY_LOCAL_PORT}${prefix}/walker/__missing__" || echo "000")
    if [ "${code}" = "503" ] || [ "${code}" = "000" ]; then
        echo "FAIL: route ${prefix} got ${code} (gateway can't reach service)"
        exit 1
    fi
    echo "  ${prefix}/walker/__missing__ -> ${code} (gateway reached upstream)"
done

# K10: if the project's jac.toml has [...microservices.ingress].enabled = true,
# also exercise the Ingress path. Skipped silently otherwise so users
# without ingress configured still get the rest of the e2e.
echo "=== K10: optional Ingress path test ==="
INGRESS_INFO=$(python - <<PYEOF
import tomllib
with open("${PROJECT_DIR}/jac.toml", "rb") as f:
    cfg = tomllib.load(f)
ing = cfg.get("plugins", {}).get("scale", {}).get("microservices", {}).get("ingress", {})
enabled = bool(ing.get("enabled", False))
host = str(ing.get("host", "")).strip()
print(f"{int(enabled)}|{host}")
PYEOF
)
INGRESS_ENABLED="${INGRESS_INFO%%|*}"
INGRESS_HOST="${INGRESS_INFO#*|}"

if [ "${INGRESS_ENABLED}" != "1" ]; then
    echo "  skipping (ingress.enabled is not set in jac.toml)"
elif [ "${USE_MINIKUBE}" != "1" ]; then
    echo "  skipping (Ingress test only runs against minikube; remote-cluster tests need controller-specific setup)"
else
    echo "  ingress.enabled = true (host: '${INGRESS_HOST:-<any>}')"

    # Verify the Ingress object exists.
    if ! kubectl get ingress gateway-ingress -n "${NAMESPACE}" >/dev/null 2>&1; then
        echo "FAIL: ingress.enabled is true but gateway-ingress wasn't created"
        kubectl get ingress -n "${NAMESPACE}" || true
        exit 1
    fi
    echo "  gateway-ingress exists"

    # Make sure the nginx-ingress controller is running (minikube
    # `ingress` addon enables it). Without this, the Ingress object
    # exists but no controller serves it -> our curl hangs.
    if ! kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller \
            --no-headers 2>/dev/null | grep -q "Running"; then
        echo "  WARN: nginx-ingress controller not running. Enable with:"
        echo "        minikube addons enable ingress"
        echo "  skipping Ingress request test"
    else
        # minikube exposes the ingress controller on the minikube IP
        # at port 80 by default. We curl with a Host header to match
        # the configured ingress.host (or any host if none set).
        MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "")
        if [ -z "${MINIKUBE_IP}" ]; then
            echo "  WARN: minikube ip returned empty; skipping Ingress request"
        else
            HOST_HEADER="${INGRESS_HOST:-localhost}"
            INGRESS_CODE=$(curl -s -o /dev/null \
                -w "%{http_code}" \
                --max-time 10 \
                -H "Host: ${HOST_HEADER}" \
                "http://${MINIKUBE_IP}/health" || echo "000")
            if [ "${INGRESS_CODE}" != "200" ]; then
                echo "FAIL: Ingress -> /health expected 200, got '${INGRESS_CODE}'"
                kubectl describe ingress gateway-ingress -n "${NAMESPACE}" || true
                kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=30 || true
                exit 1
            fi
            echo "  Ingress -> /health = 200 (host=${HOST_HEADER}, ip=${MINIKUBE_IP})"
        fi
    fi
fi

echo "=== rolling restart: hammer gateway, expect zero non-2xx ==="
# Background curl loop hitting /health while we trigger a rollout. With
# K5's RollingUpdate + readiness + grace + preStop, no request should
# observe a 503 or connection error during the rolling update window.
LOG=$(mktemp)
(
    while true; do
        code=$(curl -s -o /dev/null -w "%{http_code}\n" \
            "http://localhost:${GATEWAY_LOCAL_PORT}/health" || echo "000")
        echo "${code}" >>"${LOG}"
        sleep 0.05
    done
) &
HAMMER_PID=$!
trap 'kill ${HAMMER_PID} 2>/dev/null || true; cleanup' EXIT

# Rollout-restart the gateway (the most user-impacting one).
kubectl rollout restart deployment/gateway-deployment -n "${NAMESPACE}"
kubectl rollout status deployment/gateway-deployment -n "${NAMESPACE}" --timeout=180s

# Stop the hammer + wait for any in-flight curls.
kill "${HAMMER_PID}" 2>/dev/null || true
wait "${HAMMER_PID}" 2>/dev/null || true
sleep 1

NON_2XX=$(awk '{ if ($1 < 200 || $1 >= 300) print }' "${LOG}" | wc -l | tr -d ' ')
TOTAL=$(wc -l <"${LOG}" | tr -d ' ')
echo "  rollout requests: ${TOTAL}, non-2xx: ${NON_2XX}"
if [ "${NON_2XX}" -gt 0 ]; then
    echo "FAIL: ${NON_2XX} non-2xx responses during rolling restart"
    awk '{ if ($1 < 200 || $1 >= 300) print }' "${LOG}" | sort | uniq -c
    exit 1
fi

echo "=== K8s microservice REAL e2e PASSED (zero requests dropped during rollout) ==="
