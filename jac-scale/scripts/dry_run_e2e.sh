#!/usr/bin/env bash
# E2E smoke for `jac start --scale --dry-run` (M-05).
#
# No K8s cluster, no docker, no network. Creates a throwaway fixture,
# runs the CLI in both default (card view) and --show-yaml modes, and
# asserts the planning output structure + diagnostics exit code.
#
# Usage: bash dry_run_e2e.sh
# Env:   JAC_BIN (default `jac` from PATH)

set -euo pipefail

JAC_BIN="${JAC_BIN:-jac}"
TMP="$(mktemp -d -t jac-m5-dryrun-XXXXXX)"
trap 'rm -rf "${TMP}"' EXIT

echo "=== fixture in ${TMP} ==="
cat > "${TMP}/main.jac" <<'EOF'
"""Test app for --dry-run."""
def hello() -> str { return "world"; }
EOF
cat > "${TMP}/orders_app.jac" <<'EOF'
"""Orders microservice."""
def list_orders() -> list[str] { return ["a", "b"]; }
EOF
cat > "${TMP}/users_app.jac" <<'EOF'
"""Users microservice."""
def get_user(uid: int) -> dict { return {"id": uid, "name": "ada"}; }
EOF
cat > "${TMP}/jac.toml" <<'EOF'
[plugins.scale.microservices]
enabled = true
gateway_port = 8000

[plugins.scale.microservices.routes]
orders_app = "/api/orders"
users_app = "/api/users"

[plugins.scale.microservices.services.orders_app]
replicas = 2
cpu_request = "100m"
cpu_limit = "500m"
memory_request = "128Mi"
memory_limit = "256Mi"

[plugins.scale.microservices.services.orders_app.hpa]
min = 2
max = 10
cpu_target = 70

[plugins.scale.kubernetes]
app_name = "m5-dryrun"
namespace = "m5-dryrun"
container_port = 8000
docker_image_name = "m5-dryrun:test"
EOF

cd "${TMP}"
expect_substring() {
    if ! grep -qF -- "$2" <<< "$1"; then
        echo "FAIL: expected substring not found: $2" >&2
        echo "--- output ---" >&2
        echo "$1" >&2
        exit 1
    fi
}
forbid_substring() {
    if grep -qF -- "$2" <<< "$1"; then
        echo "FAIL: unexpected substring found: $2" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# 1. Default run: card view, no YAML, clean exit
# ---------------------------------------------------------------------------
echo "=== run #1: default (card view) ==="
OUT_DEFAULT="$(timeout 60 "${JAC_BIN}" start main.jac --scale --dry-run 2>&1)" || {
    rc=$?
    if [ $rc -eq 124 ]; then
        echo "FAIL: dry-run timed out after 60s (would have hung forever)" >&2
    else
        echo "FAIL: dry-run exited non-zero (rc=$rc)" >&2
    fi
    echo "${OUT_DEFAULT}" >&2
    exit 1
}
echo "${OUT_DEFAULT}"

echo "=== assert default output structure ==="
expect_substring "${OUT_DEFAULT}" "jac scale plan: dry-run"
expect_substring "${OUT_DEFAULT}" "m5-dryrun"        # namespace
expect_substring "${OUT_DEFAULT}" "Microservices"    # cards header
expect_substring "${OUT_DEFAULT}" "orders_app"
expect_substring "${OUT_DEFAULT}" "users_app"
expect_substring "${OUT_DEFAULT}" "image:"           # per-service field
expect_substring "${OUT_DEFAULT}" "replicas:"
expect_substring "${OUT_DEFAULT}" "resources:"
expect_substring "${OUT_DEFAULT}" "HPA: 2 -> 10"     # HPA inline qualifier
expect_substring "${OUT_DEFAULT}" "Totals"
expect_substring "${OUT_DEFAULT}" "--show-yaml"      # hint to opt-in
# Raw YAML must NOT appear by default; the hint pointing to it must.
forbid_substring "${OUT_DEFAULT}" "kind: Deployment"
forbid_substring "${OUT_DEFAULT}" "kind: HorizontalPodAutoscaler"

# ---------------------------------------------------------------------------
# 2. --show-yaml: card view + YAML stream
# ---------------------------------------------------------------------------
echo "=== run #2: --show-yaml ==="
OUT_YAML="$(timeout 60 "${JAC_BIN}" start main.jac --scale --dry-run --show-yaml 2>&1)" || {
    rc=$?
    if [ $rc -eq 124 ]; then
        echo "FAIL: --show-yaml timed out after 60s" >&2
    else
        echo "FAIL: --show-yaml exited non-zero (rc=$rc)" >&2
    fi
    echo "${OUT_YAML}" >&2
    exit 1
}

echo "=== assert --show-yaml output structure ==="
expect_substring "${OUT_YAML}" "jac scale plan: dry-run"
expect_substring "${OUT_YAML}" "Microservices"
expect_substring "${OUT_YAML}" "--- YAML (would be applied) ---"
expect_substring "${OUT_YAML}" "kind: Deployment"
expect_substring "${OUT_YAML}" "kind: Service"
expect_substring "${OUT_YAML}" "kind: HorizontalPodAutoscaler"
expect_substring "${OUT_YAML}" "kind: PodDisruptionBudget"

# ---------------------------------------------------------------------------
# 3. Nothing applied to a cluster in either run.
# ---------------------------------------------------------------------------
for OUT in "${OUT_DEFAULT}" "${OUT_YAML}"; do
    forbid_substring "${OUT}" "namespace/m5-dryrun created"
    forbid_substring "${OUT}" "deployment.apps/"
done

echo "=== M-05 dry-run e2e: PASSED ==="
