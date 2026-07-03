"""Determine if a given by-llm call should use parallel tool execution."""

def _should_parallelize(mt_run: MTRuntime) -> bool {
    per_call = mt_run.call_params.get("parallelize");
    if per_call is True {
        return True;
    }
    if per_call is False {
        return False;
    }
    # Not specified → follow global config (read fresh so runtime changes are picked up)
    return get_byllm_config().get_parallel_config().get("enabled", False);
}


"""True for transient transport errors worth retrying the same model: read-timeout
stall, mid-stream connection drop, and brief 5xx. Auth/RateLimit/NotFound and all
other errors are non-transient and propagate unchanged."""
def _is_transient_error(exc: object) -> bool {
    return isinstance(
        exc,
        (
            litellm.Timeout,
            litellm.APIConnectionError,
            litellm.InternalServerError,
            litellm.ServiceUnavailableError
        )
    );
}


"""Backoff before a transient-error retry (exponential, capped at 10s)."""
def _retry_sleep(attempt: int) {
    base = _streaming_config.get("retry_backoff", 1.0);
    time.sleep(min(base * (2 ** max(0, attempt - 1)), 10.0));
}


"""Async _retry_sleep - never blocks the event loop."""
async def _aretry_sleep(attempt: int) {
    import asyncio;
    base = _streaming_config.get("retry_backoff", 1.0);
    await asyncio.sleep(min(base * (2 ** max(0, attempt - 1)), 10.0));
}


"""Check if the model is eligible for Anthropic prompt caching."""
def _is_prompt_caching_eligible(model_name: str) -> bool {
    pc_config = _byllm_config.get_prompt_caching_config();
    if not pc_config.get("enabled", True) {
        return False;
    }
    name = model_name.lower();
    return name.startswith("anthropic/") or name.startswith("claude-");
}


"""Attach a cache_control marker to a message (string or list content)."""
def _mark_message_for_caching(msg: dict) {
    content = msg.get("content");
    if isinstance(content, str) {
        msg["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    } elif isinstance(content, list) and len(content) > 0 {
        content[-1]["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    }
}


"""Read an int usage field from a litellm usage dict-or-object, 0 if absent.

For `cache_read_input_tokens`, falls back to the `prompt_tokens_details.cached_tokens`
alias some providers nest it under.
"""
def _usage_int(usage: any, key: str) -> int {
    if usage is None {
        return 0;
    }
    val = usage.get(key) if isinstance(usage, dict) else getattr(usage, key, None);
    if val is None and key == "cache_read_input_tokens" {
        ptd = (
            usage.get("prompt_tokens_details")
                if isinstance(usage, dict)
                else usage?.prompt_tokens_details
        );
        if ptd is not None {
            val = (
                ptd.get("cached_tokens")
                    if isinstance(ptd, dict)
                    else ptd?.cached_tokens
            );
        }
    }
    try {
        return int(val or 0);
    } except Exception {
        return 0;
    }
}


"""Mark cache breakpoints for Anthropic: last system, last non-system, last tool."""
def _apply_prompt_caching(messages: list, tools: list | None) {
    last_sys_idx = -1;
    last_nonsys_idx = -1;
    for (i, msg) in enumerate(messages) {
        if isinstance(msg, dict) {
            if msg.get("role") == "system" {
                last_sys_idx = i;
            } else {
                last_nonsys_idx = i;
            }
        }
    }
    if last_sys_idx >= 0 {
        _mark_message_for_caching(messages[last_sys_idx]);
    }
    if last_nonsys_idx >= 0 {
        _mark_message_for_caching(messages[last_nonsys_idx]);
    }
    if tools {
        tools[-1]["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    }
}


"""Resolve the effective context window size for a model name via LiteLLM registry."""
def _litellm_ctx_window(model_name: str) -> int {
    try {
        info = litellm.get_model_info(model_name);
        return int(info.get("max_input_tokens") or info.get("max_tokens") or 0);
    } except Exception {
        return 0;
    }
}


"""Shallow copy of model for compaction - resets call_params and _usage_history
so the summarisation call cannot recurse or inflate the outer loop's token totals.
Works for both Model and ModelPool (shares the already-built _router at zero cost).
"""
def _copy_for_compaction(model: BaseLLM) -> BaseLLM {
    import copy;
    m = copy.copy(model);
    m.call_params = {"compaction_enabled": False};
    # Shallow copy shares the list object - give the compaction call its own
    # history so its token usage does not inflate the outer ReAct loop totals.
    m._usage_history = [];
    return m;
}


"""Summarise old ReAct tool-call rounds into one compact message.

Always keeps messages[0] (system) and messages[1] (user task) verbatim. Preserves
the last `keep_recent` complete assistant+tool_result rounds verbatim as immediate
context. Everything between index 2 and the kept tail is replaced with a single
summary user message tagged [Compacted context summary].

Assistant messages are serialised with their tool_calls (name+args) since content
is None when a tool is called - without this the summary LLM loses the action.
"""
def _default_compact(messages: list, keep_recent: int, model: BaseLLM) -> list {
    # Need at least: system + user + 1 assistant + something to compact
    if len(messages) < 4 {
        return messages;
    }
    # Walk backwards counting assistant turns to find the keep boundary
    kept_tail: list = [];
    assistant_rounds = 0;
    i = len(messages) - 1;
    while i >= 2 and assistant_rounds < keep_recent {
        msg = messages[i];
        role = msg.get("role") if isinstance(msg, dict) else msg?.role;
        if str(role) == "assistant" {
            assistant_rounds += 1;
        }
        kept_tail.insert(0, msg);
        i -= 1;
    }
    # The slice to compact is messages[2 .. i+1]
    compact_slice = messages[2:i + 1];
    if not compact_slice {
        return messages;
    }
    # Serialise the slice for the summarisation call.
    # Assistant messages have content=None when they only contain tool_calls,
    # so we serialise the tool names+args explicitly - otherwise the summary
    # LLM would see "[assistant] " with no content and lose the action context.
    lines: list = [];
    for msg in compact_slice {
        if isinstance(msg, dict) {
            role = msg.get("role", "");
            content = msg.get("content") or "";
            if isinstance(content, list) {
                content = " ".join(
                    p.get("text", "") if isinstance(p, dict) else str(p)
                    for p in content
                );
            }
            if str(role) == "assistant" and not content {
                tool_calls = msg.get("tool_calls") or [];
                if tool_calls {
                    descs: list = [];
                    for tc in tool_calls {
                        fn = tc.get("function", {})
                            if isinstance(tc, dict)
                            else (tc?.function or {});
                        name = (
                            fn.get("name", "?") if isinstance(fn, dict) else fn?.name
                        )
                        or "?";
                        args = (
                            fn.get("arguments", "")
                                if isinstance(fn, dict)
                                else fn?.arguments
                        )
                        or "";
                        descs.append(f"{name}({args})");
                    }
                    content = "called: " + "; ".join(descs);
                }
            }
            lines.append(f"[{role}] {content}");
        } else {
            lines.append(str(msg));
        }
    }
    history_text = "\n".join(lines);
    summary_prompt = (
        "Summarise the following agent tool-call history concisely. "
        "Preserve key findings, decisions, and intermediate results that "
        "may be needed to complete the ongoing task. Output plain text only.\n\n" + history_text
    );
    comp_mt_run = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="You are a concise summariser."),
            Message(role=MessageRole.USER, content=summary_prompt)
        ],
        tools=[],
        resp_type=str,
        stream=False,
        call_params={"compaction_enabled": False},
        mtir=None
    );
    summary = str(model.invoke(comp_mt_run));
    summary_msg = {
        "role": "user",
        "content": f"[Compacted context summary]\n{summary}"
    };
    return [messages[0], messages[1], summary_msg] + kept_tail;
}


"""Resolve the effective context window for this model instance.

Priority: call_params["ctx_window"] > self.ctx_window > jac.toml compaction.ctx_window
          > litellm.get_model_info() > 0 (unknown - disable threshold check).
"""
impl BaseLLM._get_ctx_window(call_params: dict) -> int {
    override = int(
        call_params.get("ctx_window")
        or self.ctx_window
        or get_byllm_config().get_compaction_config().get("ctx_window", 0)
        or 0
    );
    if override > 0 {
        return override;
    }
    return _litellm_ctx_window(self.model_name);
}


"""Resolve compaction config for one invocation (call_params > self.call_params > jac.toml).
Returns dict with keys: enabled, threshold, keep_recent, model, ctx_window.
"""
impl BaseLLM._resolve_compaction_params(mt_run: MTRuntime) -> dict {
    comp_cfg = get_byllm_config().get_compaction_config();
    enabled = bool(
        mt_run.call_params.get("compaction_enabled")
            if mt_run.call_params.get("compaction_enabled") is not None
            else comp_cfg.get("enabled", True)
    );
    _raw_threshold = (
        mt_run.call_params.get("threshold_ratio")
            if mt_run.call_params.get("threshold_ratio") is not None
            else self.call_params.get("threshold_ratio")
                if self.call_params.get("threshold_ratio") is not None
                else None
    );
    threshold = float(str(_raw_threshold))
        if _raw_threshold is not None
        else float(comp_cfg.get("threshold_ratio", 0.80));
    _raw_keep_recent = (
        mt_run.call_params.get("keep_recent_iterations")
            if mt_run.call_params.get("keep_recent_iterations") is not None
            else self.call_params.get("keep_recent_iterations")
                if self.call_params.get("keep_recent_iterations") is not None
                else None
    );
    keep_recent = int(str(_raw_keep_recent))
        if _raw_keep_recent is not None
        else int(comp_cfg.get("keep_recent_iterations", 3));
    _raw_model = (
        mt_run.call_params.get("compaction_model")
        or self.call_params.get("compaction_model")
        or comp_cfg.get("compaction_model")
    );
    model: str | None = str(_raw_model) if _raw_model else None;
    return {
        "enabled": enabled,
        "threshold": threshold,
        "keep_recent": keep_recent,
        "model": model,
        "ctx_window": self._get_ctx_window(mt_run.call_params)
    };
}


"""Compact mt_run.messages in-place.

Resolves the `on_compaction` hook: if the caller supplied one (via call_params
or model.call_params) it is called instead of the built-in default. Either way
the compacted list is written back to mt_run.messages.
"""
impl BaseLLM._compact_messages(
    mt_run: MTRuntime, keep_recent: int, comp_model: str | None
) -> None {
    on_compaction = (
        mt_run.call_params.get("on_compaction") or self.call_params.get("on_compaction")
    );
    original_len = len(mt_run.messages);
    msg_dicts = mt_run.get_msg_list();
    if on_compaction {
        compacted = on_compaction(msg_dicts, keep_recent);
        if not isinstance(compacted, list) or len(compacted) < 2 {
            got_type = type(compacted).__name__;
            got_len = len(compacted) if isinstance(compacted, list) else "N/A";
            raise ConfigurationError(
                "on_compaction hook must return a list with at least 2 messages "
                f"(system + user task). Got: {got_type} of length {got_len}."
            );
        }
    } else {
        if comp_model {
            # Named model - inherit api_key and config so proxy routing still works.
            model_for_compaction = Model(
                model_name=comp_model,
                api_key=self.api_key,
                config=self.config,
                call_params={"compaction_enabled": False}
            );
        } else {
            model_for_compaction = _copy_for_compaction(self);
        }
        compacted = _default_compact(msg_dicts, keep_recent, model_for_compaction);
    }
    removed = original_len - len(compacted);
    if removed == 0 and original_len >= 4 {
        # _default_compact returned unchanged (compact_slice was non-empty but
        # summarisation produced nothing new) or hook returned same length.
        raise CompactionNotEffectiveError(
            "Compaction produced no reduction in message history - "
            "check on_compaction hook or compaction model."
        );
    }
    mt_run.messages = compacted;
    logger.info(
        f"byLLM compaction: reduced message list from {original_len} to {len(
            compacted
        )} "
        f"({removed} messages replaced with summary)"
    );
}


