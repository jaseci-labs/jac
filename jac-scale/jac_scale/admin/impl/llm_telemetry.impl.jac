"""LLM Telemetry Implementation for JAC-Scale."""
import logging;
import threading;
import time;
import uuid;
import from collections { OrderedDict }
import from typing { Any }
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

import json as json_module;

glob logger = logging.getLogger(__name__);


obj LLMCallRecord {
    """Record for a single LLM API call within an agent invocation."""
    has call_id: str | None = None,
        model: str | None = None,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_tokens: int = 0,
        response_cost: float = 0.0,
        latency_ms: float = 0,
        status: str = "success",
        error: str | None = None,
        messages: Any = None,
        response: Any = None,
        timestamp: float = 0;

    def to_dict -> dict {
        # Safely serialize messages and response (may contain non-JSON-serializable objects)
        safe_messages = self.messages;
        try {
            json_module.dumps(safe_messages);
        } except (TypeError, ValueError) {
            safe_messages = str(self.messages);
        }
        safe_response = self.response;
        try {
            json_module.dumps(safe_response);
        } except (TypeError, ValueError) {
            safe_response = str(self.response);
        }
        return {
            "call_id": self.call_id,
            "model": self.model,
            "prompt_tokens": self.prompt_tokens,
            "completion_tokens": self.completion_tokens,
            "total_tokens": self.total_tokens,
            "response_cost": self.response_cost,
            "latency_ms": self.latency_ms,
            "status": self.status,
            "error": self.error,
            "messages": safe_messages,
            "response": safe_response,
            "timestamp": self.timestamp
        };
    }
}


obj Trace {
    """A complete agent invocation trace with correlated LLM calls."""
    has invocation_id: str = "",
        caller_name: str = "unknown",
        caller_args: dict = {},
        model: str = "unknown",
        user_prompt: str = "",
        agent_response: str = "",
        conversation_history: list = [],
        total_latency_ms: float = 0,
        total_tokens: int = 0,
        total_cost: float = 0.0,
        llm_call_count: int = 0,
        llm_calls: list = [],
        status: str = "in_progress",
        error: str | None = None,
        completed: bool = False,
        timestamp: float = 0;

    def to_dict(include_detail: bool = False) -> dict {
        result = {
            "invocation_id": self.invocation_id,
            "caller_name": self.caller_name,
            "caller_args": self.caller_args,
            "model": self.model,
            "user_prompt": self.user_prompt[:500]
                if not include_detail
                else self.user_prompt,
            "agent_response": self.agent_response[:500]
                if not include_detail
                else self.agent_response,
            "total_latency_ms": round(self.total_latency_ms, 2),
            "total_tokens": self.total_tokens,
            "total_cost": round(self.total_cost, 6),
            "llm_call_count": self.llm_call_count,
            "status": self.status,
            "error": self.error,
            "completed": self.completed,
            "timestamp": self.timestamp
        };
        if include_detail {
            safe_history = self.conversation_history;
            try {
                json_module.dumps(safe_history);
            } except (TypeError, ValueError) {
                safe_history = str(self.conversation_history);
            }
            result["conversation_history"] = safe_history;
            result["llm_calls"] = [c.to_dict() for c in self.llm_calls];
        }
        return result;
    }
}


