"""Traces UI backend for the jac-scale admin (O-02).

Provides REST endpoints that proxy Tempo's HTTP API for the in-admin
Distributed Traces page. The generic-span sibling of the A-05a logs
backend (`logs.jac`, which proxies Loki) and a counterpart to the
A-05b LLM-trace inspector (which renders byLLM telemetry). Bypasses
Grafana: the admin UI builds app-scoped TraceQL searches, returns the
span tree as flat JSON, and the React TracesPage renders the flame
graph / span waterfall.

Three endpoints, all GET, all admin-auth-gated:

  /admin/traces/services            - dropdown options from routes table
  /admin/traces                     - TraceQL search (filters: service,
                                      status, min_duration_ms, since, limit)
  /admin/traces/{trace_id}          - one trace's spans, flattened for the
                                      waterfall (accepts the K-12 dashed
                                      UUID or the 32-hex Tempo form)

Tempo stays in-cluster (no external Ingress). Auth piggybacks on the
existing admin session token. The trace_id the logs page surfaces is
the same id Tempo stores (the K-12 UUID's 128 bits), so a log line and
its trace cross-link directly.
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

"""Mixin providing in-admin distributed-trace query endpoints (O-02)."""
obj JacAPIServerTraces {
    def register_traces_endpoints -> None;
}