"""Async invoke: uses native async dispatch for simple cases, thread pool for react loops.

Non-streaming with no tools uses adispatch_no_streaming (→ model_call_no_stream_async).
Streaming with no tools uses adispatch_streaming (→ model_call_with_stream_async).
React loop (tools present) offloads the full sync invoke() to a thread pool, because
the ReAct iteration logic is synchronous and making it fully async is out of scope here.
"""
impl BaseLLM.ainvoke(mt_run: MTRuntime) -> object {
    import asyncio;
    logging_stream = mt_run.stream and mt_run.call_params.get("logging", False);
    no_tools = len(mt_run.tools) == 0;
    if not mt_run.stream and no_tools and not logging_stream {
        return await self._ainvoke_typed_retry(mt_run);
    }
    if mt_run.stream and no_tools and not logging_stream {
        return self.adispatch_streaming(mt_run);
    }
    return await asyncio.to_thread(self.invoke, mt_run);
}


"""Construct the call parameters and return self (factory pattern).

Allows chaining like: `model(temperature=0.5).invoke(mt_run)`.
"""
impl BaseLLM.__call__(**kwargs: object) -> BaseLLM {
    self.call_params = kwargs;
    return self;
}

"""Invoke the LLM with the given MTRuntime.

Handles both streaming and non-streaming modes. For tool-enabled requests,
implements a ReAct loop that continues until finish_tool is called.
"""
impl BaseLLM.invoke(mt_run: MTRuntime) -> object {
    # A stream_handler turns this into a streamed call whose events are pushed
    # to the handler as they arrive, while invoke still returns the final
    # (parsed) value. This is what lets `visit [-->] by model(stream=True,
    # stream_handler=fn)` surface live tokens yet receive the routing result.
    handler = mt_run.call_params.get("stream_handler");
    if mt_run.stream and handler is not None {
        return self._invoke_with_handler(mt_run, handler);
    }
    # If logging is enabled with streaming, yield StreamEvent objects
    if mt_run.stream and mt_run.call_params.get("logging", False) {
        return self._invoke_streaming(mt_run);
    }
    # If streaming without tools, stream immediately
    if mt_run.stream and len(mt_run.tools) == 0 {
        return self.dispatch_streaming(mt_run);
    }
    # Streaming ReAct: defer write_back until the inner generator exhausts,
    # otherwise the streamed assistant message is missed.
    if mt_run.stream {
        return self._invoke_react_loop_streaming(mt_run);
    }
    return self._invoke_typed_retry(mt_run);
}


"""Resolve the typed-output attempt budget (1 + max_output_retries).

max_output_retries counts retries AFTER the first attempt (0 disables). Resolves
via call_params > self.call_params > jac.toml > 3. Explicit None checks (not
`or`) so an intentional 0 is honored, not skipped as falsy.
"""
impl BaseLLM._resolve_output_attempts(mt_run: MTRuntime) -> int {
    max_retries = mt_run.call_params.get("max_output_retries");
    if max_retries is None {
        max_retries = self.call_params.get("max_output_retries");
    }
    if max_retries is None {
        max_retries = _call_params_config.get("max_output_retries");
    }
    if max_retries is None {
        max_retries = 3;
    }
    return 1 + max(0, int(max_retries));
}


"""Transient-transport retry budget (retries after the first attempt; 0 disables).
Priority: call_params["stream_num_retries"] > self.call_params > jac.toml > 2."""
impl BaseLLM._resolve_stream_retries(mt_run: MTRuntime) -> int {
    num_retries = mt_run.call_params.get("stream_num_retries");
    if num_retries is None {
        num_retries = self.call_params.get("stream_num_retries");
    }
    if num_retries is None {
        num_retries = _streaming_config.get("num_retries");
    }
    if num_retries is None {
        num_retries = 2;
    }
    return max(0, int(num_retries));
}


"""Invoke the non-streaming path, regenerating empty/malformed typed output.

A weak model may emit empty content or unparseable JSON for a structured return;
retry up to `max_output_retries` (default 3, 0 disables) after the first attempt,
resetting to the original prompt between tries. See _typed_retry_feedback for the
corrective message. The async equivalent is _ainvoke_typed_retry.
"""
impl BaseLLM._invoke_typed_retry(mt_run: MTRuntime) -> object {
    max_attempts = self._resolve_output_attempts(mt_run);
    base_msgs = list(mt_run.messages);
    base_scaffolding = list(mt_run._scaffolding_ids);
    attempt = 0;
    last_reason = "";
    last_output = "";
    try {
        while True {
            attempt += 1;
            if attempt > 1 {
                self._typed_retry_reset(
                    mt_run, base_msgs, base_scaffolding, last_reason, last_output
                );
            }
            try {
                result = self._invoke_react_loop(mt_run);
            } except OutputConversionError as e {
                (last_reason, last_output) = self._parse_failure_feedback(
                    attempt, max_attempts, e
                );
                if attempt >= max_attempts {
                    raise self._typed_retry_exhausted(attempt, e, last_output) from e;
                }
                continue;
            }
            if self._structured_output_ok(mt_run, result) {
                return result;
            }
            (last_err, last_reason, last_output) = self._nonconforming_feedback(
                attempt, max_attempts, mt_run, result
            );
            if attempt >= max_attempts {
                raise self._typed_retry_exhausted(
                    attempt, last_err, last_output
                ) from last_err;
            }
        }
    } finally {
        mt_run.write_back_conversation();
    }
}


"""Async equivalent of _invoke_typed_retry for the no-tools, non-streaming path.

Mirrors the sync retry loop but awaits `adispatch_no_streaming` (which parses the
response, so malformed JSON raises OutputConversionError and an empty response
yields a non-conforming value) instead of the sync ReAct loop. The per-attempt
reset and failure handling are shared via _typed_retry_reset /
_parse_failure_feedback / _nonconforming_feedback so the two loops cannot drift.
"""
impl BaseLLM._ainvoke_typed_retry(mt_run: MTRuntime) -> object {
    max_attempts = self._resolve_output_attempts(mt_run);
    base_msgs = list(mt_run.messages);
    base_scaffolding = list(mt_run._scaffolding_ids);
    attempt = 0;
    last_reason = "";
    last_output = "";
    try {
        while True {
            attempt += 1;
            if attempt > 1 {
                self._typed_retry_reset(
                    mt_run, base_msgs, base_scaffolding, last_reason, last_output
                );
            }
            try {
                result = (await self.adispatch_no_streaming(mt_run)).output;
            } except OutputConversionError as e {
                (last_reason, last_output) = self._parse_failure_feedback(
                    attempt, max_attempts, e
                );
                if attempt >= max_attempts {
                    raise self._typed_retry_exhausted(attempt, e, last_output) from e;
                }
                continue;
            }
            if self._structured_output_ok(mt_run, result) {
                return result;
            }
            (last_err, last_reason, last_output) = self._nonconforming_feedback(
                attempt, max_attempts, mt_run, result
            );
            if attempt >= max_attempts {
                raise self._typed_retry_exhausted(
                    attempt, last_err, last_output
                ) from last_err;
            }
        }
    } finally {
        mt_run.write_back_conversation();
    }
}