obj TelemetryStore {
    """Thread-safe in-memory telemetry store with trace correlation."""
    has max_traces: int = 1000,
        _lock: Any = None,
        _traces: Any = None;

    def postinit {
        self._lock = threading.Lock();
        self._traces = OrderedDict();
    }

    # Called by JacLLMLogger for each individual LLM API call.
    # Creates/updates a Trace based on invocation_id in metadata.
    def record_llm_event(event: dict) {
        with self._lock {
            metadata = event.get("metadata", {}) or {};
            inv_id = metadata.get("jac_invocation_id") or str(uuid.uuid4());
            if inv_id not in self._traces {
                self._traces[inv_id] = Trace(
                    invocation_id=inv_id,
                    caller_name=metadata.get("jac_caller_name") or "unknown",
                    model=event.get("model") or "unknown",
                    timestamp=event.get("startTime") or time.time()
                );
            }
            trace = self._traces[inv_id];
            # Cap stored payloads to bound memory usage
            _raw_msgs = event.get("messages");
            if isinstance(_raw_msgs, list) and len(_raw_msgs) > 20 {
                _raw_msgs = _raw_msgs[-20:];
            }
            _raw_resp = event.get("response");
            try {
                _resp_str = json_module.dumps(_raw_resp);
                if len(_resp_str) > 10240 {
                    _raw_resp = _resp_str[:10240] + "...[truncated]";
                }
            } except (TypeError, ValueError) {
                _raw_resp = str(_raw_resp)[:10240];
            }
            call_record = LLMCallRecord(
                call_id=event.get("id") or str(uuid.uuid4()),
                model=event.get("model"),
                prompt_tokens=event.get("prompt_tokens") or 0,
                completion_tokens=event.get("completion_tokens") or 0,
                total_tokens=event.get("total_tokens") or 0,
                response_cost=event.get("response_cost") or 0.0,
                latency_ms=(event.get("response_time") or 0) * 1000,
                status=event.get("status") or "success",
                error=event.get("error_str"),
                messages=_raw_msgs,
                response=_raw_resp,
                timestamp=event.get("startTime") or time.time()
            );
            trace.llm_calls.append(call_record);
            trace.total_tokens += call_record.total_tokens;
            trace.total_cost += call_record.response_cost;
            trace.llm_call_count += 1;
            # Evict oldest traces if over capacity
            while len(self._traces) > self.max_traces {
                self._traces.popitem(last=False);
            }
        }
    }

    # Called by byllm agent callback. Finalizes the Trace with agent-level data.
    def record_agent_completion(record: dict) {
        with self._lock {
            inv_id = record.get("invocation_id");
            if inv_id and inv_id in self._traces {
                trace = self._traces[inv_id];
                trace.caller_name = record.get("caller_name") or trace.caller_name;
                trace.caller_args = record.get("caller_args") or trace.caller_args;
                trace.user_prompt = record.get("user_prompt") or "";
                trace.agent_response = record.get("agent_response") or "";
                trace.conversation_history = record.get("conversation_history") or [];
                # Cap conversation history to last 40 entries
                if isinstance(trace.conversation_history, list)
                and len(trace.conversation_history) > 40 {
                    trace.conversation_history = trace.conversation_history[-40:];
                }
                trace.total_latency_ms = record.get("latency_ms") or 0;
                trace.status = record.get("status") or "success";
                trace.error = record.get("error");
                trace.model = record.get("model") or trace.model;
                trace.completed = True;
            } elif inv_id {
                # Agent callback arrived but no LLM calls recorded (e.g., MockLLM or proxy path)
                self._traces[inv_id] = Trace(
                    invocation_id=inv_id,
                    caller_name=record.get("caller_name") or "unknown",
                    caller_args=record.get("caller_args") or {},
                    model=record.get("model") or "unknown",
                    user_prompt=record.get("user_prompt") or "",
                    agent_response=record.get("agent_response") or "",
                    conversation_history=(record.get("conversation_history") or [])[-40:],
                    total_latency_ms=record.get("latency_ms") or 0,
                    status=record.get("status") or "success",
                    error=record.get("error"),
                    completed=True,
                    timestamp=time.time()
                );
                # Evict oldest traces if over capacity
                while len(self._traces) > self.max_traces {
                    self._traces.popitem(last=False);
                }
            }
        }
    }

    # Backfill agent_response for streaming traces from the last LLM call's response.
    # byllm contract: tool-based agents ALWAYS end with finish_tool(final_output=...).
    def _backfill_streaming_response(trace: Trace) -> None {
        if trace.agent_response != "[streaming]" or not trace.llm_calls {
            return;
        }
        _last = trace.llm_calls[-1].response;
        if hasattr(_last, "get") {
            _ch = _last.get("choices", []);
            if _ch and len(_ch) > 0 {
                _msg = _ch[0];
                if hasattr(_msg, "get") {
                    _msg = _msg.get("message", {});
                }
                if hasattr(_msg, "get") {
                    # Direct text response (no tools used)
                    if _msg.get("content") {
                        trace.agent_response = str(_msg.get("content"))[:2000];
                        # Tool-based: byllm ALWAYS uses finish_tool as last call
                    } elif _msg.get("tool_calls") {
                        for _tc in _msg.get("tool_calls", []) {
                            if _tc?.get
                            and hasattr(_tc.get("function", {}), "get")
                            and _tc.get("function", {}).get("name") == "finish_tool" {
                                _args = _tc.get("function", {}).get("arguments", "");
                                if hasattr(_args, "strip") {
                                    try {
                                        _args = json_module.loads(_args);
                                    } except (ValueError, TypeError) {
                                        _ = 0;
                                    }
                                }
                                if hasattr(_args, "get") {
                                    trace.agent_response = str(
                                        _args.get("final_output", _args)
                                    )[:2000];
                                } else {
                                    trace.agent_response = str(_args)[:2000];
                                }
                                break;
                            }
                        }
                    }
                }
            }
        } elif _last {
            trace.agent_response = str(_last)[:2000];
        }
    }

    def get_traces(
        limit: int = 50,
        offset: int = 0,
        model: str | None = None,
        status: str | None = None,
        caller: str | None = None
    ) -> dict {
        # Return traces newest-first with optional filters.
        with self._lock {
            all_traces = list(reversed(self._traces.values()));
            # Backfill streaming responses from LLM call data
            for t in all_traces {
                self._backfill_streaming_response(t);
            }
            # Apply filters
            if model {
                all_traces = [
                    t
                    for t in all_traces
                    if t.model == model
                ];
            }
            if status {
                all_traces = [
                    t
                    for t in all_traces
                    if t.status == status
                ];
            }
            if caller {
                all_traces = [
                    t
                    for t in all_traces
                    if t.caller_name == caller
                ];
            }
            total = len(all_traces);
            page = all_traces[offset:offset + limit];
            return {
                "traces": [t.to_dict() for t in page],
                "total": total,
                "has_more": (offset + limit) < total
            };
        }
    }

    # Single trace with full detail (conversation history, all LLM calls).
    def get_trace(invocation_id: str) -> dict | None {
        with self._lock {
            trace = self._traces.get(invocation_id);
            if trace {
                self._backfill_streaming_response(trace);
                return trace.to_dict(include_detail=True);
            }
            return None;
        }
    }

    # Aggregate stats across all traces.
    def get_summary -> dict {
        with self._lock {
            traces_list = list(self._traces.values());
            if not traces_list {
                return {
                    "total_invocations": 0,
                    "total_llm_calls": 0,
                    "total_tokens": 0,
                    "total_cost": 0.0,
                    "avg_latency_ms": 0.0,
                    "error_count": 0,
                    "per_model": {},
                    "per_caller": {}
                };
            }
            total_invocations = len(traces_list);
            total_llm_calls = sum(t.llm_call_count for t in traces_list);
            total_tokens = sum(t.total_tokens for t in traces_list);
            total_cost = sum(t.total_cost for t in traces_list);
            latencies = [
                t.total_latency_ms
                for t in traces_list
                if t.total_latency_ms > 0
            ];
            avg_latency = sum(latencies) / len(latencies) if latencies else 0.0;
            error_count = sum(
                1
                for t in traces_list
                if t.status == "error"
            );
            # Per-model breakdown
            per_model: dict = {};
            for t in traces_list {
                m = t.model or "unknown";
                if m not in per_model {
                    per_model[m] = {"calls": 0, "tokens": 0, "cost": 0.0, "errors": 0};
                }
                per_model[m]["calls"] += 1;
                per_model[m]["tokens"] += t.total_tokens;
                per_model[m]["cost"] += t.total_cost;
                if t.status == "error" {
                    per_model[m]["errors"] += 1;
                }
            }
            # Per-caller breakdown
            per_caller: dict = {};
            for t in traces_list {
                c = t.caller_name or "unknown";
                if c not in per_caller {
                    per_caller[c] = {"calls": 0, "tokens": 0, "cost": 0.0, "errors": 0};
                }
                per_caller[c]["calls"] += 1;
                per_caller[c]["tokens"] += t.total_tokens;
                per_caller[c]["cost"] += t.total_cost;
                if t.status == "error" {
                    per_caller[c]["errors"] += 1;
                }
            }
            # Round cost values
            for m_stats in per_model.values() {
                m_stats["cost"] = round(m_stats["cost"], 6);
            }
            for c_stats in per_caller.values() {
                c_stats["cost"] = round(c_stats["cost"], 6);
            }
            return {
                "total_invocations": total_invocations,
                "total_llm_calls": total_llm_calls,
                "total_tokens": total_tokens,
                "total_cost": round(total_cost, 6),
                "avg_latency_ms": round(avg_latency, 2),
                "error_count": error_count,
                "per_model": per_model,
                "per_caller": per_caller
            };
        }
    }

    # Return unique model names, callers, and statuses for filter dropdowns.
    def get_available_filters -> dict {
        with self._lock {
            models = list(
                set(
                    t.model
                    for t in self._traces.values()
                    if t.model
                )
            );
            callers = list(
                set(
                    t.caller_name
                    for t in self._traces.values()
                    if t.caller_name
                )
            );
            statuses = list(
                set(
                    t.status
                    for t in self._traces.values()
                    if t.status
                )
            );
            return {
                "models": sorted(models),
                "callers": sorted(callers),
                "statuses": sorted(statuses)
            };
        }
    }
}


