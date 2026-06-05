"""Traces UI backend for the jac-scale admin.

Admin-auth-gated GET endpoints that proxy Tempo's HTTP API for the
in-admin Distributed Traces page (Tempo stays in-cluster, no Grafana):

  /admin/traces/services    - service dropdown options
  /admin/traces             - TraceQL search (filters: service, status,
                              min_duration_ms, since, limit)
  /admin/traces/{trace_id}  - one trace's spans, flattened for the
                              waterfall (accepts a dashed UUID or the
                              32-hex Tempo form)

The trace_id is the same id the logs page surfaces, so a log line and
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

"""Mixin providing in-admin distributed-trace query endpoints."""
obj JacAPIServerTraces {
    def register_traces_endpoints -> None;
}
