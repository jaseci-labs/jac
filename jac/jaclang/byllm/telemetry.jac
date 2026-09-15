import from contextvars { ContextVar }
import logging;
import type from jaclang.byllm.mtir { MTRuntime }

glob _agent_callbacks: list[Callable[[dict[str, any]], None]] = [],
     logger = logging.getLogger(__name__),
     _current_invocation_id: ContextVar[str | None] = ContextVar(
         'byllm_invocation_id', `default=None
     );

def:pub register_agent_callback(callback: Callable[[dict[str, any]], None]) -> None;

def _aggregate_usage(usage_history: list[dict[str, any]]) -> dict[str, object];

def _emit_agent_telemetry(
    mt_run: MTRuntime,
    result: object,
    model_name: str,
    latency_ms: float,
    status: str,
    error: Exception | None
) -> None;