# Global store instance (created once per server)
glob _telemetry_store: TelemetryStore | None = None;


"""Register LLM telemetry endpoints and set up litellm callback + byllm agent callback."""
impl JacAPIServerLLMTelemetry.register_llm_telemetry_endpoints -> None {
    global _telemetry_store;

    # Create the store with configurable max_traces
    import from jac_scale.config_loader { get_scale_config }
    telemetry_cfg = get_scale_config().get_telemetry_config();
    _telemetry_store = TelemetryStore(max_traces=telemetry_cfg.get('max_traces', 1000));
    store = _telemetry_store;

    # --- Register litellm CustomLogger callback ---
    try {
        import litellm;
        import from litellm.integrations.custom_logger { CustomLogger }

        class JacLLMLogger(CustomLogger) {
            def init(self: JacLLMLogger, telemetry_store: TelemetryStore) {
                self.store = telemetry_store;
                CustomLogger.__init__(self);
            }

            def log_success_event(
                self: JacLLMLogger,
                kwargs: dict,
                response_obj: Any,
                start_time: Any,
                end_time: Any
            ) {
                try {
                    slp = kwargs.get("standard_logging_object", {}) or {};
                    metadata = kwargs.get("litellm_params", {}).get("metadata", {})
                    or {};
                    self.store.record_llm_event(
                        {
                            "id": slp.get("id"),
                            "model": slp.get("model") or kwargs.get("model"),
                            "response_cost": slp.get("response_cost") or 0.0,
                            "prompt_tokens": slp.get("prompt_tokens") or 0,
                            "completion_tokens": slp.get("completion_tokens") or 0,
                            "total_tokens": slp.get("total_tokens") or 0,
                            "response_time": slp.get("response_time") or 0,
                            "status": "success",
                            "messages": slp.get("messages"),
                            "response": slp.get("response"),
                            "startTime": start_time.timestamp()
                                if start_time?.timestamp
                                else time.time(),
                            "metadata": metadata,
                            "error_str": None
                        }
                    );
                } except Exception as e {
                    logger.warning(f"JacLLMLogger.log_success_event error: {e}");
                }
            }

            def log_failure_event(
                self: JacLLMLogger,
                kwargs: dict,
                response_obj: Any,
                start_time: Any,
                end_time: Any
            ) {
                try {
                    slp = kwargs.get("standard_logging_object", {}) or {};
                    metadata = kwargs.get("litellm_params", {}).get("metadata", {})
                    or {};
                    self.store.record_llm_event(
                        {
                            "id": slp.get("id"),
                            "model": slp.get("model") or kwargs.get("model"),
                            "response_cost": 0.0,
                            "prompt_tokens": slp.get("prompt_tokens") or 0,
                            "completion_tokens": 0,
                            "total_tokens": slp.get("prompt_tokens") or 0,
                            "response_time": slp.get("response_time") or 0,
                            "status": "error",
                            "messages": slp.get("messages"),
                            "response": None,
                            "startTime": start_time.timestamp()
                                if start_time?.timestamp
                                else time.time(),
                            "metadata": metadata,
                            "error_str": slp.get("error_str") or str(response_obj)[:500]
                        }
                    );
                } except Exception as e {
                    logger.warning(f"JacLLMLogger.log_failure_event error: {e}");
                }
            }
        }

        jac_logger = JacLLMLogger(store);
        litellm.callbacks.append(jac_logger);
        logger.info("LLM telemetry: litellm CustomLogger registered");
    } except ImportError {
        logger.info("LLM telemetry: litellm not available, skipping litellm callback");
    } except Exception as e {
        logger.warning(f"LLM telemetry: failed to register litellm callback: {e}");
    }

