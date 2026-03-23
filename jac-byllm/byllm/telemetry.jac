"""Agent-level telemetry callback registry.

byllm emits events after each agent invocation completes.
Consumers (e.g., jac-scale) register callbacks to receive these events.
No data is stored in byllm — this is purely a publish mechanism.
"""
import from typing { Callable }
import logging;

glob _agent_callbacks: list = [],
     logger = logging.getLogger(__name__);

"""Register a callback to receive agent invocation completion events."""
def:pub register_agent_callback(callback: Callable) -> None;

"""Extract telemetry data from mt_run and emit to all registered callbacks.

Owns all extraction logic — Model.invoke only passes mt_run through.
"""
def _emit_agent_telemetry(
    mt_run: object,
    result: object,
    model_name: str,
    latency_ms: float,
    status: str,
    error: Exception | None
) -> None;