"""Reset mt_run to the original prompt and inject the corrective feedback message.

Restores scaffolding ids alongside messages: leaving stale ids behind risks a
later real message reusing a freed id() being dropped from the persisted history.
"""
impl BaseLLM._typed_retry_reset(
    mt_run: MTRuntime, base_msgs: list, base_scaffolding: list, reason: str, output: str
) -> None {
    mt_run.messages = list(base_msgs);
    mt_run._scaffolding_ids = list(base_scaffolding);
    mt_run._has_final_output = False;
    mt_run._final_output = None;
    mt_run.add_scaffolding_message(self._typed_retry_feedback(mt_run, reason, output));
}


"""Log a parse failure and return (reason, rejected_output) for the next retry."""
impl BaseLLM._parse_failure_feedback(
    attempt: int, max_attempts: int, err: object
) -> tuple {
    self.log_info(
        f"[byllm] typed-output attempt {attempt}/{max_attempts} failed to parse: {err}"
    );
    return (
        f"The output parser reported: {err}.",
        str(getattr(err, "raw_output", "") or "")
    );
}


"""Log a non-conforming result and return (error, reason, rejected_output)."""
impl BaseLLM._nonconforming_feedback(
    attempt: int, max_attempts: int, mt_run: MTRuntime, result: object
) -> tuple {
    self.log_info(
        f"[byllm] typed-output attempt {attempt}/{max_attempts} " + "returned a non-conforming value; retrying"
    );
    err = OutputConversionError(
        f"LLM returned a non-conforming value for return type " + f"'{mt_run.resp_type}' (got '{type(
            result
        ).__name__}'); the " + "response was likely empty or not valid JSON"
    );
    reason = (
        "The previous response was empty or did not contain a JSON " + "object (it could not be converted to the required type)."
    );
    return (err, reason, str(result));
}


"""Build the error raised when typed-output retries are exhausted.

Reports the attempt/retry counts, chains the last failure, and preserves
raw_output so downstream consumers still see the rejected text.
"""
impl BaseLLM._typed_retry_exhausted(
    attempts: int, cause: object, raw: str
) -> OutputConversionError {
    err = OutputConversionError(
        f"typed-output generation failed after {attempts} attempt(s) " + f"({attempts - 1} retries); last error: {cause}"
    );
    err.raw_output = raw;
    return err;
}


"""Build the corrective USER message injected before a typed-output retry.

Re-states the failure, echoes the rejected output in full, and re-shows the JSON
schema, demanding a raw JSON object only.
"""
impl BaseLLM._typed_retry_feedback(
    mt_run: MTRuntime, reason: str, prev_output: str
) -> Message {
    rt = mt_run.resp_type;
    type_name = rt.__name__
        if (rt is not None and hasattr(rt, "__name__"))
        else str(rt);
    # get_typed_output_schema, not get_output_schema (None when tools present),
    # so the contract still shows when output arrives via finish_tool.
    schema = mt_run.get_typed_output_schema();
    schema_txt = (
        json.dumps(schema, ensure_ascii=False) if schema else "(schema unavailable)"
    );
    prev_block = f"Your previous response was:\n{prev_output}\n" if prev_output else "";
    return Message(
        role=MessageRole.USER,
        content=(
            f"Your previous response could not be used. {reason}\n" + prev_block + f"You MUST reply with ONLY a single JSON object that validates " + f"against this JSON schema for `{type_name}`:\n{schema_txt}\n" + "Output the raw JSON object only, with no explanation, no reasoning " + "text, no markdown code fences, nothing before or after the JSON."
        )
    );
}


"""True when `value` is an acceptable result for the runtime's return type.

None/str accept anything. For a structured type only a blank string is rejected
(parse_response returns the raw response when empty, the failure this targets);
a non-empty string means a subclass like MockLLM bypassed parsing, so accept it.
Otherwise a best-effort isinstance check (uncheckable generics pass).
"""
impl BaseLLM._structured_output_ok(mt_run: MTRuntime, value: object) -> bool {
    rt = mt_run.resp_type;
    if rt is None or rt is str {
        return True;
    }
    if isinstance(value, str) {
        return value.strip() != "";
    }
    try {
        return isinstance(value, rt);
    } except Exception {
        return True;
    }
}


impl BaseLLM._invoke_react_loop_streaming(
    mt_run: MTRuntime
) -> Generator[object, None, None] {
    import types as _types_mod;
    try {
        result = self._invoke_react_loop(mt_run);
        if isinstance(result, _types_mod.GeneratorType) {
            yield from result;
        } elif result is not None {
            yield result;
        }
    } finally {
        mt_run.write_back_conversation();
    }
}


"""Drive a streamed invocation through a per-event callback.

Forwards every StreamEvent to `on_event` as it arrives, then returns the
final value: the parsed structured result for a structured return type, or
the accumulated answer text otherwise. Backs `visit [-->] by model` and any
structured `by llm()` call that wants live tokens via a stream_handler.
"""
impl BaseLLM._invoke_with_handler(mt_run: MTRuntime, on_event: Callable) -> object {
    # No tools + structured return: the model output is JSON constrained by the
    # response-format schema. Stream those tokens to the handler, accumulate,
    # and parse them into the expected type.
    if len(mt_run.tools) == 0
    and mt_run.resp_type is not None
    and mt_run.resp_type is not str {
        self._usage_history = [];
        accumulated = "";
        _seen_resets = mt_run._stream_reset_count;
        try {
            for token in self.dispatch_streaming(mt_run) {
                # Retry reset the stream: discard the partial JSON so parse_response
                # sees only the final attempt.
                if mt_run._stream_reset_count != _seen_resets {
                    _seen_resets = mt_run._stream_reset_count;
                    accumulated = "";
                    try {
                        on_event(
                            StreamEvent(
                                event_type="stream_reset", data={"scope": "answer"}
                            )
                        );
                    } except Exception as e {
                        logger.debug(f"stream_handler raised: {e}");
                    }
                }
                if token {
                    accumulated += token;
                    try {
                        on_event(
                            StreamEvent(event_type="chunk", data={"content": token})
                        );
                    } except Exception as e {
                        logger.debug(f"stream_handler raised: {e}");
                    }
                }
            }
        } finally {
            mt_run.write_back_conversation();
        }
        # This branch streams only content tokens (no ReAct loop), so it never
        # emits the per-call `llm_timing` the loop does. Surface this call's usage
        # to the handler too, so structured/routing calls report tokens + cache.
        if self._usage_history {
            u = self._usage_history[-1];
            try {
                on_event(
                    StreamEvent(
                        event_type="llm_timing",
                        data={
                            "duration_ms": 0.0,
                            "iteration": 0,
                            "completion_tokens": _usage_int(u, "completion_tokens"),
                            "prompt_tokens": _usage_int(u, "prompt_tokens"),
                            "cache_read_input_tokens": _usage_int(
                                u, "cache_read_input_tokens"
                            ),
                            "cache_creation_input_tokens": _usage_int(
                                u, "cache_creation_input_tokens"
                            )
                        }
                    )
                );
            } except Exception as e {
                logger.debug(f"stream_handler raised: {e}");
            }
        }
        return mt_run.parse_response(accumulated);
    }
    # Tools (ReAct) or str return: drive the full streaming loop, forwarding
    # reasoning, tool, and answer events, then return the captured structured
    # output when present, else the streamed answer text.
    parts: list[str] = [];
    for ev in self._invoke_streaming(mt_run) {
        try {
            on_event(ev);
        } except Exception as e {
            logger.debug(f"stream_handler raised: {e}");
        }
        if ev.event_type == "stream_reset" {
            # Drop the partial answer text accumulated before the retry.
            parts = [];
        } elif ev.event_type == "chunk" {
            parts.append(str(ev.data.get("content", "")));
        }
    }
    if mt_run._has_final_output
    and mt_run.resp_type is not None
    and mt_run.resp_type is not str {
        return mt_run._final_output;
    }
    return "".join(parts);
}


