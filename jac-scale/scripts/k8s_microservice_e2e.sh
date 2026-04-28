#!/usr/bin/env bash
# K8s microservice mode e2e smoke test.
#
# Validates the K-track manifest pipeline produces real K8s objects
# against a live cluster. Does NOT need a real app image - the test
# uses `python:3.12` as a placeholder so pods will CrashLoopBackOff,
# but the K8s OBJECTS (Deployment, Service, HPA, PDB) are what we
# assert against. That validates:
#   - K1's image-flow + factory dispatch wiring
#   - K2's manifest shape (Deployment + ClusterIP Service)
#   - K3's apply lifecycle (read-patch-or-create, label-selector destroy)
#   - K5's rolling-deploy fields (RollingUpdate + readiness + preStop +
#     terminationGracePeriodSeconds)
#   - K6's HPA + PDB emission
#   - K7's per-service config layering (replicas, resources, env,
#     hpa/pdb opt-out)
# all the way through to a real K8s API server.
#
# Usage:
#   bash jac-scale/scripts/k8s_microservice_e2e.sh
#
# Requires:
#   - kubectl pointing at a working cluster (minikube, kind, EKS, etc.)
#   - jac + jac-scale[deploy] installed in the active Python env
#
# Env:
#   NAMESPACE: target namespace (default jac-e2e). Created + deleted
#              by the script; safe to re-run.

set -euo pipefail

NAMESPACE="${NAMESPACE:-jac-e2e}"

cleanup() {
    echo "=== cleanup: deleting namespace '${NAMESPACE}' ==="
    kubectl delete namespace "${NAMESPACE}" \
        --ignore-not-found --timeout=60s || true
}
trap cleanup EXIT

echo "=== K8s microservice e2e: setup ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "=== deploy: generate + apply manifests via KubernetesMicroserviceTarget ==="
python - <<PYEOF
import sys

# Activate jaclang's import hook so .jac submodules under jac_scale
# are importable from plain Python (jac_scale's __init__.py is empty
# so just `import jac_scale` doesn't auto-bootstrap jaclang).
import jaclang  # noqa: F401

from jac_scale.microservices.k8s_target import KubernetesMicroserviceTarget
from jac_scale.targets.kubernetes.kubernetes_config import KubernetesConfig
from jac_scale.abstractions.config.app_config import AppConfig

# Stub the microservices config so we don't need a jac.toml fixture.
# Two services exercise the K7 surface:
#   orders_app: resources + env override
#   cart_app:   replicas=2 override + hpa.enabled=false (opt-out)
import jac_scale.config_loader as cfg_mod

class _Stub:
    def get_microservices_config(self):
        return {
            "routes": {
                "orders_app": "/api/orders",
                "cart_app": "/api/cart",
            },
            "services": {
                "orders_app": {
                    "cpu_request": "100m",
                    "memory_request": "64Mi",
                    "env": {"TEST_MARKER": "orders"},
                },
                "cart_app": {
                    "replicas": 2,
                    "hpa": {"enabled": False},
                },
            },
            "drain_timeout_seconds": 10,
        }

cfg_mod.get_scale_config = lambda: _Stub()

target = KubernetesMicroserviceTarget(
    config=KubernetesConfig(
        app_name="jac-e2e",
        namespace="${NAMESPACE}",
        container_port=8000,
        python_image="python:3.12",  # placeholder, not a real app
    ),
)

result = target.deploy(
    AppConfig(code_folder=".", app_name="jac-e2e", build=False)
)

if not result.success:
    print(f"deploy failed: {result.message}")
    sys.exit(1)

print(f"deploy: {result.message}")
print("manifest counts:")
print(f"  deployments: {sorted(result.details['deployments'].keys())}")
print(f"  services:    {sorted(result.details['services'].keys())}")
print(f"  hpas:        {sorted(result.details['hpas'].keys())}")
print(f"  pdbs:        {sorted(result.details['pdbs'].keys())}")
PYEOF

echo "=== assert K8s objects exist in '${NAMESPACE}' ==="

count() {
    kubectl get "${1}" -n "${NAMESPACE}" -l managed=jac-scale \
        -o name 2>/dev/null | wc -l | tr -d ' '
}

DEP_COUNT=$(count deployments)
SVC_COUNT=$(count services)
HPA_COUNT=$(count hpa)
PDB_COUNT=$(count pdb)

