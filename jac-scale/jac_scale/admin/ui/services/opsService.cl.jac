"""Ops self-check query service for the admin OpsPage (V-01).

Wraps the single `/admin/ops/health` endpoint in `admin/impl/ops.impl.jac`,
which returns, per signal, a `{status, chain[]}` short-circuit diagnosis.
Returns the standard `{ok, data, error}` envelope from `api.get` (which
already guards the HTML-not-JSON SPA-catchall case).
"""

cl {
    import from .api { get }

    async def:pub getOpsHealth(token: str) -> dict {
        return await get("/admin/ops/health", token);
    }
}
