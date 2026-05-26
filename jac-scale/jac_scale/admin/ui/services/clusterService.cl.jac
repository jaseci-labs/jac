"""Cluster service — fetches Grafana embed configuration for the admin UI."""

cl {
    import from .api { get }

    async def:pub getClusterInfo(token: str) -> dict {
        return await get("/admin/cluster/info", token);
    }
}
