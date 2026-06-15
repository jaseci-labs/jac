"""Analyst service: thin wrapper over /admin/analyst/* endpoints (A-07)."""

cl {
    import from .api { get, post }

    async def:pub getAnalystDigest(token: str, baseline: str = "1h") -> dict {
        return await get("/admin/analyst/digest?baseline=" + baseline, token);
    }

    # The full deterministic performance report (health + per-pod USE + slow
    # traces + errors). No model involved.
    async def:pub getReport(token: str) -> dict {
        return await get("/admin/report", token);
    }

    # REASON stage: build the digest server-side and run one small-model call
    # over it. `apiKey` is the BYO LLM key - sent for this request only, never
    # stored. `token` is the admin session token (auth).
    async def:pub analyzeIncident(
        token: str, apiKey: str, model: str = "", baseline: str = "1h"
    ) -> dict {
        return await post(
            "/admin/analyst/analyze",
            {"api_key": apiKey, "model": model, "baseline": baseline},
            token
        );
    }
}
