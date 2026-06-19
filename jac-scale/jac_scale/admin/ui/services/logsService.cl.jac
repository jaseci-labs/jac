"""Pod-log query service for the admin LogsPage (A-05a).

Wraps the three /admin/logs/* endpoints in `admin/impl/logs.impl.jac`,
which proxy Loki's HTTP API. Returns the standard `{ok, data, error}`
envelope from `api.get`.
"""

import from .api { get }

async def:pub getLogServices(token: str) -> dict {
    return await get("/admin/logs/services", token);
}

async def:pub getLogs(
    token: str,
    service: str = "",
    level: str = "",
    search: str = "",
    trace: str = "",
    since: str = "15m",
    limit: int = 200,
    before: str = ""
) -> dict {
    params: str = f"since={encodeURIComponent(since)}&limit={limit}";
    if service {
        params += f"&service={encodeURIComponent(service)}";
    }
    if level {
        params += f"&level={encodeURIComponent(level)}";
    }
    if search {
        params += f"&search={encodeURIComponent(search)}";
    }
    if trace {
        params += f"&trace={encodeURIComponent(trace)}";
    }
    # `before` is the nanosecond ts cursor for "load older": pass
    # back the previous response's `data.next_before`. Empty on
    # the first page so the server uses `now` as the end bound.
    if before {
        params += f"&before={encodeURIComponent(before)}";
    }
    return await get("/admin/logs?" + params, token);
}

async def:pub getTraceLogs(token: str, traceId: str) -> dict {
    return await get("/admin/logs/trace/" + encodeURIComponent(traceId), token);
}
