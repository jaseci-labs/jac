"""Metrics service functions for admin dashboard."""

cl {
    import from .api { get }

    async def:pub getMetrics(token: str) -> dict {
        return await get("/admin/metrics", token);
    }
}
