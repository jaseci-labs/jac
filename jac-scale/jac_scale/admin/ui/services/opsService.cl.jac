"""Ops self-check query service for the admin OpsPage (V-01).

Wraps the single `/admin/ops/health` endpoint in `admin/impl/ops.impl.jac`,
which returns, per signal, a `{status, chain[]}` short-circuit diagnosis.
Returns the standard `{ok, data, error}` envelope from `api.get` (which
already guards the HTML-not-JSON SPA-catchall case).
"""

import from .api { get, post }

async def:pub getOpsHealth(token: str) -> dict {
    return await get("/admin/ops/health", token);
}

# V-02: deploy health (pods + deployments).
async def:pub getDeployHealth(token: str) -> dict {
    return await get("/admin/ops/deploy", token);
}

# V-03: endpoints / ingress / PVC.
async def:pub getNetwork(token: str) -> dict {
    return await get("/admin/ops/network", token);
}

# V-06: image / build freshness.
async def:pub getImages(token: str) -> dict {
    return await get("/admin/ops/images", token);
}

# V-05: events + resource pressure.
async def:pub getEvents(token: str) -> dict {
    return await get("/admin/ops/events", token);
}

# V-04: pod env (allowlist-redacted).
async def:pub getPodEnv(token: str) -> dict {
    return await get("/admin/ops/podenv", token);
}

# V-10: controlled mutations (admin-gated, audit-logged server-side).
async def:pub rolloutRestart(token: str, deployment: str) -> dict {
    return await post("/admin/ops/actions/rollout-restart", {"deployment": deployment}, token);
}

async def:pub scaleDeployment(token: str, deployment: str, replicas: int) -> dict {
    return await post(
        "/admin/ops/actions/scale",
        {"deployment": deployment, "replicas": replicas},
        token
    );
}

async def:pub deletePod(token: str, pod: str) -> dict {
    return await post("/admin/ops/actions/delete-pod", {"pod": pod}, token);
}

async def:pub unstickPvc(token: str, pvc: str) -> dict {
    return await post("/admin/ops/actions/unstick-pvc", {"pvc": pvc}, token);
}