impl BaseLLM._invoke_react_loop(mt_run: MTRuntime) -> object {
    max_iters = (
        mt_run.call_params.get("max_react_iterations")
        or self.call_params.get("max_react_iterations")
        or _call_params_config.get("max_react_iterations")
        or 0
    );
    on_iteration = (
        mt_run.call_params.get("on_iteration") or self.call_params.get("on_iteration")
    );
    _cp = self._resolve_compaction_params(mt_run);
    comp_enabled = bool(_cp["enabled"]);
    comp_threshold = float(_cp["threshold"]);
    comp_keep_recent = int(_cp["keep_recent"]);
    comp_model: str | None = _cp["model"];
    ctx_window = int(_cp["ctx_window"]);
    iter_count = 0;
    last_tool = "";
    last_result = "";
    total_tokens = 0;
    just_compacted = False;
    while True {
        iter_count += 1;
        if on_iteration and iter_count > 1 {
            ctx = IterationContext(
                iteration=iter_count,
                messages=mt_run.messages,
                last_tool=last_tool,
                last_result=last_result,
                total_tokens=total_tokens
            );
            action = on_iteration(ctx);
            if action == IterationAction.ABORT {
                return last_result;
            }
            if action == IterationAction.ABORT_WITH_SUMMARY {
                if mt_run.stream {
                    return self._stream_final_answer(mt_run);
                }
                return self._force_final_answer(mt_run);
            }
        }
        if int(max_iters) > 0 and iter_count > int(max_iters) {
            # If streaming, reuse the existing streaming final-answer path
            if mt_run.stream {
                return self._stream_final_answer(mt_run);
            }
            return self._force_final_answer(mt_run);
        }
        try {
            resp = self.dispatch_no_streaming(mt_run);
        } except litellm.exceptions.ContextWindowExceededError {
            # Context window exceeded - compact and retry once before giving up.
            # Honour the opt-out: if compaction is disabled, re-raise immediately.
            if not comp_enabled {
                raise;
            }
            if just_compacted {
                raise CompactionNotEffectiveError(
                    "Context window exceeded again after emergency compaction - "
                    "provide a custom on_compaction hook, increase ctx_window, "
                    "or switch to a model with a larger context window."
                );
            }
            logger.warning(
                "byLLM compaction: context window exceeded, triggering emergency compaction."
            );
            self._compact_messages(mt_run, comp_keep_recent, comp_model);
            just_compacted = True;
            resp = self.dispatch_no_streaming(mt_run);
        } except OutputConversionError {
            # gpt-4o returned plain text that can't be parsed - attempt recovery.
            recovery_resp = self._attempt_recovery(mt_run);
            if recovery_resp is None {
                raise;
            }
            if recovery_resp.tool_calls {
                for tool_call in recovery_resp.tool_calls {
                    if tool_call.is_finish_call() {
                        mt_run.add_message(tool_call());
                        return tool_call.get_output();
                    }
                }
            }
            return recovery_resp.output;
        }
        usage = resp.usage or {};
        total_tokens += int(
            usage.get("total_tokens", 0)
                if isinstance(usage, dict)
                else getattr(usage, "total_tokens", 0)
        );
        # Threshold-based proactive compaction: check current input size against the
        # context window and compact before the next iteration crosses the limit.
        if comp_enabled and ctx_window > 0 {
            prompt_tokens = int(
                usage.get("prompt_tokens", 0)
                    if isinstance(usage, dict)
                    else usage?.prompt_tokens or 0
            );
            if prompt_tokens > 0 and prompt_tokens / ctx_window >= comp_threshold {
                if just_compacted {
                    raise CompactionNotEffectiveError(
                        f"{prompt_tokens}/{ctx_window} tokens "
                        f"({prompt_tokens / ctx_window:.0%}) still at or above threshold "
                        f"{comp_threshold:.0%} after compaction - provide a custom "
                        "on_compaction hook, increase ctx_window, or switch to a model "
                        "with a larger context window."
                    );
                }
                logger.info(
                    f"byLLM compaction: {prompt_tokens}/{ctx_window} tokens "
                    f"({prompt_tokens / ctx_window:.0%}) >= threshold {comp_threshold:.0%}. "
                    "Compacting message history."
                );
                self._compact_messages(mt_run, comp_keep_recent, comp_model);
                just_compacted = True;
            } else {
                just_compacted = False;
            }
        }
        if resp.tool_calls {
            # Split at first finish_tool - anything after it is discarded.
            # This normalizes history regardless of parallel/sequential mode:
            # both modes see the same tool calls and produce the same mt_run.messages.
            non_finish_calls: list = [];
            finish_tc = None;
            for tc in resp.tool_calls {
                if tc.is_finish_call() {
                    finish_tc = tc;
                    break;
                }
                non_finish_calls.append(tc);
            }

            # Always route through dispatch_batch - one code path for both modes.
            # Parallel: full batch (concurrent). Sequential: one-at-a-time (inline, no pool overhead).
            if non_finish_calls {
                batches = (
                    [non_finish_calls]
                        if _should_parallelize(mt_run)
                        else [[tc] for tc in non_finish_calls]
                );
                for batch in batches {
                    raw_results: list = list(dispatch_batch(batch));
                    ordered: dict = {};
                    for r in raw_results {
                        idx = _index_by_identity(batch, r[0]);
                        ordered[idx] = r;
                    }
                    for i in range(len(batch)) {
                        (btc, result_msg, _ms) = ordered[i];
                        last_tool = btc.tool.get_name();
                        last_result = str(result_msg.content)[:500];
                        mt_run.add_message(result_msg);
                    }
                }
            }

            if finish_tc {
                mt_run.add_message(finish_tc());
                if mt_run.stream {
                    return self._stream_final_answer(mt_run);
                }
                return finish_tc.get_output();
            }
        } else {
            # LLM returned plain text without calling any tool.
            # If finish_tool is available and a structured return type was expected,
            # the model skipped the expected workflow - attempt recovery.
            # (This also handles subclasses like MockLLM that bypass parse_response
            # and thus don't trigger OutputConversionError.)
            recovery_resp = self._attempt_recovery(mt_run);
            if recovery_resp is None {
                break;
            }
            if recovery_resp.tool_calls {
                for tool_call in recovery_resp.tool_calls {
                    if tool_call.is_finish_call() {
                        mt_run.add_message(tool_call());
                        return tool_call.get_output();
                    }
                }
            }
            return recovery_resp.output;
        }
    }
    return resp.output;
}

"""Prepare the parameters for the LLM call.

Builds the parameter dict including model name, messages, tools,
response format, and call parameters like temperature and max_tokens.
"""
impl BaseLLM.make_model_params(mt_run: MTRuntime) -> dict {
    # Use call_params from config as defaults, then override with instance call_params
    default_temp = _call_params_config.get("temperature", 0.7);
    default_max_tokens = _call_params_config.get("max_tokens");

    # Build telemetry metadata (litellm passes this through to callbacks untouched)
    agent_metadata = {};
    try {
        agent_metadata = {
            "jac_invocation_id": mt_run?._invocation_id,
            "jac_parent_invocation_id": mt_run?._parent_invocation_id,
            "jac_caller_name": mt_run.mtir.caller.__name__ if mt_run.mtir else None,

        };
    } except Exception as e {
        logger.debug(f"agent_metadata build failed: {e}");
    }

    messages = mt_run.get_msg_list();
    # Tool-image → user-message reroute for providers that reject images in `role: "tool"`.
    messages = reroute_tool_images_to_user_message(messages);
    tools = mt_run.get_tool_list() or None;

    # Intelligent parallel scheduling: when parallel is active for this call,
    # annotate tool descriptions and inject scheduling rules into the system prompt
    # so the LLM can intelligently decide which tools to batch vs sequence.
    if _should_parallelize(mt_run)
    and tools
    and mt_run.call_params.get("parallel_hint", True)
    and messages
    and len(messages) > 0 {
        # --- Annotate each tool's description with scheduling metadata ---
        # The description field is the primary channel LLMs read when deciding
        # tool calls.  Placing the constraint here is more reliable than a
        # system-prompt list the LLM must cross-reference.
        annotated: list = [];
        serial_names: list = [];
        for (i, schema) in enumerate(tools) {
            tool_obj = mt_run.tools[i] if i < len(mt_run.tools) else None;
            is_serial = tool_obj.serialize if tool_obj else False;
            is_finish = tool_obj.is_finish_tool() if tool_obj else False;
            if is_finish {
                annotated.append(schema);
            } else {
                fn = schema.get("function", {});
                desc = fn.get("description", "");
                if is_serial {
                    serial_names.append(fn.get("name", "unknown"));
                    tag = " [SEQUENTIAL: has side-effects - must be called alone, never batch with other tools]";
                } else {
                    tag = " [PARALLEL-SAFE: can be batched with other independent tools in one response]";
                }
                annotated.append(
                    {** schema, "function": {** fn, "description": desc + tag}}
                );
            }
        }
        tools = annotated;

        # --- Inject intelligent scheduling hint into system prompt ---
        first_msg = messages[0];
        if isinstance(first_msg, dict) and first_msg.get("role") == "system" {
            content = first_msg.get("content", "");
            if isinstance(content, str) and _PARALLEL_TOOL_HINT not in content {
                hint = _PARALLEL_TOOL_HINT;

                # Semantic rules for implicit dependency detection
                hint += (
                    "\n\n**Intelligent tool scheduling rules:**"
                    "\nBATCH in one response (parallel) when:"
                    "\n - You already know ALL required arguments for every tool"
                    "\n - No tool in the group needs another tool's output as input"
                    "\n - No two tools in the group modify the same resource"
                    "\nSEPARATE into different responses (sequential) when:"
                    "\n - A tool's argument depends on another tool's return value"
                    "\n - Two tools write to the same file or shared state"
                    "\n - A tool is labeled [SEQUENTIAL] in its description"
                    "\n\nKEY TEST: For each tool ask - 'Can I fill in ALL of this tool's arguments RIGHT NOW"
                    " without waiting for any other tool's result?' YES for all → batch. NO for any → separate it."
                );

                # Explicit serialize list (if any)
                if serial_names {
                    hint += (
                        f"\n\nTools that must ALWAYS run alone (never batch): {serial_names}"
                    );
                }

                messages = list(messages);
                messages[0] = {** first_msg, "content": content + hint};
            }
        }
    }

