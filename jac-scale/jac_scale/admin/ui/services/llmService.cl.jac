"""LLM Telemetry service functions for admin dashboard."""

cl {
    import from .api { get }

    async def:pub getLLMSummary(token: str) -> dict {
        return await get("/admin/llm/telemetry/summary", token);
    }

    async def:pub getLLMTraces(
        token: str,
        limit: int = 50,
        offset: int = 0,
        caller: str = "",
        model: str = "",
        status: str = ""
    ) -> dict {
        params = f"limit={limit}&offset={offset}";
        if caller {
            params += f"&caller={encodeURIComponent(caller)}";
        }
        if model {
            params += f"&model={encodeURIComponent(model)}";
        }
        if status {
            params += f"&status={encodeURIComponent(status)}";
        }
        return await get("/admin/llm/telemetry/traces?" + params, token);
    }

    async def:pub getLLMTraceDetail(token: str, invocationId: str) -> dict {
        return await get(
            "/admin/llm/telemetry/traces/" + encodeURIComponent(invocationId), token
        );
    }

    async def:pub getLLMFilters(token: str) -> dict {
        return await get("/admin/llm/telemetry/filters", token);
    }
}
