"""Implementation of the byllm observability system."""
import json;
import time;
import uuid;
import from typing { Any, Callable }
import from loguru { logger }

#-------------------------------------------------------------------------------
# ByllmEvent Implementation
#-------------------------------------------------------------------------------
"""Serialize the event to a JSON-compatible dict."""
impl ByllmEvent.to_dict -> dict[str, Any] {
    return {
        "event_type": self.event_type.value,
        "trace_id": self.trace_id,
        "timestamp": self.timestamp,
        "model_name": self.model_name,
        "metadata": self.metadata,
    };
}

#-------------------------------------------------------------------------------
# EventHandler Implementation
#-------------------------------------------------------------------------------
"""Base handle method. Subclasses must override."""
impl EventHandler.handle(event: ByllmEvent) -> None {
    raise NotImplementedError("Subclasses must implement handle()");
}

#-------------------------------------------------------------------------------
# ConsoleHandler Implementation
#-------------------------------------------------------------------------------
"""Log events to console with colored, human-readable formatting."""
impl ConsoleHandler.handle(event: ByllmEvent) -> None {
    m = event.metadata;
    c = self._colors();

    prefix = f"[{c['C']}byllm{c['R']}][{c['D']}{event.trace_id}{c['R']}]";
    detail = self._format_detail(event.event_type, m, c);
    print(f"{prefix} {detail}");
}

"""Return color codes dict (empty strings when colorize=False)."""
impl ConsoleHandler._colors -> dict[str, str] {
    if self.colorize {
        return {"C": "\033[96m", "G": "\033[92m", "Y": "\033[93m",
                "E": "\033[91m", "B": "\033[1m", "D": "\033[2m", "R": "\033[0m"};
    }
    return {"C": "", "G": "", "Y": "", "E": "", "B": "", "D": "", "R": ""};
}

"""Format event detail string by type."""
impl ConsoleHandler._format_detail(et: EventType, m: dict, c: dict) -> str {
    B = c["B"];
    G = c["G"];
    Y = c["Y"];
    E = c["E"];
    D = c["D"];
    R = c["R"];

    if et == EventType.INVOKE_START {
        return (f"{B}invoke_start{R} caller={m.get('caller_name', '?')} "
                f"tools=[{', '.join(m.get('tool_names', []))}] "
                f"streaming={m.get('is_streaming', False)}");
    } elif et == EventType.INVOKE_END {
        return (f"{B}invoke_end{R} iterations={m.get('total_iterations', 0)} "
                f"finish={m.get('finish_reason', '?')} ({m.get('duration_ms', 0):.0f}ms)");
    } elif et == EventType.REACT_ITERATION_START {
        return f"{D}react_iter {m.get('iteration', 0)} start{R}";
    } elif et == EventType.REACT_ITERATION_END {
        return (f"{D}react_iter {m.get('iteration', 0)} end{R} "
                f"({m.get('duration_ms', 0):.0f}ms) tool_calls={m.get('num_tool_calls', 0)}");
    } elif et == EventType.LLM_REQUEST {
        return f"{B}llm_request{R} messages={m.get('num_messages', 0)} tools={m.get('has_tools', False)}";
    } elif et == EventType.LLM_RESPONSE {
        tc = m.get("tool_call_names", []);
        tc_str = f" [{', '.join(tc)}]" if tc else "";
        line = (f"{G}llm_response{R} ({m.get('duration_ms', 0):.0f}ms) "
                f"tool_calls={m.get('num_tool_calls', 0)}{tc_str} output_len={m.get('output_length', 0)}");
        reasoning = m.get("reasoning_preview", "");
        if reasoning {
            line += f"\n  {D}[reasoning] {reasoning[:200]}{R}";
        }
        output = m.get("output_preview", "");
        if output {
            line += f"\n  {D}[content] {output[:200]}{R}";
        }
        return line;
    } elif et == EventType.LLM_ERROR {
        return f"{E}llm_error{R} {m.get('error_type', '?')}: {m.get('error_message', '?')}";
    } elif et == EventType.TOOL_CALL_START {
        args_str = json.dumps(m.get("args", {})) if self.show_args else "...";
        return f"{Y}tool_call{R} {m.get('tool_name', '?')}({args_str})";
    } elif et == EventType.TOOL_CALL_END {
        result_str = m.get("result_preview", "") if self.show_results else "...";
        return f"{G}tool_done{R} {m.get('tool_name', '?')} ({m.get('duration_ms', 0):.0f}ms) -> {result_str}";
    } elif et == EventType.TOOL_CALL_ERROR {
        return f"{E}tool_error{R} {m.get('tool_name', '?')}: {m.get('error_type', '?')}: {m.get('error_message', '?')}";
    } elif et == EventType.FINISH_TOOL_CALLED {
        return f"{G}finish_tool{R} output_type={m.get('output_type', '?')}";
    } elif et == EventType.MTIR_FACTORY {
        return (f"{D}mtir_factory{R} caller={m.get('caller_name', '?')} "
                f"tools={m.get('num_tools', 0)} return_type={m.get('return_type_name', '?')}");
    }
    return f"{et.value} {json.dumps(m)}";
}

