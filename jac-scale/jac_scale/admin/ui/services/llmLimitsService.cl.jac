"""LLM Limits service functions for admin dashboard."""

cl {
    import from .api { get, put, del, post }

    async def:pub getDefaultLimits(token: str) -> dict {
        return await get("/admin/llm/limits/default", token);
    }

    async def:pub setDefaultLimits(token: str, limits: dict) -> dict {
        return await put("/admin/llm/limits/default", limits, token);
    }

    async def:pub getAllLimits(token: str, limit: int = 50, offset: int = 0) -> dict {
        return await get(
            "/admin/llm/limits?limit=" + str(limit) + "&offset=" + str(offset), token
        );
    }

    async def:pub getUserLimits(token: str, username: str) -> dict {
        return await get("/admin/llm/limits/" + encodeURIComponent(username), token);
    }

    async def:pub setUserLimits(token: str, username: str, limits: dict) -> dict {
        return await put(
            "/admin/llm/limits/" + encodeURIComponent(username), limits, token
        );
    }

    async def:pub deleteUserLimits(token: str, username: str) -> dict {
        return await del("/admin/llm/limits/" + encodeURIComponent(username), token);
    }

    async def:pub getAllUsage(token: str, limit: int = 50, offset: int = 0) -> dict {
        return await get(
            "/admin/llm/usage?limit=" + str(limit) + "&offset=" + str(offset), token
        );
    }

    async def:pub getUserUsage(token: str, username: str) -> dict {
        return await get("/admin/llm/usage/" + encodeURIComponent(username), token);
    }

    async def:pub resetUserUsage(token: str, username: str) -> dict {
        return await post(
            "/admin/llm/usage/" + encodeURIComponent(username) + "/reset", {}, token
        );
    }

    async def:pub getProviderKeys(token: str) -> dict {
        return await get("/admin/llm/config/provider-keys", token);
    }

    async def:pub setProviderKey(token: str, provider: str, apiKey: str) -> dict {
        return await put(
            "/admin/llm/config/provider-keys/" + encodeURIComponent(provider),
            {"api_key": apiKey},
            token
        );
    }

    async def:pub deleteProviderKey(token: str, provider: str) -> dict {
        return await del(
            "/admin/llm/config/provider-keys/" + encodeURIComponent(provider), token
        );
    }
}
