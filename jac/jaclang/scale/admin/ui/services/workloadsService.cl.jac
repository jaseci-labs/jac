"""Workloads service: thin wrappers over /admin/workloads/* endpoints."""

cl {
    import from .api { get }

    async def:pub getWorkloadsSummary(token: str) -> dict {
        return await get("/admin/workloads", token);
    }

    async def:pub getWorkloadsList(token: str) -> dict {
        return await get("/admin/workloads/list", token);
    }

    async def:pub getWorkloadsPods(token: str) -> dict {
        return await get("/admin/workloads/pods", token);
    }

    async def:pub getWorkloadsTimeseries(token: str, rangeMinutes: int = 60) -> dict {
        return await get(
            "/admin/workloads/timeseries?range_minutes=" + str(rangeMinutes), token
        );
    }
}