    # --- Register byllm agent callback ---
    try {
        import from byllm.telemetry { register_agent_callback }
        register_agent_callback(store.record_agent_completion);
        logger.info("LLM telemetry: byllm agent callback registered");
    } except ImportError {
        logger.info("LLM telemetry: byllm not available, skipping agent callback");
    } except Exception as e {
        logger.warning(f"LLM telemetry: failed to register byllm callback: {e}");
    }

    # --- Register REST endpoints ---

    # GET /admin/llm/telemetry/summary
    async def summary_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        data = store.get_summary();
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/telemetry/summary",
            callback=summary_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Telemetry"],
            summary="LLM Telemetry Summary",
            description="Aggregate LLM usage statistics: total calls, tokens, cost, latency, per-model/per-caller breakdowns."
        )
    );

    # GET /admin/llm/telemetry/traces
    async def traces_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        qp = request.query_params;
        try {
            limit = int(qp.get("limit", "50"));
        } except (ValueError, TypeError) {
            limit = 50;
        }
        try {
            offset = int(qp.get("offset", "0"));
        } except (ValueError, TypeError) {
            offset = 0;
        }
        model = qp.get("model") or None;
        status = qp.get("status") or None;
        caller = qp.get("caller") or None;
        data = store.get_traces(
            limit=limit, offset=offset, model=model, status=status, caller=caller
        );
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/telemetry/traces",
            callback=traces_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Telemetry"],
            summary="LLM Telemetry Traces",
            description="Paginated list of agent invocation traces with optional filters (query params: limit, offset, model, status, caller)."
        )
    );

    # GET /admin/llm/telemetry/traces/{invocation_id}
    async def trace_detail_handler(
        request: Request, invocation_id: str
    ) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        data = store.get_trace(invocation_id);
        if data is None {
            return JSONResponse(
                status_code=404,
                content={"ok": False, "error": {"message": "Trace not found"}}
            );
        }
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/telemetry/traces/{invocation_id}",
            callback=trace_detail_handler,
            parameters=[
                APIParameter(
                    name="invocation_id",
                    data_type="string",
                    required=True,
                    default=None,
                    description="The invocation ID of the trace",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["LLM Telemetry"],
            summary="LLM Telemetry Trace Detail",
            description="Full detail of a single agent invocation trace including conversation history and per-LLM-call breakdown."
        )
    );

    # GET /admin/llm/telemetry/filters
    async def filters_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get('http_status', 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        data = store.get_available_filters();
        return JSONResponse(content={"ok": True, "data": data});
    }

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/llm/telemetry/filters",
            callback=filters_handler,
            parameters=[],
            response_model=None,
            tags=["LLM Telemetry"],
            summary="LLM Telemetry Filters",
            description="Available filter values (models, callers, statuses) for the traces view."
        )
    );

    logger.info(
        "LLM telemetry endpoints registered: /admin/llm/telemetry/{summary,traces,traces/{id},filters}"
    );
}
