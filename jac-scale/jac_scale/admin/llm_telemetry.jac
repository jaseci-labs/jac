"""LLM Telemetry for JAC-Scale Admin Dashboard.

Provides telemetry endpoints for monitoring LLM usage including
per-call metrics (tokens, cost, latency) and agent-level traces
(user inputs, agent responses, conversation history).

Integrates with byllm's callback system and litellm's CustomLogger.
"""
import from collections.abc { Callable }
import from typing { Any }
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.runtimelib.transport { TransportResponse }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

"""LLM Telemetry mixin providing telemetry storage, litellm logger, and REST endpoints."""
obj JacAPIServerLLMTelemetry {
    def register_llm_telemetry_endpoints -> None;
}

"""Per-user LLM rate and budget limiter.

Pure logic class — no litellm dependency. The litellm CustomLogger adapter
that delegates to this is created inside register_llm_telemetry_endpoints.
Exposed at module level so tests can instantiate it directly.
"""
class JacUserRateLimiter {
    has rc: Any = None,
        col: Any = None,
        rpm: Any = None,
        rpd: Any = None,
        tpm: Any = None,
        tpd: Any = None,
        daily_budget: Any = None,
        monthly_budget: Any = None;

    def init(self: JacUserRateLimiter, rc: Any, col: Any, cfg: dict) -> None;

    def _check_and_incr(
        self: JacUserRateLimiter, key: str, limit: int, ttl: int
    ) -> None;
    def _get_budget_spent(
        self: JacUserRateLimiter, username: str, period: str, cache_key: str, ttl: int
    ) -> float;

    def check_pre_call(self: JacUserRateLimiter, username: str) -> None;
    def record_success(
        self: JacUserRateLimiter,
        username: str,
        tokens: int,
        cost_usd: float,
        model: str
    ) -> None;
}

glob _rate_limiter_instance: JacUserRateLimiter | None = None;