    if _is_prompt_caching_eligible(self.model_name) {
        _apply_prompt_caching(messages, tools);
    }

    params = {
        "model": self.model_name,
        "api_key": self.api_key or None,
        "api_base": (
            self.config.get("base_url")
            or self.config.get("host")
            or self.config.get("api_base")
            or _model_config.get("base_url")
        ),
        "messages": messages,
        "tools": tools,
        "response_format": mt_run.get_output_schema(),
        "temperature": self.call_params.get("temperature", default_temp),
        "max_tokens": self.call_params.get("max_tokens", default_max_tokens),
        "metadata": agent_metadata,

    };
    # Pass through tool_choice if explicitly set in call_params
    if "tool_choice" in mt_run.call_params {
        params["tool_choice"] = mt_run.call_params["tool_choice"];
    }
    # Inject the response_format schema's enum hint (e.g. "1=WORK, 2=PERSONAL,
    # ...") into the last user message so every backend sees the constraint
    # the same way frontier providers' server-side prompt builders do for
    # cloud routes. Local-style backends (Ollama, vLLM, in-process llama.cpp)
    # use response_format only as a grammar constraint and would otherwise
    # default to the first allowed enum value for every input. No-op when
    # response_format has no enum-typed properties.
    params = inject_schema_hint(params);
    # Backends without server-side tool calling (in-process llama.cpp) get the
    # tool schemas + call protocol rendered straight into the system prompt;
    # the structured `tools` field is dropped so their unreliable native tool
    # template is not engaged. The cloud/litellm path keeps `tools` untouched.
    if not self.supports_native_tools {
        params = inject_tool_hint(params);
    }
    # Streaming: an inter-chunk read timeout (resets per chunk) catches a silent
    # mid-stream stall in `read_timeout`s instead of litellm's ~600s default,
    # without cutting a healthy long generation. Non-streaming keeps the default
    # (one read for the whole body, so a read timeout would cap total gen time).
    if mt_run.stream {
        import httpx;
        params["timeout"] = httpx.Timeout(
            connect=_streaming_config.get("connect_timeout", 30.0),
            read=_streaming_config.get("read_timeout", 90.0),
            write=_streaming_config.get("write_timeout", 30.0),
            pool=_streaming_config.get("pool_timeout", 30.0)
        );
    }
    return params;
}

"""Log a message to the console if verbose mode is enabled."""
impl BaseLLM.log_info(message: str) -> None {
    # FIXME: The logger.info will not always log so for now I'm printing to stdout
    # remove and log properly.
    # Check instance config first, then fall back to global config
    verbose = self.config.get("verbose", _model_config.get("verbose", False));
    if bool(verbose) {
        logger.info(message);
    }
}

"""Format model parameters for logging, masking sensitive information."""
impl BaseLLM.format_prompt(params: dict) -> str {
    MAGENTA = "\033[95m";
    RESET = "\033[0m";
    log_params = params.copy();
    if log_params.get("api_key") {
        key = log_params["api_key"];
        if len(key) <= 1 {
            log_params["api_key"] = "*";
        } elif len(key) < 4 {
            log_params["api_key"] = "*" * (len(key) - 1) + key[-1:];
        } else {
            log_params["api_key"] = "*" * (len(key) - 4) + key[-4:];
        }
    }
    def _msg_content(m: object) -> object {
        if isinstance(m, dict) {
            return m.get("content");
        }
        return m?.content;
    }
    msgs = log_params["messages"];
    user_content = _msg_content(msgs[1]);
    log = f"""
    {MAGENTA}[SYSTEM]{RESET}
    {_msg_content(msgs[0])}
    {MAGENTA}[USER]{RESET}
    {user_content[0]['text'] if isinstance(user_content, list) else user_content}
    {MAGENTA}[TOOL]{RESET}
    {_msg_content(msgs[3]) if len(msgs) > 3 else "No tools provided."}
    {" "}
    {MAGENTA}[TOOLS]{RESET}
    {json.dumps(log_params.get("tools"), indent=2, ensure_ascii=False)
        if log_params.get("tools")
        else ""}
    {MAGENTA}[RESPONSE FORMAT]{RESET}
    {json.dumps(log_params.get("response_format"), indent=2, ensure_ascii=False)
        if log_params.get("response_format") is not None
        else "None"}""";
    return log;
}

"""Build a ToolCall that reports a malformed-call error back to the model.

When the model emits a tool call byLLM cannot honour - invalid JSON arguments,
or a tool name that does not exist - the ReAct loop must still answer that
call_id with a tool result (the provider API requires tool_use/tool_result
pairing) and let the model retry. This wraps the failure as an ordinary tool
result so the turn recovers gracefully instead of crashing.
"""
def _error_tool_call(call_id: str, tool_name: str, reason: str) -> ToolCall {
    name = tool_name or "unknown_tool";
    def _report_error -> str {
        return (
            f"Tool error: {reason}. "
            f"Re-send the {name} call with corrected arguments."
        );
    }
    _report_error.__name__ = name;
    return ToolCall(call_id=call_id, tool=Tool(func=_report_error), args={});
}


"""Parse raw LLM tool calls into ToolCall objects, tolerating malformed calls.

A tool call the model botches - invalid JSON arguments, or a tool name that
does not exist - becomes an error ToolCall (see `_error_tool_call`) instead of
a raised exception. The ReAct loop then answers it with a normal tool result
so the model can retry, rather than the whole turn crashing on one bad call.
"""
def _parse_tool_calls(
    mt_run: MTRuntime, tool_calls_list: list, truncated_ids: set | None = None
) -> list[ToolCall] {
    parsed: list[ToolCall] = [];
    for tool_call in tool_calls_list {
        fn = tool_call?.function;
        call_id = str(tool_call?.id or "");
        tool_name = str(fn?.name or "") if fn else "";
        tool = mt_run.get_tool(tool_name);
        if tool is None {
            parsed.append(
                _error_tool_call(call_id, tool_name, f"unknown tool '{tool_name}'")
            );
            continue;
        }
        if truncated_ids and call_id in truncated_ids {
            parsed.append(
                _error_tool_call(
                    call_id,
                    tool_name,
                    "the response hit the max_tokens limit before this tool call "
                    "finished, so its arguments were truncated and discarded. Retry "
                    "with a smaller payload (if one argument is very large, split the "
                    "work across multiple calls)"
                )
            );
            continue;
        }
        try {
            raw_args = (fn?.arguments or "") if fn else "";
            args_json = json.loads(raw_args) if raw_args else {};
            args = tool.parse_arguments(args_json);
        } except Exception as e {
            parsed.append(
                _error_tool_call(call_id, tool_name, f"invalid tool arguments ({e})")
            );
            continue;
        }
        parsed.append(ToolCall(call_id=call_id, tool=tool, args=args));
    }
    return parsed;
}


"""Repair malformed tool-call arguments on an assistant message, in place.

A tool call whose `arguments` string is not valid JSON cannot be replayed to
the provider API on the next turn - the provider rejects the entire request
(`Expecting value: line 1 column 1`). Rewrite any such arguments to `"{}"` so
the message persists and replays cleanly. (Truncated/incomplete tool calls are
detected separately from the response's finish_reason - see
`_truncated_call_ids` - so this only repairs JSON for replay safety.)
"""
def _sanitize_tool_calls(message: object) {
    tool_calls = (message or {}).get("tool_calls") or [];
    for tc in tool_calls {
        fn = tc?.function;
        if fn is None {
            continue;
        }
        raw = fn?.arguments;
        valid = False;
        if isinstance(raw, str) and raw.strip() {
            try {
                json.loads(raw);
                valid = True;
            } except Exception {
                valid = False;
            }
        }
        if not valid {
            try {
                fn.arguments = "{}";
            } except Exception {
                if isinstance(fn, dict) {
                    fn["arguments"] = "{}";
                }
            }
        }
    }
}


"""Tool-call ids in a response the model cut off at max_tokens (finish_reason
== "length"). Such a call may be incomplete - invalid JSON, or valid JSON
missing required arguments - so callers report a clear truncation error instead
of executing it with partial arguments (which fails with a misleading "missing
required argument").
"""
def _truncated_call_ids(message: object, finish_reason: str) -> set {
    if finish_reason != "length" {
        return set();
    }
    ids: set = set();
    for tc in ((message or {}).get("tool_calls") or []) {
        ids.add(str(tc?.id or ""));
    }
    return ids;
}