#-------------------------------------------------------------------------------
# FileHandler Implementation
#-------------------------------------------------------------------------------
"""Write one JSON line per event to the file (JSONL format)."""
impl FileHandler.handle(event: ByllmEvent) -> None {
    line = json.dumps(event.to_dict()) + "\n";
    with open(self.file_path, "a") as f {
        f.write(line);
    }
}

"""Close is a no-op since we open/close per write for safety."""
impl FileHandler.close -> None {}

#-------------------------------------------------------------------------------
# CallbackHandler Implementation
#-------------------------------------------------------------------------------
"""Pass the event dict to the user-supplied callback, with optional filtering."""
impl CallbackHandler.handle(event: ByllmEvent) -> None {
    if self.callback is None {
        return;
    }
    if self.event_filter is not None and event.event_type not in self.event_filter {
        return;
    }
    self.callback(event.to_dict());
}

#-------------------------------------------------------------------------------
# ByllmObserver Implementation
#-------------------------------------------------------------------------------
"""Dispatch an event to all enabled handlers. No-op when disabled."""
impl ByllmObserver.emit(event: ByllmEvent) -> None {
    if not self.enabled {
        return;
    }
    for handler in self.handlers {
        if handler.enabled {
            try {
                handler.handle(event);
            } except Exception as e {
                # Never let observer errors propagate to business logic
                logger.warning(f"Observer handler error: {e}");
            }
        }
    }
}

"""Emit a structured event. No-op when disabled (zero cost)."""
impl ByllmObserver.emit_event(event_type: EventType, model_name: str = "", **metadata: Any) -> None {
    if not self.enabled {
        return;
    }
    self.emit(ByllmEvent(
        event_type=event_type,
        trace_id=self._current_trace_id,
        timestamp=time.time(),
        model_name=model_name,
        metadata=metadata,
    ));
}

"""Generate a new trace ID for a by llm() invocation."""
impl ByllmObserver.start_trace -> str {
    self._current_trace_id = str(uuid.uuid4())[:8];
    return self._current_trace_id;
}

"""Add a handler to the observer."""
impl ByllmObserver.add_handler(handler: EventHandler) -> None {
    self.handlers.append(handler);
}

"""Remove a handler from the observer."""
impl ByllmObserver.remove_handler(handler: EventHandler) -> None {
    if handler in self.handlers {
        self.handlers.remove(handler);
    }
}

"""Remove all handlers."""
impl ByllmObserver.clear_handlers -> None {
    self.handlers = [];
}

#-------------------------------------------------------------------------------
# ObserveScope Implementation
#-------------------------------------------------------------------------------
"""Enter the scope: enable observer and attach a callback handler."""
impl ObserveScope.__enter__ -> ObserveScope {
    observer = get_observer();
    self._prev_enabled = observer.enabled;
    observer.enabled = True;
    self._handler = CallbackHandler(
        callback=self.callback,
        event_filter=self.event_filter,
    );
    observer.add_handler(self._handler);
    return self;
}

"""Exit the scope: remove the handler and restore previous enabled state."""
impl ObserveScope.__exit__(exc_type: type, exc_val: object, exc_tb: object) -> None {
    observer = get_observer();
    if self._handler is not None {
        observer.remove_handler(self._handler);
    }
    observer.enabled = self._prev_enabled;
}

#-------------------------------------------------------------------------------
# Module-Level Functions
#-------------------------------------------------------------------------------
"""Get the global ByllmObserver singleton."""
impl get_observer -> ByllmObserver {
    global _observer_instance;
    if _observer_instance is None {
        _observer_instance = ByllmObserver();
    }
    return _observer_instance;
}

"""Configure the observer from jac.toml [plugins.byllm.observability] settings."""
impl configure_observer_from_config -> None {
    import from byllm.config_loader { get_byllm_config }
    obs_config = get_byllm_config().get_observability_config();

    observer = get_observer();
    observer.clear_handlers();
    observer.enabled = bool(obs_config.get("enabled", False));

    if not observer.enabled {
        return;
    }

    console_config = obs_config.get("console", {});
    if bool(console_config.get("enabled", True)) {
        observer.add_handler(ConsoleHandler(
            level=console_config.get("level", "INFO"),
            show_args=bool(console_config.get("show_args", True)),
            show_results=bool(console_config.get("show_results", True)),
            colorize=bool(console_config.get("colorize", True)),
        ));
    }

    file_config = obs_config.get("file", {});
    if bool(file_config.get("enabled", False)) {
        observer.add_handler(FileHandler(
            file_path=file_config.get("path", "byllm_events.jsonl"),
        ));
    }
}