# Expected: orders_app + cart_app + gateway = 3 of each, EXCEPT HPA
# where cart_app opted out via hpa.enabled=false -> 2 HPAs.
if [ "${DEP_COUNT}" -ne 3 ]; then
    echo "FAIL: expected 3 Deployments, got ${DEP_COUNT}"
    exit 1
fi
if [ "${SVC_COUNT}" -ne 3 ]; then
    echo "FAIL: expected 3 Services, got ${SVC_COUNT}"
    exit 1
fi
if [ "${HPA_COUNT}" -ne 2 ]; then
    echo "FAIL: expected 2 HPAs (cart_app opted out), got ${HPA_COUNT}"
    exit 1
fi
if [ "${PDB_COUNT}" -ne 3 ]; then
    echo "FAIL: expected 3 PDBs, got ${PDB_COUNT}"
    exit 1
fi

echo "=== verify K7 config landed in manifests ==="

ORDERS_CPU=$(kubectl get deployment orders-app-deployment \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
if [ "${ORDERS_CPU}" != "100m" ]; then
    echo "FAIL: expected orders_app cpu_request=100m, got '${ORDERS_CPU}'"
    exit 1
fi

ORDERS_MARKER=$(kubectl get deployment orders-app-deployment \
    -n "${NAMESPACE}" \
    -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name=='TEST_MARKER')].value}")
if [ "${ORDERS_MARKER}" != "orders" ]; then
    echo "FAIL: expected orders_app TEST_MARKER=orders, got '${ORDERS_MARKER}'"
    exit 1
fi

CART_REPLICAS=$(kubectl get deployment cart-app-deployment \
    -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')
if [ "${CART_REPLICAS}" != "2" ]; then
    echo "FAIL: expected cart_app replicas=2, got '${CART_REPLICAS}'"
    exit 1
fi

echo "=== verify K5 rolling-deploy wires landed ==="

READINESS_PATH=$(kubectl get deployment orders-app-deployment \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')
if [ "${READINESS_PATH}" != "/healthz" ]; then
    echo "FAIL: expected readinessProbe path /healthz, got '${READINESS_PATH}'"
    exit 1
fi

GRACE=$(kubectl get deployment orders-app-deployment \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}')
# Default drain_timeout_seconds=10 + 5 cushion = 15
if [ "${GRACE}" != "15" ]; then
    echo "FAIL: expected terminationGracePeriodSeconds=15, got '${GRACE}'"
    exit 1
fi

ROLLING_TYPE=$(kubectl get deployment orders-app-deployment \
    -n "${NAMESPACE}" -o jsonpath='{.spec.strategy.type}')
if [ "${ROLLING_TYPE}" != "RollingUpdate" ]; then
    echo "FAIL: expected strategy.type=RollingUpdate, got '${ROLLING_TYPE}'"
    exit 1
fi

echo "=== destroy + verify cleanup ==="
python - <<PYEOF
import jaclang  # noqa: F401  - activate .jac import hook

from jac_scale.microservices.k8s_target import KubernetesMicroserviceTarget
from jac_scale.targets.kubernetes.kubernetes_config import KubernetesConfig

target = KubernetesMicroserviceTarget(
    config=KubernetesConfig(app_name="jac-e2e", namespace="${NAMESPACE}"),
)
target.destroy("jac-e2e")
PYEOF

# K8s controllers take a moment to actually remove the objects after
# the API call returns; poll until empty or timeout.
for i in 1 2 3 4 5 6 7 8 9 10; do
    DEP_AFTER=$(count deployments)
    SVC_AFTER=$(count services)
    HPA_AFTER=$(count hpa)
    PDB_AFTER=$(count pdb)
    TOTAL_AFTER=$((DEP_AFTER + SVC_AFTER + HPA_AFTER + PDB_AFTER))
    if [ "${TOTAL_AFTER}" -eq 0 ]; then
        break
    fi
    sleep 2
done

if [ "${TOTAL_AFTER}" -ne 0 ]; then
    echo "FAIL: destroy left resources after 20s:"
    echo "  deployments=${DEP_AFTER}, services=${SVC_AFTER}, hpas=${HPA_AFTER}, pdbs=${PDB_AFTER}"
    exit 1
fi

echo "=== K8s microservice e2e PASSED ==="
