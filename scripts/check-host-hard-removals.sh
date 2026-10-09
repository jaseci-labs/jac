#!/usr/bin/env bash
# P0 hard removals 1–7 and P1 hard removals 8–10 from jaseci-labs/jac#8144.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JAC="${ROOT}/jac/jaclang"
FAIL=0

check_absent() {
  local desc="$1"
  local pattern="$2"
  local path="$3"
  if rg -q "$pattern" "$path" 2>/dev/null; then
    echo "FAIL: $desc still present (pattern: $pattern)"
    rg -n "$pattern" "$path" | head -20 || true
    FAIL=1
  fi
}

# 1. placement_solver arm chain
check_absent \
  "_seed_from_summary cap arm chain" \
  "if cap == 'FFI'" \
  "$JAC/compiler/placement/placement_solver.jac"

# 2–3. PLACEMENT_SV_SIGNAL_NODES / PLACEMENT_NATIVE_REJECT_NODES
check_absent \
  "PLACEMENT_SV_SIGNAL_NODES tuple" \
  "PLACEMENT_SV_SIGNAL_NODES" \
  "$JAC"

check_absent \
  "PLACEMENT_NATIVE_REJECT_NODES tuple" \
  "PLACEMENT_NATIVE_REJECT_NODES" \
  "$JAC"

# 4. unconditional dom_types merge into builtins
check_absent \
  "unconditional dom_types -> builtins merge" \
  "for \\(name, sym\\) in self\\.dom_types_module\\.names_in_scope" \
  "$JAC/jaclang/compiler/type_system/type_evaluator.impl/type_evaluator.impl.jac"

# 5. js_globals gated on in_client_context in type evaluator
check_absent \
  "js_globals in_client_context gate" \
  "js_sym is not None and expr\\.in_client_context\\(\\)" \
  "$JAC/jaclang/compiler/type_system/type_evaluator.impl/type_evaluator.impl.jac"

# 6. resolve_active_backend global singleton reader
check_absent \
  "resolve_active_backend()" \
  "resolve_active_backend" \
  "$JAC"

# 7. TargetType enum + get_target_type if-chain
check_absent \
  "TargetType enum" \
  "enum TargetType" \
  "$JAC"

check_absent \
  "get_target_type if-chain" \
  "def get_target_type" \
  "$JAC"

# 8. prepare_inprocess_runtime transport_kind reservation strings
check_absent \
  "transport_kind asgi/isolated_worker reservation" \
  "isolated_worker" \
  "$JAC/jaclang/scale/server/inprocess.jac"

check_absent \
  "transport_kind NotImplementedError gate" \
  "transport_kind != \"testclient\"" \
  "$JAC/jaclang/scale/server/inprocess.jac"

# 9. duplicate sv RPC client fallback in jac0core runtime
check_absent \
  "core sv_service_call HTTP fallback body" \
  "post_stream_aware_sync" \
  "$JAC/jac0core/impl/runtime.impl.jac"

# 10. _test_clients production dispatch
check_absent \
  "_test_clients dict in sv_client" \
  "glob _test_clients" \
  "$JAC/runtimelib/sv_client.jac"

check_absent \
  "_test_clients in rpc dispatch" \
  "_test_clients" \
  "$JAC/scale/runtime/rpc/rpc.jac"

check_absent \
  "_test_clients in scale ensure_sv_service" \
  "_test_clients" \
  "$JAC/scale/plugin.jac"

check_absent \
  "_test_clients in loopback ensure_sv_service" \
  "_test_clients" \
  "$JAC/jac0core/impl/runtime.impl.jac"

if [[ "$FAIL" -ne 0 ]]; then
  echo "Hard-removal grep check failed."
  exit 1
fi

echo "Hard-removal grep check passed (P0 items 1–7, P1 items 8–10)."
