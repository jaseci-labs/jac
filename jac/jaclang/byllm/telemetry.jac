import from typing { Callable }
import from contextvars { ContextVar }
import logging;

glob _agent_callbacks: list = [],
     logger = logging.getLogger(__name__),
     _current_invocation_id: ContextVar = ContextVar(
         'byllm_invocation_id', default=None
     );

def:pub register_agent_callback(callback: Callable) -> None;

def _emit_agent_telemetry(
    mt_run: object,
    result: object,
    model_name: str,
    latency_ms: float,
    status: str,
    error: Exception | None
) -> None;