"""Dispatch the LLM call without streaming.

Makes a synchronous API call and processes the response, including
parsing any tool calls returned by the model.
"""
impl BaseLLM.dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    # Construct the parameters for the LLM call
    params = self.make_model_params(mt_run);
    # Call the LiteLLM API
    log_params = self.format_prompt(params);
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    while True {
        try {
            response = self.model_call_no_stream(params);
            break;
        } except Exception as e {
            # Retry the same model on a transient transport error; others propagate.
            if _is_transient_error(e)
            and attempt < self._resolve_stream_retries(mt_run) {
                attempt += 1;
                self.log_info(
                    f"Transient LLM error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                _retry_sleep(attempt);
                continue;
            }
            # Log with model_name on failure so verbose output is still captured
            self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");
            raise;
        }
    }
    # Log the actual model that served the request (from response, useful for proxy/pool)
    actual_model = response.get("model", self.model_name);
    self.log_info(f"Calling LLM: {actual_model} with params: {log_params}");
    # Output format:
    # https://docs.litellm.ai/docs/#response-format-openai-format
    #
    # TODO: Handle stream output (type ignoring stream response)
    message: LiteLLMMessage = response.get("choices", [])[0].get(
        "message"
    );  # type: ignore
    # For backends without native tool calling, lift any tool call the model
    # emitted as plain text into the structured `tool_calls` field so the
    # ReAct loop below sees it. No-op once `tool_calls` is already populated.
    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content: str = message.get("content") or "";  # type: ignore
    self.log_info(f"LLM call completed with response: {output_content}");
    finish_reason = str(
        (response.get("choices") or [{}])[0].get("finish_reason") or ""
    );
    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    tool_calls_list = (message or {}).get("tool_calls") or [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids);
    # Only parse the content as the final output when there are no tool calls.
    # gpt-4o may return non-JSON content alongside tool calls (e.g. "I'll handle that."),
    # which would cause json.loads to fail if we parsed it as the typed response.
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    usage_data = response.get("usage", {});
    return CompletionResult(
        output=output_value, tool_calls=tool_calls, usage=usage_data
    );
}

"""Dispatch the LLM call with streaming.

Makes a streaming API call and yields content chunks as they arrive.
"""
impl BaseLLM.dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None] {
    # Construct the parameters for the LLM call
    params = self.make_model_params(mt_run);
    # Call the LiteLLM API
    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    usage_base = len(self._usage_history);
    while True {
        try {
            response = self.model_call_with_stream(params);
            for chunk in response {
                # Final chunk carries usage when stream_options.include_usage is set.
                chunk_usage = chunk?.usage;
                if chunk_usage {
                    self._usage_history.append(chunk_usage);
                }
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    delta = chunk.choices[0].delta;
                    yield delta.content or "";
                }
            }
            break;
        } except Exception as e {
            # Transient mid-stream drop: retry the same model from scratch, drop the
            # failed attempt's usage, and bump the reset counter so consumers discard
            # tokens already shown.
            if _is_transient_error(e)
            and attempt < self._resolve_stream_retries(mt_run) {
                attempt += 1;
                self._usage_history = self._usage_history[:usage_base];
                mt_run._stream_reset_count += 1;
                self.log_info(
                    f"Transient stream error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                _retry_sleep(attempt);
                continue;
            }
            raise;
        }
    }
}

"""Dispatch a tool-enabled LLM call with streaming.

Streams the model's content tokens (yielded as they arrive) while collecting
the full response - content, tool calls and usage - which is reassembled and
appended to `out` as a single CompletionResult. This lets the ReAct loop
surface the model's reasoning live, token by token, instead of waiting for the
whole step to finish. Backends without streaming (e.g. MockLLM) transparently
fall back to one non-streaming call.
"""
impl BaseLLM.dispatch_streaming_with_tools(
    mt_run: MTRuntime, out: list[CompletionResult]
) -> Generator[str, None, None] {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.log_info(
        f"Calling LLM (streaming): {self.model_name} with params:\n{log_params}"
    );
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    chunks: list = [];
    content_buf = "";
    no_stream = False;
    finish_reason = "";
    attempt = 0;
    while True {
        # Reset accumulators each attempt so a retried step is never doubled.
        chunks = [];
        content_buf = "";
        try {
            for chunk in self.model_call_with_stream(params) {
                chunks.append(chunk);
                delta_content = "";
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    delta_content = chunk.choices[0].delta?.content or "";
                } elif isinstance(chunk, dict) {
                    _choices = chunk.get("choices") or [];
                    if _choices {
                        delta_content = (_choices[0].get("delta") or {}).get("content")
                        or "";
                    }
                }
                if delta_content {
                    content_buf += str(delta_content);
                    yield str(delta_content);
                }
            }
            break;
        } except NotImplementedError {
            # Backend has no streaming - fall back to a single non-streaming call.
            no_stream = True;
            break;
        } except Exception as e {
            # Transient mid-stream drop: discard the partial step and retry the same
            # model; the reset counter tells consumers to drop shown tokens.
            if _is_transient_error(e)
            and attempt < self._resolve_stream_retries(mt_run) {
                attempt += 1;
                mt_run._stream_reset_count += 1;
                self.log_info(
                    f"Transient stream error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                _retry_sleep(attempt);
                continue;
            }
            raise;
        }
    }
    if no_stream {
        out.append(self.dispatch_no_streaming(mt_run));
        return;
    }
    # Reassemble the streamed chunks into one complete response. litellm's
    # builder merges native tool-call fragments; the fallback covers backends
    # whose chunk shape it cannot parse (e.g. in-process llama.cpp).
    message: object = None;
    usage_data: dict = {};
    try {
        rebuilt = litellm.stream_chunk_builder(chunks);
        if rebuilt {
            message = rebuilt.get("choices", [])[0].get("message");
            usage_data = rebuilt.get("usage", {}) or {};
            finish_reason = str(
                rebuilt.get("choices", [])[0].get("finish_reason") or ""
            );
        }
    } except Exception as e {
        logger.debug(f"stream_chunk_builder failed, using accumulated text: {e}");
        message = None;
    }
    if message is None {
        message = {"role": "assistant", "content": content_buf};
    }
    # Lift any tool call emitted as plain text into the structured `tool_calls`
    # field (see dispatch_no_streaming). Some native providers (e.g. ollama)
    # stream a tool call as plain content text that litellm.stream_chunk_builder
    # cannot reassemble into `tool_calls`, so the native path silently drops it.
    # When tools were offered but no structured tool_calls came back, rebuild the
    # message as a plain dict from the accumulated text -- recover_tool_calls
    # requires a dict and `message` here is a litellm `Message` object -- then
    # recover the call. recover_tool_calls is idempotent and name-filtered, so it
    # is a no-op for a genuine native tool_calls field or a plain-text answer.
    has_native_tool_calls = bool((message or {}).get("tool_calls"));
    if (not self.supports_native_tools)
    or (mt_run.tools and not has_native_tool_calls) {
        if not has_native_tool_calls and not isinstance(message, dict) {
            message = {"role": "assistant", "content": content_buf};
        }
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content: str = message.get("content") or "";
    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    tool_calls_list = (message or {}).get("tool_calls") or [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids);
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    out.append(
        CompletionResult(output=output_value, tool_calls=tool_calls, usage=usage_data)
    );
}

"""Async dispatch: mirrors dispatch_no_streaming but calls model_call_no_stream_async."""
impl BaseLLM.adispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    while True {
        try {
            response = await self.model_call_no_stream_async(params);
            break;
        } except Exception as e {
            if _is_transient_error(e)
            and attempt < self._resolve_stream_retries(mt_run) {
                attempt += 1;
                self.log_info(
                    f"Transient LLM error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                await _aretry_sleep(attempt);
                continue;
            }
            self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");
            raise;
        }
    }
    actual_model = response.get("model", self.model_name);
    self.log_info(f"Calling LLM: {actual_model} with params: {log_params}");
    message: LiteLLMMessage = response.get("choices", [])[0].get(
        "message"
    );  # type: ignore
    # For backends without native tool calling, lift any tool call the model
    # emitted as plain text into the structured `tool_calls` field so the
    # ReAct loop below sees it. No-op once `tool_calls` is already populated.
    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content: str = message.get("content") or "";  # type: ignore
    self.log_info(f"LLM call completed with response: {output_content}");
    finish_reason = str(
        (response.get("choices") or [{}])[0].get("finish_reason") or ""
    );
    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    tool_calls_list = (message or {}).get("tool_calls") or [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids);
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    usage_data = response.get("usage", {});
    return CompletionResult(
        output=output_value, tool_calls=tool_calls, usage=usage_data
    );
}

"""Async dispatch: mirrors dispatch_streaming but calls model_call_with_stream_async."""
impl BaseLLM.adispatch_streaming(mt_run: MTRuntime) {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    usage_base = len(self._usage_history);
    while True {
        try {
            response = await self.model_call_with_stream_async(params);
            async for chunk in response {
                chunk_usage = chunk?.usage;
                if chunk_usage {
                    self._usage_history.append(chunk_usage);
                }
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    delta = chunk.choices[0].delta;
                    yield delta.content or "";
                }
            }
            break;
        } except Exception as e {
            if _is_transient_error(e)
            and attempt < self._resolve_stream_retries(mt_run) {
                attempt += 1;
                self._usage_history = self._usage_history[:usage_base];
                mt_run._stream_reset_count += 1;
                self.log_info(
                    f"Transient stream error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                await _aretry_sleep(attempt);
                continue;
            }
            raise;
        }
    }
}

"""Make a direct model call without streaming.

Subclasses must implement this to define how the actual LLM API is called.
Should return the raw API response object.
"""
impl BaseLLM.model_call_no_stream(params: dict) -> dict {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call without streaming."
    );
}

