#!/usr/bin/env bash
# E2E smoke for `jac start --scale --dry-run` (M-05).
#
# No K8s cluster, no docker, no network. Creates a throwaway fixture,
# runs the CLI, and asserts the planning output contains the expected
# resource kinds + service names.
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

[plugins.scale.kubernetes]
app_name = "m5-dryrun"
namespace = "m5-dryrun"
container_port = 8000
docker_image_name = "m5-dryrun:test"
EOF

echo "=== run jac start --scale --dry-run ==="
cd "${TMP}"
OUT="$("${JAC_BIN}" start main.jac --scale --dry-run 2>&1)" || {
    echo "FAIL: dry-run exited non-zero" >&2
    echo "${OUT}" >&2
    exit 1
}
echo "${OUT}"

echo "=== assert output structure ==="
expect_substring() {
    if ! grep -qF -- "$1" <<< "${OUT}"; then
        echo "FAIL: expected substring not found: $1" >&2
        exit 1
    fi
}

expect_substring "jac scale plan: dry-run"
expect_substring "Namespace: m5-dryrun"
expect_substring "orders_app"
expect_substring "users_app"
expect_substring "manifests, NOT applied"
# YAML stream present + parseable
expect_substring "kind: Deployment"
expect_substring "kind: Service"
expect_substring "kind: HorizontalPodAutoscaler"
expect_substring "kind: PodDisruptionBudget"

# Make sure nothing tried to deploy (no apply, no namespace create).
# kubectl invocations from the dry-run path would print these strings.
if grep -qF "namespace/m5-dryrun created" <<< "${OUT}"; then
    echo "FAIL: dry-run created a namespace; should have done nothing on cluster" >&2
    exit 1
fi
if grep -qF "deployment.apps/" <<< "${OUT}"; then
    echo "FAIL: dry-run applied a Deployment; should have done nothing on cluster" >&2
    exit 1
fi

echo "=== M-05 dry-run e2e: PASSED ==="
