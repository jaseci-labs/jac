"""Operations self-check backend for the jac-scale admin.

A single admin-auth-gated endpoint that answers "why is observability /
health broken?" without a kubeconfig:

  /admin/ops/health  - per signal (traces, logs, metrics, mongo, redis,
                       admin API) a {status, chain[]} where each chain
                       step is {name, ok, detail}, evaluated SHORT-CIRCUIT
                       so the first ok:false IS the diagnosis.

All checks are in-process reads (HAS_OTEL, config, self.server) plus
best-effort outbound HTTP / ping probes with short (~2s) timeouts wrapped
in try/except, so a dead backend renders a RED ROW, never a 500. No K8s
API, no RBAC.

The pure chain-evaluation helpers (`short_circuit_chain` + the per-signal
`_*_chain` builders) live in `impl/ops.impl.jac` and are kept separate
from the probe I/O so `tests/test_ops_health.jac` can feed them mocked
probe results.
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

"""Mixin providing the in-admin signal self-check endpoint."""
obj JacAPIServerOps {
    def register_ops_endpoints -> None;
}
