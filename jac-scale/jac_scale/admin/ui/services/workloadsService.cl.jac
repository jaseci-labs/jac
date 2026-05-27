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

    async def:pub getWorkloadDetail(token: str, name: str) -> dict {
        return await get("/admin/workloads/" + name, token);
    }

    async def:pub getWorkloadTimeseries(
        token: str, name: str, metric: str = "cpu", rangeMinutes: int = 60
    ) -> dict {
        path = "/admin/workloads/" + name + "/timeseries" + "?metric=" + metric + "&range_minutes=" + str(
            rangeMinutes
        );
        return await get(path, token);
    }
}
