"""LLM Usage Limits for JAC-Scale Admin Dashboard.

Provides rate limiting, budget caps, and model access controls
for byllm LLM calls. Enforces per-user limits by wrapping
litellm.completion/acompletion with pre-call checks.

Integrates with the existing telemetry system for usage tracking
and the admin dashboard for limit management.
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

"""LLM Limits mixin providing usage enforcement, storage, and REST endpoints."""
obj JacAPIServerLLMLimits {
    def register_llm_limits_endpoints -> None;
}
