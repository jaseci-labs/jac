"""Workloads service: thin wrappers over /admin/workloads/* endpoints."""

import from .api { get }

async def:pub getWorkloadsSummary(token: str) -> dict[str, any] {
    return await get("/admin/workloads", token);
}

async def:pub getWorkloadsList(token: str) -> dict[str, any] {
    return await get("/admin/workloads/list", token);
}

async def:pub getWorkloadsPods(token: str) -> dict[str, any] {
    return await get("/admin/workloads/pods", token);
}

async def:pub getWorkloadsTimeseries(
    token: str, rangeMinutes: int = 60
) -> dict[str, any] {
    return await get(
        "/admin/workloads/timeseries?range_minutes=" + str(rangeMinutes), token
    );
}