"""Make a direct model call with streaming.

Subclasses must implement this to define how the actual LLM API is called.
Should return a generator that yields response chunks.
"""
impl BaseLLM.model_call_with_stream(params: dict) -> Generator[str, None, None] {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call with streaming."
    );
}

"""Async fallback: wraps sync model_call_no_stream in a thread.

Subclasses with native async support (e.g. Model) override this.
"""
impl BaseLLM.model_call_no_stream_async(params: dict) -> dict {
    import asyncio;
    return await asyncio.to_thread(self.model_call_no_stream, params);
}

"""Async fallback: drives the sync streaming generator step-by-step in a thread pool.

asyncio.to_thread(model_call_with_stream, params) would only off-thread generator
creation — actual chunk I/O still runs on the event loop during iteration. This impl
calls next() inside the thread for each chunk so every blocking step is off-loop.
Subclasses with native async support (e.g. Model) override this.
"""
impl BaseLLM.model_call_with_stream_async(params: dict) {
    import asyncio;
    def _next_chunk(gen: object) -> tuple[bool, object] {
        try {
            return (True, next(gen));
        } except StopIteration {
            return (False, None);
        }
    }
    gen = self.model_call_with_stream(params);
    while True {
        (has_value, chunk) = await asyncio.to_thread(_next_chunk, gen);
        if not has_value {
            break;
        }
        yield chunk;
    }
}

"""Force LLM to produce a final answer (non-streaming). Restricts tools to finish_tool only."""
impl BaseLLM._force_final_answer(mt_run: MTRuntime) -> object {
    final_instruction = Message(
        role=MessageRole.USER,
        content="Based on the tool calls and their results above, provide only your final answer.",
    );
    mt_run.add_scaffolding_message(final_instruction);
    original_tools = mt_run.tools;
    finish_tool_obj = mt_run.get_tool("finish_tool");
    mt_run.tools = [finish_tool_obj] if finish_tool_obj else [];
    try {
        final_resp = self.dispatch_no_streaming(mt_run);
        if final_resp.tool_calls {
            for tool_call in final_resp.tool_calls {
                if tool_call.is_finish_call() {
                    mt_run.add_scaffolding_message(tool_call());
                    return tool_call.get_output();
                }
            }
        }
        return str(final_resp.output) if final_resp.output else "";
    } finally {
        mt_run.tools = original_tools;
    }
}


"""Stream the final answer after ReAct tool calls complete.

Creates a new streaming LLM call with all context from tool calls
to generate the final answer in real-time streaming mode.
Unlike _stream_finish_output which splits an already-complete string,
this makes a REAL streaming API call to the LLM.
"""
impl BaseLLM._stream_final_answer(mt_run: MTRuntime) -> Generator[str, None, None] {
    # Add a message instructing the LLM to provide the final answer
    # based on all the tool call results gathered so far
    final_instruction = Message(
        role=MessageRole.USER,
        content="Based on the tool calls and their results above, provide your final answer. "
        "Be comprehensive and synthesize all the information gathered.",
    );
    mt_run.add_scaffolding_message(final_instruction);
    # Keep only finish_tool so Anthropic sees a valid tools= param
    # (conversation history may already contain tool_use blocks)
    original_tools = mt_run.tools;
    finish_tool_obj = mt_run.get_tool("finish_tool");
    mt_run.tools = [finish_tool_obj] if finish_tool_obj else [];
    # Force text generation - tool_choice="none" tells the LLM
    # "tools are defined but do NOT call any, just produce text"
    # Save caller's original tool_choice (if any) so we can restore it after.
    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    mt_run.call_params["tool_choice"] = "none";
    accumulated: str = "";
    try {
        # Make the actual streaming call - this is REAL streaming from the LLM!
        for token in self.dispatch_streaming(mt_run) {
            accumulated += token;
            yield token;
        }
    } finally {
        # Restore tools and original tool_choice
        mt_run.tools = original_tools;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }
        # dispatch_streaming yields tokens but doesn't append to messages;
        # persist the final answer so write_back_conversation includes it.
        if accumulated {
            mt_run.add_message(
                Message(role=MessageRole.ASSISTANT, content=accumulated)
            );
        }
    }
}

"""Attempt finish_tool recovery when the LLM skips the expected workflow.

Called when the LLM either raises OutputConversionError (non-JSON output
from parse_response) or returns no tool calls when finish_tool was expected.
Re-prompts the LLM with only finish_tool available.

Returns CompletionResult from the recovery dispatch if preconditions are met,
or None if recovery is not applicable (no finish_tool, or resp_type is str/None).
Callers should check the returned CompletionResult's tool_calls for finish_tool.
"""
impl BaseLLM._attempt_recovery(mt_run: MTRuntime) -> CompletionResult | None {
    finish_tool_obj = mt_run.get_tool("finish_tool");
    if not finish_tool_obj or mt_run.resp_type is None or mt_run.resp_type is str {
        return None;
    }
    recovery_msg = Message(
        role=MessageRole.USER,
        content="You must use finish_tool to return your response. Call finish_tool now.",
    );
    mt_run.add_scaffolding_message(recovery_msg);
    original_tools = mt_run.tools;
    mt_run.tools = [finish_tool_obj];
    try {
        return self.dispatch_no_streaming(mt_run);
    } finally {
        mt_run.tools = original_tools;
    }
}

"""Process a recovery CompletionResult for streaming, yielding StreamEvents.

Shared by both the OutputConversionError and no-tool-call recovery paths
in _invoke_streaming. Appends usage, checks for finish_tool, yields
steps_done, and either streams the final answer or yields the raw output.
"""
impl BaseLLM._yield_recovery_result(
    recovery_resp: CompletionResult, iter_count: int, mt_run: MTRuntime
) -> Generator[StreamEvent, None, None] {
    self._usage_history.append(recovery_resp.usage);
    finish_found = False;
    if recovery_resp.tool_calls {
        for tool_call in recovery_resp.tool_calls {
            if tool_call.is_finish_call() {
                mt_run.add_message(tool_call());
                finish_found = True;
                break;
            }
        }
    }
    yield StreamEvent(event_type="steps_done", data={"iterations": iter_count});
    if finish_found {
        for token in self._stream_final_answer(mt_run) {
            if token {
                yield StreamEvent(event_type="chunk", data={"content": token});
            }
        }
    } elif recovery_resp.output {
        yield StreamEvent(
            event_type="chunk", data={"content": str(recovery_resp.output)}
        );
    }
}

