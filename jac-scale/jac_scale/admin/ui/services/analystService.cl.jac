"""Analyst service: thin wrapper over /admin/analyst/* endpoints (A-07)."""

cl {
    import from .api { get }

    async def:pub getAnalystDigest(token: str, baseline: str = "1h") -> dict {
        return await get("/admin/analyst/digest?baseline=" + baseline, token);
    }
}
