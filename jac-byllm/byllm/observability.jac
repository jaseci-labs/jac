"""Observability system for byllm.

Provides structured event emission at key execution points
(LLM calls, tool execution, ReAct iterations) for debugging,
monitoring, and UI integration.
"""
import json;
import time;
import uuid;
import from enum { StrEnum }
import from typing { Any, Callable }

"""Discriminator for all observability events."""
enum EventType ( StrEnum ) {
    INVOKE_START = "invoke_start",
    INVOKE_END = "invoke_end",
    REACT_ITERATION_START = "react_iteration_start",
    REACT_ITERATION_END = "react_iteration_end",
    LLM_REQUEST = "llm_request",
    LLM_RESPONSE = "llm_response",
    LLM_ERROR = "llm_error",
    TOOL_CALL_START = "tool_call_start",
    TOOL_CALL_END = "tool_call_end",
    TOOL_CALL_ERROR = "tool_call_error",
    FINISH_TOOL_CALLED = "finish_tool_called",
    MTIR_FACTORY = "mtir_factory"
}

"""Structured observability event. JSON-serializable via to_dict()."""
obj ByllmEvent {
    has event_type: EventType,
        trace_id: str,
        timestamp: float,
        model_name: str = "",
        metadata: dict[str, Any] = {};

    def to_dict -> dict[str, Any];
}

"""Abstract handler interface. Concrete handlers implement handle()."""
obj EventHandler {
    has enabled: bool = True;

    def handle(event: ByllmEvent) -> None;
}

"""Console handler that logs events with colored output."""
obj ConsoleHandler(EventHandler) {
    has level: str = "INFO",
        show_args: bool = True,
        show_results: bool = True,
        colorize: bool = True;

    override def handle(event: ByllmEvent) -> None;
    def _colors -> dict[str, str];
    def _format_detail(et: EventType, m: dict, c: dict) -> str;
}

"""File handler that writes JSON events in JSONL format."""
obj FileHandler(EventHandler) {
    has file_path: str = "byllm_events.jsonl";

    override def handle(event: ByllmEvent) -> None;
    def close -> None;
}

"""Callback handler for UI integration and programmatic access."""
obj CallbackHandler(EventHandler) {
    has callback: Callable[[dict[str, Any]], None] | None = None,
        event_filter: list[EventType] | None = None;

    override def handle(event: ByllmEvent) -> None;
}

"""Central observer singleton. Receives events and dispatches to handlers."""
obj ByllmObserver {
    has handlers: list[EventHandler] = [],
        enabled: bool = False,
        _current_trace_id: str = "";

    def emit(event: ByllmEvent) -> None;
    def emit_event(event_type: EventType, model_name: str = "", **metadata: Any) -> None;
    def start_trace -> str;
    def add_handler(handler: EventHandler) -> None;
    def remove_handler(handler: EventHandler) -> None;
    def clear_handlers -> None;
}

"""Context manager for scoped observation. Attaches a callback handler
on enter and removes it on exit."""
obj ObserveScope {
    has callback: Callable[[dict[str, Any]], None],
        event_filter: list[EventType] | None = None,
        _handler: CallbackHandler | None = None,
        _prev_enabled: bool = False;

    def __enter__ -> ObserveScope;
    def __exit__(exc_type: type, exc_val: object, exc_tb: object) -> None;
}

glob _observer_instance: ByllmObserver | None = None;

def get_observer -> ByllmObserver;
def configure_observer_from_config -> None;
