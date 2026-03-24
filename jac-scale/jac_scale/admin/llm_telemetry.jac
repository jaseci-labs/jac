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