"""Invoke the LLM with logging enabled, yielding StreamEvent objects.

When logging=True is set in call_params, this method replaces the default
invoke path. It yields StreamEvent for every intermediate step (thoughts,
tool calls, tool results) and wraps final answer tokens in StreamEvent too.
Works for both tool and non-tool streaming paths.
"""
impl BaseLLM._invoke_streaming(
    mt_run: MTRuntime
) -> Generator[StreamEvent, None, None] {
    # Reset per-call usage accumulator so long-lived LLM instances don't leak memory.
    self._usage_history = [];
    # No tools: wrap plain streaming tokens in StreamEvent
    if len(mt_run.tools) == 0 {
        _seen_resets = mt_run._stream_reset_count;
        for token in self.dispatch_streaming(mt_run) {
            # Retry reset the stream: tell the consumer to drop the partial answer.
            if mt_run._stream_reset_count != _seen_resets {
                _seen_resets = mt_run._stream_reset_count;
                yield StreamEvent(event_type="stream_reset", data={"scope": "answer"});
            }
            if token {
                yield StreamEvent(event_type="chunk", data={"content": token});
            }
        }
    } else {
        # ReAct loop with tools
        max_iters = (
            mt_run.call_params.get("max_react_iterations")
            or self.call_params.get("max_react_iterations")
            or _call_params_config.get("max_react_iterations")
            or 0
        );
        on_iteration = (
            mt_run.call_params.get("on_iteration")
            or self.call_params.get("on_iteration")
        );
        _cp = self._resolve_compaction_params(mt_run);
        comp_enabled = bool(_cp["enabled"]);
        comp_threshold = float(_cp["threshold"]);
        comp_keep_recent = int(_cp["keep_recent"]);
        comp_model: str | None = _cp["model"];
        ctx_window = int(_cp["ctx_window"]);
        iter_count = 0;
        last_tool = "";
        last_result = "";
        total_tokens = 0;
        just_compacted = False;
        while True {
            iter_count += 1;

            if on_iteration and iter_count > 1 {
                ctx = IterationContext(
                    iteration=iter_count,
                    messages=mt_run.messages,
                    last_tool=last_tool,
                    last_result=last_result,
                    total_tokens=total_tokens
                );
                action = on_iteration(ctx);
                if action == IterationAction.ABORT {
                    yield StreamEvent(
                        event_type="steps_done",
                        data={"iterations": iter_count - 1, "reason": "aborted"}
                    );
                    if last_result {
                        yield StreamEvent(
                            event_type="chunk", data={"content": last_result}
                        );
                    }
                    break;
                }
                if action == IterationAction.ABORT_WITH_SUMMARY {
                    yield StreamEvent(
                        event_type="steps_done",
                        data={
                            "iterations": iter_count - 1,
                            "reason": "aborted_with_summary"
                        }
                    );
                    for token in self._stream_final_answer(mt_run) {
                        if token {
                            yield StreamEvent(
                                event_type="chunk", data={"content": token}
                            );
                        }
                    }
                    break;
                }
            }

            if int(max_iters) > 0 and iter_count > int(max_iters) {
                yield StreamEvent(
                    event_type="steps_done",
                    data={"iterations": iter_count - 1, "reason": "max_iterations"}
                );
                for token in self._stream_final_answer(mt_run) {
                    if token {
                        yield StreamEvent(event_type="chunk", data={"content": token});
                    }
                }
                break;
            }

            import time as _time;
            _llm_t0 = _time.time();
            try {
                # Stream the model's content tokens live as `thought` events
                # while collecting the full response (content + tool calls).
                _stream_out: list[CompletionResult] = [];
                _seen_resets = mt_run._stream_reset_count;
                for _tok in self.dispatch_streaming_with_tools(mt_run, _stream_out) {
                    # Retry reset this step: drop the partial reasoning for it.
                    if mt_run._stream_reset_count != _seen_resets {
                        _seen_resets = mt_run._stream_reset_count;
                        yield StreamEvent(
                            event_type="stream_reset",
                            data={"scope": "thought", "iteration": iter_count}
                        );
                    }
                    if _tok {
                        yield StreamEvent(
                            event_type="thought",
                            data={
                                "content": _tok,
                                "iteration": iter_count,
                                "streaming": True
                            }
                        );
                    }
                }
                resp = _stream_out[0];
            } except litellm.exceptions.ContextWindowExceededError {
                if not comp_enabled {
                    raise;
                }
                if just_compacted {
                    raise CompactionNotEffectiveError(
                        "Context window exceeded again after emergency compaction - "
                        "provide a custom on_compaction hook, increase ctx_window, "
                        "or switch to a model with a larger context window."
                    );
                }
                logger.warning(
                    "byLLM compaction: context window exceeded, triggering emergency compaction."
                );
                self._compact_messages(mt_run, comp_keep_recent, comp_model);
                just_compacted = True;
                resp = self.dispatch_no_streaming(mt_run);
            } except OutputConversionError {
                # gpt-4o returned plain text that can't be parsed - attempt recovery.
                recovery_resp = self._attempt_recovery(mt_run);
                if recovery_resp is None {
                    raise;
                }
                yield from self._yield_recovery_result(
                    recovery_resp, iter_count, mt_run
                );
                break;
            }
            _llm_ms = int((_time.time() - _llm_t0) * 1000);
            self._usage_history.append(resp.usage);

            usage = resp.usage or {};
            total_tokens += int(
                usage.get("total_tokens", 0)
                    if isinstance(usage, dict)
                    else getattr(usage, "total_tokens", 0)
            );
            # Threshold-based proactive compaction - identical logic to invoke().
            if comp_enabled and ctx_window > 0 {
                prompt_tokens = int(
                    usage.get("prompt_tokens", 0)
                        if isinstance(usage, dict)
                        else usage?.prompt_tokens or 0
                );
                if prompt_tokens > 0 and prompt_tokens / ctx_window >= comp_threshold {
                    if just_compacted {
                        raise CompactionNotEffectiveError(
                            f"{prompt_tokens}/{ctx_window} tokens "
                            f"({prompt_tokens / ctx_window:.0%}) still at or above threshold "
                            f"{comp_threshold:.0%} after compaction - provide a custom "
                            "on_compaction hook, increase ctx_window, or switch to a model "
                            "with a larger context window."
                        );
                    }
                    logger.info(
                        f"byLLM compaction: {prompt_tokens}/{ctx_window} tokens "
                        f"({prompt_tokens / ctx_window:.0%}) >= threshold {comp_threshold:.0%}. "
                        "Compacting message history."
                    );
                    self._compact_messages(mt_run, comp_keep_recent, comp_model);
                    just_compacted = True;
                } else {
                    just_compacted = False;
                }
            }

            # Metrics: emit LLM call duration and completion-token count for this
            # iteration so consumers can show generation speed (tokens/sec).
            _completion_tokens = int(
                usage.get("completion_tokens", 0)
                    if isinstance(usage, dict)
                    else getattr(usage, "completion_tokens", 0)
            );
            yield StreamEvent(
                event_type="llm_timing",
                data={
                    "duration_ms": _llm_ms,
                    "iteration": iter_count,
                    "completion_tokens": _completion_tokens,
                    "prompt_tokens": _usage_int(usage, "prompt_tokens"),
                    "cache_read_input_tokens": _usage_int(
                        usage, "cache_read_input_tokens"
                    ),
                    "cache_creation_input_tokens": _usage_int(
                        usage, "cache_creation_input_tokens"
                    )
                }
            );

            # The model's reasoning already streamed above as incremental
            # `thought` events while the call was in flight.
            if resp.tool_calls {
                # Split at first finish_tool - normalizes history for both modes.
                non_finish_calls: list = [];
                finish_tc = None;
                for tc in resp.tool_calls {
                    if tc.is_finish_call() {
                        finish_tc = tc;
                        break;
                    }
                    non_finish_calls.append(tc);
                }

                if non_finish_calls {
                    max_result_len = int(
                        mt_run.call_params.get("max_tool_result_length")
                        or self.call_params.get("max_tool_result_length")
                        or _call_params_config.get("max_tool_result_length")
                        or 500
                    );

                    # Parallel: full batch. Sequential: one-at-a-time via dispatch_batch.
                    batches = (
                        [non_finish_calls]
                            if _should_parallelize(mt_run)
                            else [[tc] for tc in non_finish_calls]
                    );

                    for batch in batches {
                        # Announce tool calls before execution
                        for btc in batch {
                            yield StreamEvent(
                                event_type="tool_call",
                                data={
                                    "tool": btc.tool.get_name(),
                                    "args": btc.args,
                                    "call_id": btc.call_id,
                                    "iteration": iter_count
                                }
                            );
                        }

                        # Execute via dispatch_batch, emit results as they complete
                        raw_results: list = [];
                        for (btc, result_msg, tool_ms) in dispatch_batch(batch) {
                            truncated_result = content_preview(
                                result_msg.content, max_result_len
                            );
                            last_tool = btc.tool.get_name();
                            last_result = truncated_result;
                            yield StreamEvent(
                                event_type="tool_result",
                                data={
                                    "tool": btc.tool.get_name(),
                                    "result": truncated_result,
                                    "call_id": btc.call_id,
                                    "iteration": iter_count
                                }
                            );
                            yield StreamEvent(
                                event_type="tool_timing",
                                data={
                                    "tool": btc.tool.get_name(),
                                    "duration_ms": tool_ms,
                                    "call_id": btc.call_id,
                                    "iteration": iter_count
                                }
                            );
                            raw_results.append((btc, result_msg, tool_ms));
                        }

                        # Add messages in input order for deterministic history
                        ordered: dict = {};
                        for r in raw_results {
                            idx = _index_by_identity(batch, r[0]);
                            ordered[idx] = r;
                        }
                        for i in range(len(batch)) {
                            mt_run.add_message(ordered[i][1]);
                        }
                    }
                }

                if finish_tc {
                    mt_run.add_message(finish_tc());
                    # Capture the structured result so a handler-driven invoke
                    # can return it once this generator is consumed.
                    mt_run._final_output = finish_tc.get_output();
                    mt_run._has_final_output = True;
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
                    );
                    # A structured return already carries its value in the finish
                    # tool output; only stream a textual final answer for str/None
                    # returns (the common `by llm() -> str` case).
                    if mt_run.resp_type is None or mt_run.resp_type is str {
                        for token in self._stream_final_answer(mt_run) {
                            if token {
                                yield StreamEvent(
                                    event_type="chunk", data={"content": token}
                                );
                            }
                        }
                    }
                    break;
                }
            } else {
                # No tool calls - check if recovery is needed.
                # (OutputConversionError catch above handles real Model;
                # this branch handles MockLLM which bypasses parse_response.)
                recovery_resp = self._attempt_recovery(mt_run);
                if recovery_resp is None {
                    # The model answered in plain text without calling finish_tool,
                    # so its terminal text IS the final answer - deliver it on the
                    # `chunk` channel instead of leaving it as `thought`-only.
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
                    );
                    final_answer = str(resp.output) if resp.output is not None else "";
                    if final_answer {
                        yield StreamEvent(
                            event_type="chunk", data={"content": final_answer}
                        );
                    }
                    break;
                }
                yield from self._yield_recovery_result(
                    recovery_resp, iter_count, mt_run
                );
                break;
            }
        }
    }
    # Emit aggregated usage from all LLM calls in this invocation, then reset.
    if self._usage_history {
        totals: dict = {};
        per_call_dicts: list = [];
        for u in self._usage_history {
            # Usage may be a Pydantic model (LiteLLM) or a plain dict.
            u_dict = u
                if isinstance(u, dict)
                else (u.model_dump() if u?.model_dump else vars(u));
            per_call_dicts.append(u_dict);
            for (k, v) in u_dict.items() {
                if isinstance(v, (int, float)) {
                    totals[k] = totals.get(k, 0) + v;
                }
            }
        }
        yield StreamEvent(
            event_type="usage", data={"total": totals, "per_call": per_call_dicts}
        );
        self._usage_history = [];
    }
    # If `by llm(conversation=<list>)` was set, mutate the caller's list
    # in place with the persistable conversation. Runs once when the
    # generator is fully consumed.
    mt_run.write_back_conversation();
}
