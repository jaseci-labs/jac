"""Logs UI backend for the jac-scale admin (A-05a).

Provides REST endpoints that proxy Loki's HTTP API for the in-admin
Pod Logs page. Bypasses Grafana - the admin UI builds focused queries
scoped to the deployed app_name, returns parsed JSON log lines, and
the React LogsPage renders them with service color coding + group-by-
trace_id.

Three endpoints, all GET, all admin-auth-gated:

  /admin/logs/services             - dropdown options from routes table
  /admin/logs                       - paginated query (filters: service,
                                      level, search, trace, since, limit,
                                      offset)
  /admin/logs/trace/{trace_id}      - all lines for one trace, time-sorted

Loki stays in-cluster (no external Ingress). Auth piggybacks on the
existing admin session token.
"""
import from collections.abc { Callable }
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.runtimelib.transport { TransportResponse }
import from jaclang.scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

"""Mixin providing in-admin pod-log query endpoints (A-05a)."""
obj JacAPIServerLogs {
    def register_logs_endpoints -> None;
}
