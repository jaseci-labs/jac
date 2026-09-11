"""Metrics service functions for admin dashboard."""

import from .api { get }

async def:pub getMetrics(token: str) -> dict[str, any] {
    return await get("/admin/metrics", token);
}
