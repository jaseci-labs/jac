"""Ops Console query service for the admin pages.

Wraps the /admin/ops/* endpoints; returns the standard {ok, data, error}
envelope from api.get/post (which guard the HTML-not-JSON SPA-catchall case).
"""

import from .api { get }

# signal self-check.
async def:pub getOpsHealth(token: str) -> dict {
    return await get("/admin/ops/health", token);
}

# deploy health (pods + deployments).
async def:pub getDeployHealth(token: str) -> dict {
    return await get("/admin/ops/deploy", token);
}

# endpoints / ingress / PVC.
async def:pub getNetwork(token: str) -> dict {
    return await get("/admin/ops/network", token);
}

# pod env (allowlist-redacted).
async def:pub getPodEnv(token: str) -> dict {
    return await get("/admin/ops/podenv", token);
}
