"""Distributed-trace query service for the admin TracesPage (O-02).

Wraps the three /admin/traces/* endpoints in `admin/impl/traces.impl.jac`,
which proxy Tempo's HTTP API. Returns the standard `{ok, data, error}`
envelope from `api.get`. Counterpart to `logsService` (Loki) and the
LLM-trace service; this one surfaces the generic span waterfall.
"""

cl {
    import from .api { get }

    async def:pub getTraceServices(token: str) -> dict {
        return await get("/admin/traces/services", token);
    }

    async def:pub searchTraces(
        token: str,
        service: str = "",
        status: str = "",
        minDurationMs: int = 0,
        since: str = "1h",
        limit: int = 20
    ) -> dict {
        params: str = f"since={encodeURIComponent(since)}&limit={limit}";
        if service {
            params += f"&service={encodeURIComponent(service)}";
        }
        if status {
            params += f"&status={encodeURIComponent(status)}";
        }
        if minDurationMs > 0 {
            params += f"&min_duration_ms={minDurationMs}";
        }
        return await get("/admin/traces?" + params, token);
    }

    async def:pub getTrace(token: str, traceId: str) -> dict {
        return await get("/admin/traces/" + encodeURIComponent(traceId), token);
    }
}
