def _tool_call_fragments(chunk: object) -> list[dict[str, any]];


obj _ToolDeltaCoalescer {
    has out: list[dict[str, any]],
        state: dict[int, dict[str, any]] = {},
        min_chars: int = _TOOL_DELTA_MIN_CHARS,
        min_interval: float = _TOOL_DELTA_MIN_INTERVAL_S,
        max_per_call: int = _TOOL_DELTA_MAX_PER_CALL;

    def observe(frag: dict[str, any]) -> None;
    def _publish(idx: int, st: dict[str, any]) -> None;
    def flush;
}


def _tool_stream_settings(mt_run: MTRuntime) -> dict[str, any];


def _should_parallelize(mt_run: MTRuntime) -> bool;


def _is_transient_error(exc: object) -> bool;


def _retry_sleep(attempt: int);


async def _aretry_sleep(attempt: int);


def _retry_delay(attempt: int) -> float;


def _close_stream(stream: any);


async def _aclose_stream(stream: any);


def _is_prompt_caching_eligible(model_name: str) -> bool;


def _without_cache_control(block: dict[str, any]) -> dict[str, any];


def _mark_message_for_caching(msg: dict[str, any]);


def _usage_int(usage: any, key: str) -> int;


def _apply_prompt_caching(
    messages: list[any], tools: list[dict[str, any]] | None
) -> tuple[list[any], list[dict[str, any]] | None];


def _quiet_lookup(lookup: Callable, fallback: any) -> any;


def _litellm_ctx_window(model_name: str) -> int;


def _existing_cost(usage_obj: object) -> object;


def _rebuild_stream_chunks(chunks: list[any], logging_obj: object) -> dict[str, any];


def _attach_call_cost(
    usage_obj: object, model_name: str, response: object = None
) -> None;


def _usage_to_dict(usage_obj: object) -> dict[str, any];


def _record_usage(
    mt_run: MTRuntime,
    usage_obj: object,
    model_name: str,
    call_kind: str | None = None,
    finish_reason: str | None = None
);


class _StreamReset(str) {}


glob _STREAM_RESET: str = _StreamReset();


def _usage_step_events(
    mt_run: MTRuntime, usage_base: int
) -> Generator[StreamEvent, None, None];


def _compaction_events(
    mt_run: MTRuntime, compactions_base: int, iteration: int
) -> Generator[StreamEvent, None, None];


def _usage_history_total_cost(mt_run: MTRuntime) -> float;


def _copy_for_compaction(model: BaseLLM) -> BaseLLM;


glob _CHARS_PER_TOKEN: int = 4,
     _TAIL_BUDGET_RATIO: float = 0.25,
     _MIN_SLICE_RATIO: float = 0.05,
     _REASONING_MIN_CHARS: int = 200,
     _PASS_THROUGH_PARAMS: tuple[str, ...] = (
         "reasoning_effort",
         "thinking",
         "extra_body"
     );


def _delta_reasoning(chunk: object) -> str;


def _reasoning_chars(msg: any) -> int;


def _reasoning_events(
    mt_run: MTRuntime, iteration: int
) -> Generator[StreamEvent, None, None];


def _answer_events(
    mt_run: MTRuntime, tokens: Generator[str, None, None], iteration: int
) -> Generator[StreamEvent, None, None];


def _message_role(msg: dict[str, any]) -> str;


def _compaction_line(msg: any) -> str;


def _estimate_tokens(messages: list[any]) -> int;


def _tail_start(messages: list[any], keep_recent: int, budget: int) -> int;


def _clip_content(msg: dict[str, any], max_chars: int) -> dict[str, any];


def _clip_tool_results(tail: list[any], budget: int) -> list[any];


def _default_compact(
    messages: list[any],
    keep_recent: int,
    model: BaseLLM,
    parent_mt_run: MTRuntime | None = None,
    ctx_window: int = 0
) -> list[any];


impl BaseLLM._get_ctx_window(call_params: dict[str, any]) -> int {
    `override = int(
        call_params.get("ctx_window")
            or self.ctx_window
            or get_byllm_config().get_compaction_config().get("ctx_window", 0)
            or 0
    );
    if `override > 0 {
        return `override;
    }
    return _litellm_ctx_window(self.model_name);
}


impl BaseLLM._resolve_compaction_params(mt_run: MTRuntime) -> dict[str, any] {
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


impl BaseLLM._maybe_compact(
    mt_run: MTRuntime, usage: object, just_compacted: bool, cp: dict[str, any]
) -> bool {
    ctx_window = int(cp["ctx_window"]);
    if not (bool(cp["enabled"]) and ctx_window > 0) {
        return just_compacted;
    }
    comp_threshold = float(cp["threshold"]);
    prompt_tokens = int(
        usage.get("prompt_tokens", 0)
            if isinstance(usage, dict)
            else usage?.prompt_tokens or 0
    );
    if prompt_tokens > 0 and prompt_tokens / ctx_window >= comp_threshold {
        if just_compacted {
            logger.warning(
                f"byLLM compaction: {prompt_tokens}/{ctx_window} tokens "
                f"({prompt_tokens / ctx_window:.0%}) still at or above threshold "
                f"{comp_threshold:.0%} after compaction. Continuing: the provider's "
                "own limit decides. Provide a custom on_compaction hook, increase "
                "ctx_window, or switch to a model with a larger context window."
            );
            return True;
        }
        logger.info(
            f"byLLM compaction: {prompt_tokens}/{ctx_window} tokens "
            f"({prompt_tokens / ctx_window:.0%}) >= threshold {comp_threshold:.0%}. "
            "Compacting message history."
        );
        if self._compact_messages(mt_run, cp, "threshold") {
            return True;
        }
        logger.warning(
            "byLLM compaction: could not reduce the message history (nothing "
            "worth summarising). Continuing: the provider's own limit decides."
        );
    }
    return False;
}


impl BaseLLM._emergency_compact(
    mt_run: MTRuntime, just_compacted: bool, cp: dict[str, any]
) -> None {
    if not bool(cp["enabled"]) {
        raise;
    }
    if just_compacted {
        raise CompactionNotEffectiveError(
            "Context window exceeded again after compaction - "
            "provide a custom on_compaction hook, increase ctx_window, "
            "or switch to a model with a larger context window."
        );
    }
    logger.warning(
        "byLLM compaction: context window exceeded, triggering emergency compaction."
    );
    if not self._compact_messages(mt_run, cp, "overflow")
        and len(mt_run.messages) >= 4 {
        raise CompactionNotEffectiveError(
            "Compaction produced no reduction in message history - "
            "check on_compaction hook or compaction model."
        );
    }
}


impl BaseLLM._compact_messages(
    mt_run: MTRuntime, cp: dict[str, any], reason: str
) -> bool {
    keep_recent = int(cp["keep_recent"]);
    comp_model = cp["model"];
    on_compaction = (
        mt_run.call_params.get("on_compaction") or self.call_params.get("on_compaction")
    );
    original_len = len(mt_run.messages);
    msg_dicts = mt_run.get_msg_list();
    tokens_before = _estimate_tokens(msg_dicts);
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
            model_for_compaction: BaseLLM = Model(
                model_name=comp_model,
                api_key=self.api_key,
                config=self.config,
                call_params={"compaction_enabled": False}
            );
        } else {
            model_for_compaction = _copy_for_compaction(self);
        }
        compacted = _default_compact(
            msg_dicts, keep_recent, model_for_compaction, mt_run, int(cp["ctx_window"])
        );
    }
    tokens_after = _estimate_tokens(compacted);
    if tokens_after >= tokens_before {
        return False;
    }
    mt_run.messages = compacted;
    mt_run._llm_hook_cursor = 0;
    mt_run._llm_hook_compacted = True;
    mt_run._compactions.append(
        {
            "reason": reason,
            "by": "hook" if on_compaction else "builtin",
            "messages_before": original_len,
            "messages_after": len(compacted),
            "tokens_before": tokens_before,
            "tokens_after": tokens_after
        }
    );
    logger.info(
        f"byLLM compaction: reduced message list from {original_len} to "
        f"{len(compacted)} messages, about {tokens_before} to {tokens_after} tokens"
    );
    return True;
}


impl BaseLLM.ainvoke(mt_run: MTRuntime) -> any {
    import asyncio;
    self._call_deadline(mt_run);
    if image_resp_kind(mt_run.resp_type) {
        return await asyncio.to_thread(self.dispatch_image, mt_run);
    }
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


impl BaseLLM.__call__(**kwargs: object) -> BaseLLM {
    self.call_params = kwargs;
    return self;
}

impl BaseLLM.invoke(mt_run: MTRuntime) -> any {
    self._call_deadline(mt_run);
    if image_resp_kind(mt_run.resp_type) {
        return self.dispatch_image(mt_run);
    }
    handler = mt_run.call_params.get("stream_handler");
    if mt_run.stream and handler is not None and callable(handler) {
        return self._invoke_with_handler(mt_run, cast(Callable, handler));
    }

    if mt_run.stream and mt_run.call_params.get("logging", False) {
        return self._invoke_streaming(mt_run);
    }

    if mt_run.stream and len(mt_run.tools) == 0 {
        return self.dispatch_streaming(mt_run);
    }

    if mt_run.stream {
        return self._invoke_react_loop_streaming(mt_run);
    }
    return self._invoke_typed_retry(mt_run);
}


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


impl BaseLLM._resolve_timeout(mt_run: MTRuntime) -> float | None {
    timeout: any = mt_run.call_params.get("timeout");
    if timeout is None {
        timeout = self.call_params.get("timeout");
    }
    if timeout is None {
        timeout = self.timeout;
    }
    if timeout is None {
        timeout = _call_params_config.get("timeout");
    }
    if timeout is None {
        timeout = 600.0;
    }
    resolved = float(timeout);
    return resolved if resolved > 0 else None;
}


impl BaseLLM._call_deadline(mt_run: MTRuntime) -> CallDeadline {
    if mt_run._deadline is None {
        mt_run._deadline = CallDeadline(
            budget=self._resolve_timeout(mt_run), model=self.model_name
        );
    }
    return mt_run._deadline;
}


impl BaseLLM._arm_attempt(
    mt_run: MTRuntime, params: dict[str, any], stream: bool
) -> None {
    deadline = self._call_deadline(mt_run);
    deadline.check();
    if stream {
        import httpx;
        params["timeout"] = httpx.Timeout(
            connect=deadline.bound(_streaming_config.get("connect_timeout", 30.0)),
            read=deadline.bound(_streaming_config.get("read_timeout", 90.0)),
            write=deadline.bound(_streaming_config.get("write_timeout", 30.0)),
            pool=deadline.bound(_streaming_config.get("pool_timeout", 30.0))
        );
        return;
    }
    left = deadline.remaining();
    if left is None {
        params.pop("timeout", None);
    } else {
        params["timeout"] = left;
    }
}


impl BaseLLM._may_retry(mt_run: MTRuntime, e: Exception, attempt: int) -> bool {
    if not (
        _is_transient_error(e) and attempt < self._resolve_stream_retries(mt_run)
    ) {
        return False;
    }
    deadline = self._call_deadline(mt_run);
    left = deadline.remaining();
    if left is None or left > _retry_delay(attempt + 1) {
        return True;
    }
    left = max(0.0, left);
    self.log_info(
        f"Transient LLM error ({type(e).__name__}) on {self.model_name}; not "
        f"retrying with {left:.1f}s left of the {deadline.budget:g}s timeout"
    );
    return False;
}


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


impl BaseLLM._typed_retry_reset(
    mt_run: MTRuntime,
    base_msgs: list[any],
    base_scaffolding: list[any],
    reason: str,
    output: str
) -> None {
    mt_run.messages = list(base_msgs);
    mt_run._llm_hook_cursor = 0;
    mt_run._llm_hook_compacted = True;
    mt_run._scaffolding_ids = list(base_scaffolding);
    mt_run._has_final_output = False;
    mt_run._final_output = None;
    mt_run.add_scaffolding_message(self._typed_retry_feedback(mt_run, reason, output));
}


impl BaseLLM._parse_failure_feedback(
    attempt: int, max_attempts: int, err: object
) -> tuple[str, str] {
    self.log_info(
        f"[byllm] typed-output attempt {attempt}/{max_attempts} failed to parse: {err}"
    );
    return (
        f"The output parser reported: {err}.",
        str(getattr(err, "raw_output", "") or "")
    );
}


impl BaseLLM._nonconforming_feedback(
    attempt: int, max_attempts: int, mt_run: MTRuntime, result: object
) -> tuple[OutputConversionError, str, str] {
    self.log_info(
        f"[byllm] typed-output attempt {attempt}/{max_attempts} "
            + "returned a non-conforming value; retrying"
    );
    type_name = type_display_name(mt_run.resp_type);
    err = OutputConversionError(
        f"LLM returned a non-conforming value for return type "
            + f"'{type_name}' (got '{type(result).__name__}'); the "
            + "response was likely empty or not valid JSON"
    );
    reason = (
        "The previous response was empty or did not contain a JSON "
        + "object (it could not be converted to the required type)."
    );
    return (err, reason, str(result));
}


impl BaseLLM._typed_retry_exhausted(
    attempts: int, cause: object, raw: str
) -> OutputConversionError {
    err = OutputConversionError(
        f"typed-output generation failed after {attempts} attempt(s) "
            + f"({attempts - 1} retries); last error: {cause}"
    );
    setattr(err, "raw_output", raw);
    return err;
}


impl BaseLLM._typed_retry_feedback(
    mt_run: MTRuntime, reason: str, prev_output: str
) -> Message {
    type_name = type_display_name(mt_run.resp_type);

    schema = mt_run.get_typed_output_schema();
    schema_txt = (
        json.dumps(schema, ensure_ascii=False) if schema else "(schema unavailable)"
    );
    prev_block = f"Your previous response was:\n{prev_output}\n" if prev_output else "";
    return Message(
        role=MessageRole.USER,
        content=(
            f"Your previous response could not be used. {reason}\n"
            + prev_block
            + f"You MUST reply with ONLY a single JSON object that validates "
            + f"against this JSON schema for `{type_name}`:\n{schema_txt}\n"
            + "Output the raw JSON object only, with no explanation, no reasoning "
            + "text, no markdown code fences, nothing before or after the JSON."
        )
    );
}


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


impl BaseLLM._invoke_with_handler(mt_run: MTRuntime, on_event: Callable) -> object {
    if len(mt_run.tools) == 0
        and mt_run.resp_type is not None
        and mt_run.resp_type is not str {
        accumulated = "";
        try {
            for ev in _answer_events(
                mt_run, self.dispatch_streaming(mt_run, retractable=True), 0
            ) {
                if ev.event_type == "stream_reset" {
                    accumulated = "";
                } elif ev.event_type == "chunk" {
                    accumulated += ev.data["content"];
                }
                try {
                    on_event(ev);
                } except Exception as e {
                    logger.debug(f"stream_handler raised: {e}");
                }
            }
        } finally {
            mt_run.write_back_conversation();
        }

        if mt_run._usage_history {
            try {
                on_event(
                    StreamEvent(
                        event_type="llm_timing",
                        data={"duration_ms": 0.0, "iteration": 0}
                    )
                );
            } except Exception as e {
                logger.debug(f"stream_handler raised: {e}");
            }
        }
        return mt_run.parse_response(accumulated);
    }

    parts: list[str] = [];
    for ev in self._invoke_streaming(mt_run) {
        try {
            on_event(ev);
        } except Exception as e {
            logger.debug(f"stream_handler raised: {e}");
        }
        if ev.event_type == "stream_reset" {
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
                total_tokens=total_tokens,
                total_cost=_usage_history_total_cost(mt_run)
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
            if mt_run.stream {
                return self._stream_final_answer(mt_run);
            }
            return self._force_final_answer(mt_run);
        }
        try {
            resp = self.dispatch_no_streaming(mt_run);
        } except litellm.exceptions.ContextWindowExceededError {
            self._emergency_compact(mt_run, just_compacted, _cp);
            just_compacted = True;
            resp = self.dispatch_no_streaming(mt_run);
        } except OutputConversionError {
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
        usage: dict[str, any] = resp.usage or {};
        total_tokens += int(
            usage.get("total_tokens", 0)
                if isinstance(usage, dict)
                else getattr(usage, "total_tokens", 0)
        );

        just_compacted = self._maybe_compact(mt_run, usage, just_compacted, _cp);
        if resp.tool_calls {
            (non_finish_calls, finish_tc, skipped_calls) = _split_at_finish(
                resp.tool_calls
            );

            if non_finish_calls {
                batches = (
                    [non_finish_calls]
                        if _should_parallelize(mt_run)
                        else [[tc] for tc in non_finish_calls]
                );
                for batch in batches {
                    raw_results: list[tuple[ToolCall, Message, float]] = list(
                        dispatch_batch(batch)
                    );
                    ordered: dict[int, tuple[ToolCall, Message, float]] = {};
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

            _answer_skipped(mt_run, skipped_calls);

            if finish_tc {
                try {
                    finish_msg = finish_tc();
                    final_output = finish_tc.get_output();
                } except FinishToolError as e {
                    mt_run.add_message(
                        _error_tool_call(finish_tc.call_id, "finish_tool", str(e))()
                    );
                    continue;
                }
                mt_run.add_message(finish_msg);
                if mt_run.stream {
                    return self._stream_final_answer(
                        mt_run, fallback=str(final_output or "")
                    );
                }
                return final_output;
            }
        } else {
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

impl BaseLLM.make_model_params(mt_run: MTRuntime) -> dict[str, any] {
    default_temp = _call_params_config.get("temperature");
    default_max_tokens = _call_params_config.get("max_tokens");

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

    messages = reroute_tool_images_to_user_message(messages);
    tools = mt_run.get_tool_list() or None;

    if _should_parallelize(mt_run)
        and tools
        and mt_run.call_params.get("parallel_hint", True)
        and messages
        and len(messages) > 0 {
        annotated: list[dict[str, any]] = [];
        serial_names: list[str] = [];
        for (i, schema) in enumerate(tools) {
            tool_obj = mt_run.tools[i] if i < len(mt_run.tools) else None;
            is_serial = bool(getattr(tool_obj, "serialize", False));
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

        first_msg = messages[0];
        if isinstance(first_msg, dict) and first_msg.get("role") == "system" {
            content = first_msg.get("content", "");
            if isinstance(content, str) and _PARALLEL_TOOL_HINT not in content {
                hint = _PARALLEL_TOOL_HINT;

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

    first = messages[0] if messages else None;

    mt_run._sent_system = dict(first)
        if isinstance(first, dict) and first.get("role") == "system"
        else None;
    if _is_prompt_caching_eligible(self.model_name) {
        (messages, tools) = _apply_prompt_caching(messages, tools);
    }

    params = {
        "model": self.model_name,
        "api_key": self.api_key or None,
        "api_base": self._resolve_api_base(),
        "messages": messages,
        "tools": tools,
        "response_format": mt_run.get_output_schema(),
        "max_tokens": self.call_params.get("max_tokens", default_max_tokens),
        "metadata": agent_metadata,

    };

    resolved_temp = self.call_params.get("temperature", default_temp);
    if resolved_temp is not None {
        params["temperature"] = resolved_temp;
    }

    if "tool_choice" in mt_run.call_params {
        params["tool_choice"] = mt_run.call_params["tool_choice"];
    }

    for key in _PASS_THROUGH_PARAMS {
        value = self.call_params.get(key, _call_params_config.get(key));
        if value is not None {
            params[key] = value;
        }
    }

    params = inject_schema_hint(params);

    if not self.supports_native_tools {
        params = inject_tool_hint(params);
    }

    self._arm_attempt(mt_run, params, mt_run.stream);
    return params;
}

impl BaseLLM.log_info(message: str) -> None {
    verbose = self.config.get("verbose", _model_config.get("verbose", False));
    if bool(verbose) {
        logger.info(message);
    }
}

impl BaseLLM.format_prompt(params: dict[str, any]) -> str {
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

def _error_tool_call(call_id: str, tool_name: str, reason: str) -> ToolCall;

def _split_at_finish(
    tool_calls: list[ToolCall]
) -> tuple[list[ToolCall], ToolCall | None, list[ToolCall]];

def _answer_skipped(mt_run: MTRuntime, skipped: list[ToolCall]) -> None;

def _parse_tool_calls(
    mt_run: MTRuntime,
    tool_calls_list: list[any],
    truncated_ids: set | None = None,
    damaged_ids: set | None = None
) -> list[ToolCall];


def _sanitize_tool_calls(message: dict[str, any]) -> set[str];


def _raise_if_empty_truncation(finish_reason: str, content: any, tool_calls: any);


def _truncated_call_ids(message: dict[str, any], finish_reason: str) -> set[str];


impl BaseLLM.dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);

    log_params = self.format_prompt(params);
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    while True {
        self._arm_attempt(mt_run, params, False);
        try {
            response = self.model_call_no_stream(params);
            break;
        } except Exception as e {
            if self._may_retry(mt_run, e, attempt) {
                attempt += 1;
                self.log_info(
                    f"Transient LLM error ({type(e).__name__}); "
                    f"retry {attempt} on {self.model_name}"
                );
                _retry_sleep(attempt);
                continue;
            }

            self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");
            raise;
        }
    }

    actual_model = response.get("model", self.model_name);
    self.log_info(f"Calling LLM: {actual_model} with params: {log_params}");

    message = coerce_message_dict(response.get("choices", [])[0].get("message"));

    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    damaged_ids = _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content = message.get("content") or "";
    assert isinstance(output_content, str);
    self.log_info(f"LLM call completed with response: {output_content}");
    finish_reason = str(
        (response.get("choices") or [{}])[0].get("finish_reason") or ""
    );

    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    _tc_raw: any = (message or {}).get("tool_calls") or [];
    tool_calls_list: list[any] = _tc_raw if isinstance(_tc_raw, list) else [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids, damaged_ids);

    usage_data = response.get("usage", {});
    _attach_call_cost(usage_data, self.model_name, response);
    _record_usage(mt_run, usage_data, actual_model, finish_reason=finish_reason);
    _notify_llm_call(mt_run);
    _raise_if_empty_truncation(finish_reason, output_content, tool_calls_list);
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    return CompletionResult(
        output=output_value,
        tool_calls=tool_calls,
        usage=usage_data,
        finish_reason=finish_reason
    );
}

impl BaseLLM._should_retry_stream(
    mt_run: MTRuntime,
    e: Exception,
    attempt: int,
    usage_base: int = -1,
    restartable: bool = True
) -> bool {
    if not (restartable and self._may_retry(mt_run, e, attempt)) {
        return False;
    }
    if usage_base >= 0 {
        mt_run._usage_history = mt_run._usage_history[:usage_base];
    }
    self.log_info(
        f"Transient stream error ({type(e).__name__}); "
        f"retry {attempt + 1} on {self.model_name}"
    );
    return True;
}

impl BaseLLM.dispatch_streaming(
    mt_run: MTRuntime, retractable: bool = False
) -> Generator[str, None, None] {
    params = self.make_model_params(mt_run);

    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    usage_base = len(mt_run._usage_history);
    stream_model: str = self.model_name;
    events = bool(mt_run.call_params.get("logging", False));
    deadline = self._call_deadline(mt_run);
    while True {
        finish_reason = "";
        produced = False;
        shown = False;
        mt_run._last_stream_chunks = [];
        reasoning_pending = "";
        self._arm_attempt(mt_run, params, True);
        response: any = None;
        try {
            response = self.model_call_with_stream(params);
            for chunk in response {
                deadline.check();
                if mt_run._call_kind == "final_answer_restream" {
                    mt_run._last_stream_chunks.append(chunk);
                }
                if events {
                    reasoning_pending += _delta_reasoning(chunk);
                    answering = bool(
                        chunk?.choices and chunk?.choices?[0]?.delta?.content
                    );
                    if reasoning_pending
                        and (
                            len(reasoning_pending) >= _REASONING_MIN_CHARS or answering
                        ) {
                        mt_run._reasoning_deltas.append(reasoning_pending);
                        reasoning_pending = "";
                    }
                }
                stream_model = chunk?.model or stream_model;
                if chunk?.choices and chunk?.choices?[0]?.finish_reason {
                    finish_reason = str(chunk?.choices?[0]?.finish_reason);
                }
                chunk_usage = chunk?.usage;
                if chunk_usage {
                    chunk_model: str = chunk?.model or self.model_name;
                    _attach_call_cost(chunk_usage, chunk_model);
                    _record_usage(
                        mt_run, chunk_usage, chunk_model, finish_reason=finish_reason
                    );
                }
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    content = str(chunk?.choices?[0]?.delta?.content or "");
                    shown = shown or bool(content);
                    produced = produced or bool(content.strip());
                    yield content;
                }
            }
            if reasoning_pending {
                mt_run._reasoning_deltas.append(reasoning_pending);
                yield "";
            }
            break;
        } except Exception as e {
            if self._should_retry_stream(
                mt_run, e, attempt, usage_base, retractable or not shown
            ) {
                attempt += 1;
                if retractable {
                    yield _STREAM_RESET;
                }
                _retry_sleep(attempt);
                continue;
            }
            raise;
        } finally {
            _close_stream(response);
        }
    }

    if len(mt_run._usage_history) == usage_base {
        _record_usage(mt_run, {}, stream_model, finish_reason=finish_reason);
    }
    if not produced {
        _raise_if_empty_truncation(finish_reason, "", None);
    }
}

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
    chunks: list[any] = [];
    content_buf = "";
    reasoning_buf = "";
    no_stream = False;
    finish_reason = "";
    attempt = 0;
    deadline = self._call_deadline(mt_run);
    while True {
        chunks = [];
        content_buf = "";
        reasoning_buf = "";
        reasoning_pending = "";
        self._arm_attempt(mt_run, params, True);

        mt_run._tool_arg_deltas = [];
        settings = _tool_stream_settings(mt_run);
        stream_args = bool(settings.get("enabled", False));
        coalescer = _ToolDeltaCoalescer(
            out=mt_run._tool_arg_deltas,
            min_chars=int(settings.get("min_chars", _TOOL_DELTA_MIN_CHARS)),
            min_interval=float(
                settings.get("min_interval", _TOOL_DELTA_MIN_INTERVAL_S)
            ),
            max_per_call=int(settings.get("max_per_call", _TOOL_DELTA_MAX_PER_CALL))
        );
        _stream_resp: any = None;
        try {
            _stream_resp = self.model_call_with_stream(params);
            for chunk in _stream_resp {
                deadline.check();
                chunks.append(chunk);
                pending_before = len(mt_run._tool_arg_deltas);
                if stream_args {
                    for _frag in _tool_call_fragments(chunk) {
                        coalescer.observe(_frag);
                    }
                }
                delta_content = "";
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    delta_content = chunk?.choices?[0]?.delta?.content or "";
                } elif isinstance(chunk, dict) {
                    _choices: any = chunk.get("choices") or [];
                    if _choices {
                        delta_content = str(
                            (_choices[0].get("delta") or {}).get("content") or ""
                        );
                    }
                }
                delta_reasoning = _delta_reasoning(chunk);
                if delta_reasoning {
                    reasoning_buf += delta_reasoning;
                    reasoning_pending += delta_reasoning;
                }
                if reasoning_pending
                    and (
                        len(reasoning_pending) >= _REASONING_MIN_CHARS
                        or delta_content
                        or _tool_call_fragments(chunk)
                    ) {
                    mt_run._reasoning_deltas.append(reasoning_pending);
                    reasoning_pending = "";
                    yield "";
                }
                if delta_content {
                    content_buf += str(delta_content);
                    yield str(delta_content);
                } elif len(mt_run._tool_arg_deltas) > pending_before {
                    yield "";
                }
            }
            if stream_args {
                coalescer.flush();
            }
            if reasoning_pending {
                mt_run._reasoning_deltas.append(reasoning_pending);
                yield "";
            }
            break;
        } except NotImplementedError {
            no_stream = True;
            break;
        } except Exception as e {
            if self._should_retry_stream(mt_run, e, attempt) {
                attempt += 1;
                yield _STREAM_RESET;
                _retry_sleep(attempt);
                continue;
            }
            raise;
        } finally {
            _close_stream(_stream_resp);
        }
    }
    if no_stream {
        out.append(self.dispatch_no_streaming(mt_run));
        return;
    }

    message: (dict[str, any] | None) = None;
    usage_data: dict[str, any] = {};
    actual_model = self.model_name;
    try {
        rebuilt = _rebuild_stream_chunks(chunks, _stream_resp?.logging_obj);
        if rebuilt {
            message = coerce_message_dict(rebuilt.get("choices", [])[0].get("message"));
            usage_data = rebuilt.get("usage", {}) or {};
            actual_model = rebuilt.get("model", self.model_name);
            _attach_call_cost(usage_data, actual_model, rebuilt);
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
        if reasoning_buf {
            message["reasoning_content"] = reasoning_buf;
        }
    }

    has_native_tool_calls = bool((message or {}).get("tool_calls"));
    if (not self.supports_native_tools)
        or (mt_run.tools and not has_native_tool_calls) {
        if not has_native_tool_calls and not isinstance(message, dict) {
            message = {"role": "assistant", "content": content_buf};
        }
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    damaged_ids = _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content = message.get("content") or "";
    assert isinstance(output_content, str);

    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    _tc_raw: any = (message or {}).get("tool_calls") or [];
    tool_calls_list: list[any] = _tc_raw if isinstance(_tc_raw, list) else [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids, damaged_ids);
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    _record_usage(mt_run, usage_data, actual_model, finish_reason=finish_reason);
    _notify_llm_call(mt_run);
    out.append(
        CompletionResult(
            output=output_value,
            tool_calls=tool_calls,
            usage=usage_data,
            finish_reason=finish_reason
        )
    );
}

impl BaseLLM.adispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    while True {
        self._arm_attempt(mt_run, params, False);
        try {
            response = await self.model_call_no_stream_async(params);
            break;
        } except Exception as e {
            if self._may_retry(mt_run, e, attempt) {
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
    message = coerce_message_dict(response.get("choices", [])[0].get("message"));

    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    damaged_ids = _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content = message.get("content") or "";
    assert isinstance(output_content, str);
    self.log_info(f"LLM call completed with response: {output_content}");
    finish_reason = str(
        (response.get("choices") or [{}])[0].get("finish_reason") or ""
    );

    truncated_ids = _truncated_call_ids(message, finish_reason);
    tool_calls: list[ToolCall] = [];
    _tc_raw: any = (message or {}).get("tool_calls") or [];
    tool_calls_list: list[any] = _tc_raw if isinstance(_tc_raw, list) else [];
    tool_calls = _parse_tool_calls(mt_run, tool_calls_list, truncated_ids, damaged_ids);
    usage_data = response.get("usage", {});
    _attach_call_cost(usage_data, self.model_name, response);
    _record_usage(mt_run, usage_data, actual_model, finish_reason=finish_reason);
    _notify_llm_call(mt_run);
    _raise_if_empty_truncation(finish_reason, output_content, tool_calls_list);
    output_value = mt_run.parse_response(output_content)
        if not tool_calls_list
        else output_content;
    return CompletionResult(
        output=output_value,
        tool_calls=tool_calls,
        usage=usage_data,
        finish_reason=finish_reason
    );
}

impl BaseLLM.adispatch_streaming(mt_run: MTRuntime) -> AsyncIterator[str] {
    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    usage_base = len(mt_run._usage_history);
    stream_model: str = self.model_name;
    deadline = self._call_deadline(mt_run);
    while True {
        finish_reason = "";
        produced = False;
        shown = False;
        self._arm_attempt(mt_run, params, True);
        response: any = None;
        try {
            response = await self.model_call_with_stream_async(params);
            async for chunk in response {
                deadline.check();
                stream_model = chunk?.model or stream_model;
                if chunk?.choices and chunk?.choices?[0]?.finish_reason {
                    finish_reason = str(chunk?.choices?[0]?.finish_reason);
                }
                chunk_usage = chunk?.usage;
                if chunk_usage {
                    chunk_model: str = chunk?.model or self.model_name;
                    _attach_call_cost(chunk_usage, chunk_model);
                    _record_usage(
                        mt_run, chunk_usage, chunk_model, finish_reason=finish_reason
                    );
                }
                if chunk?.choices and chunk?.choices?[0]?.delta {
                    content = str(chunk?.choices?[0]?.delta?.content or "");
                    shown = shown or bool(content);
                    produced = produced or bool(content.strip());
                    yield content;
                }
            }
            break;
        } except Exception as e {
            if self._should_retry_stream(mt_run, e, attempt, usage_base, not shown) {
                attempt += 1;
                await _aretry_sleep(attempt);
                continue;
            }
            raise;
        } finally {
            await _aclose_stream(response);
        }
    }

    if len(mt_run._usage_history) == usage_base {
        _record_usage(mt_run, {}, stream_model, finish_reason=finish_reason);
    }
    if not produced {
        _raise_if_empty_truncation(finish_reason, "", None);
    }
}

glob _IMAGE_CALL_PARAMS: tuple[str, ...] = (
         "n",
         "size",
         "quality",
         "style",
         "response_format",
         "user",
         "timeout"
     );


def _image_prompt(mt_run: MTRuntime) -> str;


def _images_from_response(response: dict[str, any]) -> list[Image];


impl BaseLLM.dispatch_image(mt_run: MTRuntime) -> object {
    params: dict[str, any] = {
        "model": self.model_name,
        "prompt": _image_prompt(mt_run),
        "response_format": "b64_json"
    };
    api_base = self._resolve_api_base();
    if api_base {
        params["api_base"] = api_base;
    }
    for key in _IMAGE_CALL_PARAMS {
        value = mt_run.call_params.get(key, self.call_params.get(key));
        if value is not None {
            params[key] = value;
        }
    }
    self.log_info(f"Calling image model: {self.model_name} with params: {params}");
    response = self.model_call_image(params);
    _record_usage(
        mt_run,
        response.get("usage") or {},
        str(response.get("model") or self.model_name),
        call_kind="image_generation"
    );
    images = _images_from_response(response);
    return images if image_resp_kind(mt_run.resp_type) == "many" else images[0];
}


impl BaseLLM._resolve_api_base -> str {
    return (
        self.config.get("base_url")
        or self.config.get("host")
        or self.config.get("api_base")
        or self.api_base
        or _model_config.get("base_url")
        or ""
    );
}

impl BaseLLM.model_call_image(params: dict[str, any]) -> dict[str, any] {
    raise NotImplementedError(
        f"{type(self).__name__} cannot generate images: implement "
        "model_call_image to serve an Image return type."
    );
}

impl BaseLLM.model_call_no_stream(params: dict[str, any]) -> dict[str, any] {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call without streaming."
    );
}

impl BaseLLM.model_call_with_stream(params: dict[str, any]) -> Iterable[object] {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call with streaming."
    );
}

impl BaseLLM.model_call_no_stream_async(params: dict[str, any]) -> dict[str, any] {
    import asyncio;
    return await asyncio.to_thread(self.model_call_no_stream, params);
}

impl BaseLLM.model_call_with_stream_async(
    params: dict[str, any]
) -> AsyncIterator[object] {
    import asyncio;

    def _next_chunk(gen: Generator[object, None, None]) -> tuple[bool, object] {
        try {
            return (True, next(gen));
        } except StopIteration {
            return (False, None);
        }
    }
    async def _iter -> AsyncGenerator[object, None] {
        gen = iter(await asyncio.to_thread(self.model_call_with_stream, params));
        while True {
            (has_value, chunk) = await asyncio.to_thread(_next_chunk, gen);
            if not has_value {
                break;
            }
            yield chunk;
        }
    }
    return _iter();
}

impl BaseLLM._force_final_answer(mt_run: MTRuntime) -> object {
    final_instruction = Message(
        role=MessageRole.USER,
        content="Based on the tool calls and their results above, provide only your final answer.",
    );
    mt_run.add_scaffolding_message(final_instruction);
    original_call_kind = mt_run._call_kind;
    finish_tool_obj = mt_run.get_tool("finish_tool");
    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    if finish_tool_obj {
        mt_run.call_params["tool_choice"] = {
            "type": "function",
            "function": {"name": "finish_tool"}
        };
    }
    mt_run._call_kind = "final_answer_restream";
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
        mt_run._call_kind = original_call_kind;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }
    }
}


impl BaseLLM._stream_final_answer(
    mt_run: MTRuntime, fallback: str | None = None, retractable: bool = False
) -> Generator[str, None, None] {
    final_instruction = Message(
        role=MessageRole.USER,
        content="Based on the tool calls and their results above, provide your final answer. "
        "Be comprehensive and synthesize all the information gathered.",
    );
    mt_run.add_scaffolding_message(final_instruction);

    original_call_kind = mt_run._call_kind;
    mt_run._call_kind = "final_answer_restream";

    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    mt_run.call_params["tool_choice"] = "none";
    accumulated: str = "";
    try {
        for token in self.dispatch_streaming(mt_run, retractable) {
            if token is _STREAM_RESET {
                accumulated = "";
            } else {
                accumulated += token;
            }
            yield token;
        }
        if not accumulated and fallback is not None {
            accumulated = fallback;
            yield fallback;
        }
    } except OutputTruncatedError {
        if fallback is None {
            raise;
        }
        accumulated = fallback;
        yield fallback;
    } except Exception {
        accumulated = "";
        raise;
    } finally {
        mt_run._call_kind = original_call_kind;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }

        if accumulated {
            final: dict[str, any] = {"role": "assistant", "content": accumulated};
            try {
                rebuilt = _rebuild_stream_chunks(mt_run._last_stream_chunks, None)
                    if mt_run._last_stream_chunks
                    else None;
                if rebuilt {
                    final = coerce_message_dict(
                        rebuilt.get("choices", [])[0].get("message")
                    );
                    final["content"] = accumulated;
                    final.pop("tool_calls", None);
                }
            } except Exception as e {
                logger.debug(f"final answer rebuild failed, keeping the text: {e}");
                reasoning = "".join(
                    _delta_reasoning(c) for c in mt_run._last_stream_chunks
                );
                if reasoning {
                    final["reasoning_content"] = reasoning;
                }
            }
            mt_run._last_stream_chunks = [];
            mt_run.add_message(final);
            _notify_llm_call(mt_run);
        }
    }
}

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
    original_call_kind = mt_run._call_kind;
    mt_run._call_kind = "recovery";
    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    mt_run.call_params["tool_choice"] = {
        "type": "function",
        "function": {"name": "finish_tool"}
    };
    try {
        return self.dispatch_no_streaming(mt_run);
    } finally {
        mt_run._call_kind = original_call_kind;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }
    }
}

impl BaseLLM._yield_recovery_result(
    recovery_resp: CompletionResult, iter_count: int, mt_run: MTRuntime, usage_base: int
) -> Generator[StreamEvent, None, None] {
    finish_found = False;
    committed = "";
    if recovery_resp.tool_calls {
        for tool_call in recovery_resp.tool_calls {
            if tool_call.is_finish_call() {
                mt_run.add_message(tool_call());
                committed = str(tool_call.get_output() or "");
                finish_found = True;
                break;
            }
        }
    }
    yield StreamEvent(event_type="steps_done", data={"iterations": iter_count});
    if finish_found {
        yield from _answer_events(
            mt_run,
            self._stream_final_answer(mt_run, fallback=committed, retractable=True),
            iter_count
        );
    } elif recovery_resp.output {
        yield StreamEvent(
            event_type="chunk", data={"content": str(recovery_resp.output)}
        );
    }
    yield from _usage_step_events(mt_run, usage_base);
}

impl BaseLLM._invoke_streaming(
    mt_run: MTRuntime
) -> Generator[StreamEvent, None, None] {
    try {
        yield from self._stream_steps(mt_run);
    } finally {
        mt_run.write_back_conversation();
    }
}

impl BaseLLM._stream_steps(mt_run: MTRuntime) -> Generator[StreamEvent, None, None] {
    if len(mt_run.tools) == 0 {
        yield from _answer_events(
            mt_run, self.dispatch_streaming(mt_run, retractable=True), 0
        );
    } else {
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
        iter_count = 0;
        last_tool = "";
        last_result = "";
        total_tokens = 0;
        just_compacted = False;
        while True {
            iter_count += 1;
            _usage_base = len(mt_run._usage_history);
            _compactions_base = len(mt_run._compactions);

            if on_iteration and iter_count > 1 {
                ctx = IterationContext(
                    iteration=iter_count,
                    messages=mt_run.messages,
                    last_tool=last_tool,
                    last_result=last_result,
                    total_tokens=total_tokens,
                    total_cost=_usage_history_total_cost(mt_run)
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
                    yield from _answer_events(
                        mt_run,
                        self._stream_final_answer(mt_run, retractable=True),
                        iter_count
                    );
                    yield from _usage_step_events(mt_run, _usage_base);
                    break;
                }
            }

            if int(max_iters) > 0 and iter_count > int(max_iters) {
                yield StreamEvent(
                    event_type="steps_done",
                    data={"iterations": iter_count - 1, "reason": "max_iterations"}
                );
                yield from _answer_events(
                    mt_run,
                    self._stream_final_answer(mt_run, retractable=True),
                    iter_count
                );
                yield from _usage_step_events(mt_run, _usage_base);
                break;
            }

            import time as _time;
            _llm_t0 = _time.time();
            try {
                _stream_out: list[CompletionResult] = [];
                _emitted_deltas = False;
                for _tok in self.dispatch_streaming_with_tools(mt_run, _stream_out) {
                    if _tok is _STREAM_RESET {
                        yield StreamEvent(
                            event_type="stream_reset",
                            data={"scope": "thought", "iteration": iter_count}
                        );
                        continue;
                    }
                    yield from _reasoning_events(mt_run, iter_count);
                    while mt_run._tool_arg_deltas {
                        _d = mt_run._tool_arg_deltas.pop(0);
                        _emitted_deltas = True;
                        yield StreamEvent(
                            event_type="tool_call_delta",
                            data={
                                "call_id": _d.get("call_id", ""),
                                "tool": _d.get("tool", ""),
                                "arg_fragment": _d.get("arg_fragment", ""),
                                "index": _d.get("index", 0),
                                "truncated": _d.get("truncated", False),
                                "iteration": iter_count
                            }
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

                while mt_run._tool_arg_deltas {
                    _d = mt_run._tool_arg_deltas.pop(0);
                    _emitted_deltas = True;
                    yield StreamEvent(
                        event_type="tool_call_delta",
                        data={
                            "call_id": _d.get("call_id", ""),
                            "tool": _d.get("tool", ""),
                            "arg_fragment": _d.get("arg_fragment", ""),
                            "index": _d.get("index", 0),
                            "truncated": _d.get("truncated", False),
                            "iteration": iter_count
                        }
                    );
                }
                resp = _stream_out[0];
            } except litellm.exceptions.ContextWindowExceededError {
                if _emitted_deltas {
                    _emitted_deltas = False;
                    yield StreamEvent(
                        event_type="stream_reset",
                        data={"scope": "thought", "iteration": iter_count}
                    );
                }
                mt_run._tool_arg_deltas = [];
                self._emergency_compact(mt_run, just_compacted, _cp);
                just_compacted = True;
                yield from _compaction_events(mt_run, _compactions_base, iter_count);
                _compactions_base = len(mt_run._compactions);
                resp = self.dispatch_no_streaming(mt_run);
            } except OutputConversionError {
                if _emitted_deltas {
                    _emitted_deltas = False;
                    yield StreamEvent(
                        event_type="stream_reset",
                        data={"scope": "thought", "iteration": iter_count}
                    );
                }
                mt_run._tool_arg_deltas = [];
                recovery_resp = self._attempt_recovery(mt_run);
                if recovery_resp is None {
                    raise;
                }
                yield from self._yield_recovery_result(
                    recovery_resp, iter_count, mt_run, _usage_base
                );
                break;
            }
            _llm_ms = int((_time.time() - _llm_t0) * 1000);

            usage: dict[str, any] = resp.usage or {};
            total_tokens += int(
                usage.get("total_tokens", 0)
                    if isinstance(usage, dict)
                    else getattr(usage, "total_tokens", 0)
            );

            just_compacted = self._maybe_compact(mt_run, usage, just_compacted, _cp);
            yield from _compaction_events(mt_run, _compactions_base, iter_count);

            yield StreamEvent(
                event_type="llm_timing",
                data={"duration_ms": _llm_ms, "iteration": iter_count}
            );
            yield from _usage_step_events(mt_run, _usage_base);
            _usage_base = len(mt_run._usage_history);

            if resp.tool_calls {
                (non_finish_calls, finish_tc, skipped_calls) = _split_at_finish(
                    resp.tool_calls
                );

                if non_finish_calls {
                    max_result_len = int(
                        mt_run.call_params.get("max_tool_result_length")
                            or self.call_params.get("max_tool_result_length")
                            or _call_params_config.get("max_tool_result_length")
                            or 500
                    );

                    batches = (
                        [non_finish_calls]
                            if _should_parallelize(mt_run)
                            else [[tc] for tc in non_finish_calls]
                    );

                    for batch in batches {
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

                        raw_results: list[tuple[ToolCall, Message, float]] = [];
                        for bres in dispatch_batch(batch) {
                            btc: ToolCall = bres[0];
                            result_msg: Message = bres[1];
                            tool_ms: float = bres[2];
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

                        ordered: dict[int, tuple[ToolCall, Message, float]] = {};
                        for r in raw_results {
                            idx = _index_by_identity(batch, r[0]);
                            ordered[idx] = r;
                        }
                        for i in range(len(batch)) {
                            mt_run.add_message(ordered[i][1]);
                        }
                    }
                }

                _answer_skipped(mt_run, skipped_calls);

                if finish_tc {
                    try {
                        finish_msg = finish_tc();
                        final_output = finish_tc.get_output();
                    } except FinishToolError as e {
                        mt_run.add_message(
                            _error_tool_call(finish_tc.call_id, "finish_tool", str(e))()
                        );
                        continue;
                    }
                    mt_run.add_message(finish_msg);

                    mt_run._final_output = final_output;
                    mt_run._has_final_output = True;
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
                    );

                    if mt_run.resp_type is None or mt_run.resp_type is str {
                        yield from _answer_events(
                            mt_run,
                            self._stream_final_answer(
                                mt_run,
                                fallback=str(final_output or ""),
                                retractable=True
                            ),
                            iter_count
                        );
                        yield from _usage_step_events(mt_run, _usage_base);
                    }
                    break;
                }
            } else {
                _raise_if_empty_truncation(
                    resp.finish_reason, resp.output, resp.tool_calls
                );
                recovery_resp = self._attempt_recovery(mt_run);
                if recovery_resp is None {
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
                    recovery_resp, iter_count, mt_run, _usage_base
                );
                break;
            }
        }
    }

    yield StreamEvent(event_type="usage", data=_aggregate_usage(mt_run._usage_history));
}

impl _tool_call_fragments(chunk: object) -> list[dict[str, any]] {
    raw: (list[object] | None) = None;
    try {
        if chunk?.choices and chunk?.choices?[0]?.delta {
            raw = chunk?.choices?[0]?.delta?.tool_calls;
        } elif isinstance(chunk, dict) {
            _choices: any = chunk.get("choices") or [];
            if _choices {
                _tcs = (_choices[0].get("delta") or {}).get("tool_calls");
                raw = _tcs if isinstance(_tcs, list) else None;
            }
        }
    } except Exception {
        return [];
    }
    if not raw {
        return [];
    }
    out: list[dict[str, any]] = [];
    for (pos, tc) in enumerate(raw) {
        try {
            if isinstance(tc, dict) {
                fn: any = tc.get("function") or {};
                idx = tc.get("index");
                out.append(
                    {
                        "index": int(idx) if idx is not None else pos,
                        "id": tc.get("id") or "",
                        "name": (fn.get("name") if isinstance(fn, dict) else "") or "",
                        "fragment": (
                            fn.get("arguments") if isinstance(fn, dict) else ""
                        )
                            or ""
                    }
                );
            } else {
                idx = tc?.index;
                out.append(
                    {
                        "index": int(idx) if idx is not None else pos,
                        "id": tc?.id or "",
                        "name": tc?.function?.name or "",
                        "fragment": tc?.function?.arguments or ""
                    }
                );
            }
        } except Exception {
            continue;
        }
    }
    return out;
}


impl _ToolDeltaCoalescer.observe(frag: dict[str, any]) -> None {
    idx = frag.get("index", 0);
    st = self.state.get(idx);
    if st is None {
        st = {
            "call_id": "",
            "tool": "",
            "buf": "",
            "last": time.time(),
            "sent": 0,
            "announced": False,
            "capped": False
        };
        self.state[idx] = st;
    }
    if frag.get("id") {
        st["call_id"] = str(frag["id"]);
    }
    if frag.get("name") {
        st["tool"] = str(frag["name"]);
    }
    st["buf"] += str(frag.get("fragment") or "");

    if st["tool"] and not st["announced"] {
        st["announced"] = True;
        self._publish(idx, st);
        return;
    }
    if st["sent"] >= self.max_per_call {
        if not st["capped"] {
            st["capped"] = True;
            self.out.append(
                {
                    "call_id": st["call_id"],
                    "tool": st["tool"],
                    "arg_fragment": "",
                    "index": idx,
                    "truncated": True
                }
            );
        }
        return;
    }
    last_val = st["last"];
    last_at = last_val if isinstance(last_val, float) else 0.0;
    if len(str(st["buf"])) >= self.min_chars
        or (time.time() - last_at) >= self.min_interval {
        self._publish(idx, st);
    }
}

impl _ToolDeltaCoalescer._publish(idx: int, st: dict[str, any]) -> None {
    if not st["buf"] and st["sent"] > 0 {
        return;
    }
    self.out.append(
        {
            "call_id": st["call_id"],
            "tool": st["tool"],
            "arg_fragment": st["buf"],
            "index": idx
        }
    );
    st["buf"] = "";
    st["last"] = time.time();
    st["sent"] = st["sent"] + 1;
}

impl _ToolDeltaCoalescer.flush {
    for idx in list(self.state.keys()) {
        st = self.state[idx];
        if st["buf"] and st["sent"] < self.max_per_call {
            self._publish(idx, st);
        }
    }
}


impl _tool_stream_settings(mt_run: MTRuntime) -> dict[str, any] {
    settings = dict(get_byllm_config().get_tool_stream_config());
    per_call = mt_run.call_params.get("stream_tool_args");
    if per_call is True or per_call is False {
        settings["enabled"] = per_call;
    }
    return settings;
}


impl _should_parallelize(mt_run: MTRuntime) -> bool {
    per_call = mt_run.call_params.get("parallelize");
    if per_call is True {
        return True;
    }
    if per_call is False {
        return False;
    }

    return get_byllm_config().get_parallel_config().get("enabled", False);
}


impl _is_transient_error(exc: object) -> bool {
    return isinstance(
        exc,
        (
            litellm.Timeout,
            litellm.APIConnectionError,
            litellm.InternalServerError,
            litellm.ServiceUnavailableError,
            openai.APIConnectionError,
            openai.InternalServerError,
            RateLimitError
        )
    );
}


impl _retry_delay(attempt: int) -> float {
    base = float(_streaming_config.get("retry_backoff", 1.0));
    return min(base * (2 ** max(0, attempt - 1)), 10.0);
}

impl _retry_sleep(attempt: int) {
    time.sleep(_retry_delay(attempt));
}


impl _aretry_sleep(attempt: int) {
    import asyncio;
    await asyncio.sleep(_retry_delay(attempt));
}


impl _is_prompt_caching_eligible(model_name: str) -> bool {
    pc_config = _byllm_config.get_prompt_caching_config();
    if not pc_config.get("enabled", True) {
        return False;
    }
    name = model_name.lower();
    return name.startswith("anthropic/") or name.startswith("claude-");
}


impl _without_cache_control(block: dict[str, any]) -> dict[str, any] {
    out = {
        key: value
        for (key, value) in block.items()
        if key != "cache_control"
    };
    content = out.get("content");
    if isinstance(content, list) {
        out["content"] = [
            _without_cache_control(part) if isinstance(part, dict) else part
            for part in content
        ];
    }
    return out;
}


impl _mark_message_for_caching(msg: dict[str, any]) {
    content = msg.get("content");
    if isinstance(content, str) {
        msg["cache_control"] = dict(_CACHE_CONTROL_EPHEMERAL);
    } elif isinstance(content, list) and content and isinstance(content[-1], dict) {
        content[-1]["cache_control"] = dict(_CACHE_CONTROL_EPHEMERAL);
    }
}


impl _usage_int(usage: any, key: str) -> int {
    if usage is None {
        return 0;
    }
    val = usage.get(key) if isinstance(usage, dict) else getattr(usage, key, None);
    if val is None {
        detail: tuple[str, str] | None = {
            "cache_read_input_tokens": ("prompt_tokens_details", "cached_tokens"),
            "cache_creation_input_tokens": (
                "prompt_tokens_details",
                "cache_creation_tokens"
            ),
            "reasoning_tokens": ("completion_tokens_details", "reasoning_tokens")
        }.get(
            key
        );
        if detail is not None {
            (details_name, detail_key) = detail;
            details = (
                usage.get(details_name)
                    if isinstance(usage, dict)
                    else getattr(usage, details_name, None)
            );
            if details is not None {
                val = (
                    details.get(detail_key)
                        if isinstance(details, dict)
                        else getattr(details, detail_key, None)
                );
            }
        }
    }
    try {
        return int(val or 0);
    } except Exception {
        return 0;
    }
}


impl _apply_prompt_caching(
    messages: list[any], tools: list[dict[str, any]] | None
) -> tuple[list[any], list[dict[str, any]] | None] {
    out_msgs: list[any] = [
        _without_cache_control(msg) if isinstance(msg, dict) else msg
        for msg in messages
    ];
    last_sys: dict[str, any] | None = None;
    last_nonsys: dict[str, any] | None = None;
    for msg in out_msgs {
        if isinstance(msg, dict) {
            if msg.get("role") == "system" {
                last_sys = msg;
            } else {
                last_nonsys = msg;
            }
        }
    }
    for target in (last_sys, last_nonsys) {
        if target is not None {
            _mark_message_for_caching(target);
        }
    }
    if not tools {
        return (out_msgs, tools);
    }
    out_tools = [_without_cache_control(tool) for tool in tools];
    out_tools[-1]["cache_control"] = dict(_CACHE_CONTROL_EPHEMERAL);
    return (out_msgs, out_tools);
}


impl _quiet_lookup(lookup: Callable, fallback: any) -> any {
    try {
        return lookup();
    } except Exception {
        return fallback;
    }
}


impl _litellm_ctx_window(model_name: str) -> int {
    def lookup -> int {
        info = dict(litellm.get_model_info(model_name));
        return int(info.get("max_input_tokens") or info.get("max_tokens") or 0);
    }
    window: int = _quiet_lookup(lookup, 0);
    return window;
}


impl _existing_cost(usage_obj: object) -> object {
    return (usage_obj.get("cost") if isinstance(usage_obj, dict) else usage_obj?.cost);
}


impl _rebuild_stream_chunks(chunks: list[any], logging_obj: object) -> dict[str, any] {
    rebuilt: any = (
        litellm.stream_chunk_builder(chunks, logging_obj=logging_obj)
            if _stream_builder_accepts_logging_obj()
            else litellm.stream_chunk_builder(chunks)
    );
    return rebuilt;
}


impl _attach_call_cost(
    usage_obj: object, model_name: str, response: object = None
) -> None {
    if usage_obj is None
        or not (
            _usage_int(usage_obj, "prompt_tokens")
            or _usage_int(usage_obj, "completion_tokens")
            or _usage_int(usage_obj, "total_tokens")
        ) {
        return;
    }
    if _existing_cost(usage_obj) is not None {
        return;
    }
    def lookup -> object {
        return litellm.completion_cost(
            completion_response=(
                response
                    if response is not None
                    else {"model": model_name, "usage": usage_obj}
            ),
            model=model_name
        );
    }
    cost = _quiet_lookup(lookup, None);
    if cost is None {
        return;
    }
    if isinstance(usage_obj, dict) {
        usage_obj["cost"] = cost;
    } else {
        try {
            setattr(usage_obj, "cost", cost);
        } except Exception {}
    }
}


impl _usage_to_dict(usage_obj: object) -> dict[str, any] {
    if usage_obj is None {
        return {};
    }
    if isinstance(usage_obj, dict) {
        return dict(usage_obj);
    }
    try {
        dump = usage_obj?.model_dump;
        result = dump() if callable(dump) else dict(vars(usage_obj));
        return result if isinstance(result, dict) else {};
    } except Exception as e {
        logger.debug(f"usage serialization failed, recording an empty payload: {e}");
        return {};
    }
}


impl _record_usage(
    mt_run: MTRuntime,
    usage_obj: object,
    model_name: str,
    call_kind: str | None = None,
    finish_reason: str | None = None
) {
    record = _usage_to_dict(usage_obj);
    record["model"] = model_name;
    record["call_kind"] = call_kind or mt_run._call_kind;
    if finish_reason {
        record["finish_reason"] = finish_reason;
    }
    record["cache_read_input_tokens"] = _usage_int(
        usage_obj, "cache_read_input_tokens"
    );
    record["cache_creation_input_tokens"] = _usage_int(
        usage_obj, "cache_creation_input_tokens"
    );
    record["reasoning_tokens"] = _usage_int(usage_obj, "reasoning_tokens");
    mt_run._usage_history.append(record);
}


impl _usage_step_events(
    mt_run: MTRuntime, usage_base: int
) -> Generator[StreamEvent, None, None] {
    if len(mt_run._usage_history) > usage_base {
        yield StreamEvent(
            event_type="usage_step",
            data=_aggregate_usage(mt_run._usage_history[usage_base:])
        );
    }
}


impl _compaction_events(
    mt_run: MTRuntime, compactions_base: int, iteration: int
) -> Generator[StreamEvent, None, None] {
    for record in mt_run._compactions[compactions_base:] {
        yield StreamEvent(
            event_type="compaction", data={** record, "iteration": iteration}
        );
    }
}


impl _usage_history_total_cost(mt_run: MTRuntime) -> float {
    return sum(
        float(record.get("cost", 0.0) or 0.0) for record in mt_run._usage_history
    );
}


impl _copy_for_compaction(model: BaseLLM) -> BaseLLM {
    import copy;
    m = copy.copy(model);
    m.call_params = {"compaction_enabled": False};
    return m;
}


impl _message_role(msg: dict[str, any]) -> str {
    return str(msg.get("role"));
}


impl _compaction_line(msg: any) -> str {
    if not isinstance(msg, dict) {
        return str(msg);
    }
    role = msg.get("role", "");
    content = msg.get("content") or "";
    if isinstance(content, list) {
        content = " ".join(
            p.get("text", "") if isinstance(p, dict) else str(p) for p in content
        );
    }
    if str(role) == "assistant" {
        tool_calls: any = msg.get("tool_calls") or [];
        if tool_calls {
            descs: list[str] = [];
            for tc in tool_calls {
                fn = tc.get("function", {})
                    if isinstance(tc, dict)
                    else (tc?.function or {});
                name = (fn.get("name", "?") if isinstance(fn, dict) else fn?.name)
                    or "?";
                args = (
                    fn.get("arguments", "") if isinstance(fn, dict) else fn?.arguments
                )
                    or "";
                descs.append(f"{name}({args})");
            }
            called = "called: " + "; ".join(descs);
            content = f"{content}\n{called}" if content else called;
        }
    }
    return f"[{role}] {content}";
}


impl _estimate_tokens(messages: list[any]) -> int {
    return sum(len(_compaction_line(msg)) + _reasoning_chars(msg) for msg in messages)
        // _CHARS_PER_TOKEN;
}


impl _reasoning_chars(msg: any) -> int {
    if not isinstance(msg, dict) {
        return 0;
    }
    total = len(str(msg.get("reasoning_content") or ""));
    for block in msg.get("thinking_blocks") or [] {
        if isinstance(block, dict) {
            total += len(str(block.get("thinking") or ""));
        }
    }
    return total;
}


impl _delta_reasoning(chunk: object) -> str {
    if isinstance(chunk, dict) {
        choices: any = chunk.get("choices") or [];
        delta: any = (choices[0].get("delta") or {}) if choices else {};
        return str(delta.get("reasoning_content") or "");
    }
    if chunk?.choices and chunk?.choices?[0]?.delta {
        return str(chunk?.choices?[0]?.delta?.reasoning_content or "");
    }
    return "";
}


impl _reasoning_events(
    mt_run: MTRuntime, iteration: int
) -> Generator[StreamEvent, None, None] {
    while mt_run._reasoning_deltas {
        yield StreamEvent(
            event_type="reasoning",
            data={"content": mt_run._reasoning_deltas.pop(0), "iteration": iteration}
        );
    }
}


impl _answer_events(
    mt_run: MTRuntime, tokens: Generator[str, None, None], iteration: int
) -> Generator[StreamEvent, None, None] {
    for token in tokens {
        if token is _STREAM_RESET {
            yield StreamEvent(event_type="stream_reset", data={"scope": "answer"});
        } else {
            yield from _reasoning_events(mt_run, iteration);
            if token {
                yield StreamEvent(event_type="chunk", data={"content": token});
            }
        }
    }
}


impl _tail_start(messages: list[any], keep_recent: int, budget: int) -> int {
    rounds = [
        i
        for i in range(2, len(messages))
        if _message_role(messages[i]) == "assistant"
    ];
    if not rounds {
        return 2;
    }
    kept = min(keep_recent, len(rounds));
    while kept > 1
        and budget > 0
        and _estimate_tokens(messages[rounds[-kept]:]) > budget {
        kept -= 1;
    }
    return rounds[-kept] if kept > 0 else len(messages);
}


impl _clip_content(msg: dict[str, any], max_chars: int) -> dict[str, any] {
    content = msg.get("content");
    if not isinstance(content, str) or len(content) <= max_chars {
        return msg;
    }
    dropped = len(content) - max_chars;
    clipped = dict(msg);
    clipped["content"] = f"{content[:max_chars]}\n[truncated: {dropped} characters removed]";
    return clipped;
}


impl _clip_tool_results(tail: list[any], budget: int) -> list[any] {
    tool_count = sum(
        1
        for msg in tail
        if _message_role(msg) == "tool"
    );
    if budget <= 0 or not tool_count or _estimate_tokens(tail) <= budget {
        return tail;
    }
    max_chars = budget * _CHARS_PER_TOKEN // tool_count;
    return [
        _clip_content(msg, max_chars) if _message_role(msg) == "tool" else msg
        for msg in tail
    ];
}


impl _default_compact(
    messages: list[any],
    keep_recent: int,
    model: BaseLLM,
    parent_mt_run: MTRuntime | None = None,
    ctx_window: int = 0
) -> list[any] {
    if len(messages) < 4 {
        return messages;
    }

    tail_budget = int(ctx_window * _TAIL_BUDGET_RATIO);
    tail_start = _tail_start(messages, keep_recent, tail_budget);
    kept_tail = _clip_tool_results(messages[tail_start:], tail_budget);
    compact_slice = messages[2:tail_start];
    if _estimate_tokens(compact_slice) <= int(ctx_window * _MIN_SLICE_RATIO) {
        return messages[:tail_start] + kept_tail;
    }

    history_text = "\n".join(_compaction_line(msg) for msg in compact_slice);
    summary_prompt = (
        "Summarise the following agent tool-call history concisely. "
        "Preserve key findings, decisions, and intermediate results that "
        "may be needed to complete the ongoing task. Output plain text only.\n\n"
        + history_text
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
        mtir=None,
        _call_kind="compaction"
    );
    try {
        summary = str(model.invoke(comp_mt_run));
    } finally {
        if parent_mt_run is not None {
            parent_mt_run._usage_history.extend(comp_mt_run._usage_history);
        }
    }
    summary_msg = {
        "role": "user",
        "content": f"[Compacted context summary]\n{summary}"
    };
    return [messages[0], messages[1], summary_msg] + kept_tail;
}


impl _error_tool_call(call_id: str, tool_name: str, reason: str) -> ToolCall {
    name = tool_name or "unknown_tool";
    def _report_error -> str {
        return (
            f"Tool error: {reason}. "
            f"Re-send the {name} call with corrected arguments."
        );
    }
    _report_error.__name__ = name;

    setattr(_report_error, "_is_error_tool", True);
    return ToolCall(call_id=call_id, tool=Tool(func=_report_error), args={});
}

impl _split_at_finish(
    tool_calls: list[ToolCall]
) -> tuple[list[ToolCall], ToolCall | None, list[ToolCall]] {
    before: list[ToolCall] = [];
    for (i, tc) in enumerate(tool_calls) {
        if tc.is_finish_call() {
            return (before, tc, tool_calls[i + 1:]);
        }
        before.append(tc);
    }
    return (before, None, []);
}

impl _answer_skipped(mt_run: MTRuntime, skipped: list[ToolCall]) -> None {
    for tc in skipped {
        mt_run.add_message(
            ToolCallResultMsg(
                content="Not executed: it came after finish_tool in the same response. "
                "Call it again in a later response if it is still needed.",
                tool_call_id=tc.call_id,
                name=tc.tool.get_name()
            )
        );
    }
}

impl _parse_tool_calls(
    mt_run: MTRuntime,
    tool_calls_list: list[any],
    truncated_ids: set | None = None,
    damaged_ids: set | None = None
) -> list[ToolCall] {
    parsed: list[ToolCall] = [];
    for tool_call in tool_calls_list {
        fn = response_field(tool_call, "function");
        call_id = str(response_field(tool_call, "id") or "");
        tool_name = str(response_field(fn, "name") or "") if fn else "";
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
        if damaged_ids and call_id in damaged_ids {
            parsed.append(
                _error_tool_call(
                    call_id,
                    tool_name,
                    "this tool call's arguments arrived malformed and could not be "
                    "parsed, so they were discarded. The arguments you chose were "
                    "not the problem and the payload was not too large: send the "
                    "same call again unchanged"
                )
            );
            continue;
        }
        try {
            raw_args = response_field(fn, "arguments") or "";
            assert isinstance(raw_args, str);
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


impl _sanitize_tool_calls(message: dict[str, any]) -> set[str] {
    damaged: set[str] = set();
    tool_calls: any = (message or {}).get("tool_calls") or [];
    for tc in tool_calls {
        fn = response_field(tc, "function");
        if fn is None {
            continue;
        }
        raw = response_field(fn, "arguments");
        valid = False;
        had_args = isinstance(raw, str) and bool(raw.strip());
        if had_args {
            assert isinstance(raw, str);
            try {
                json.loads(raw);
                valid = True;
            } except Exception {
                valid = False;
            }
        }
        if not valid {
            if had_args {
                damaged.add(str(response_field(tc, "id") or ""));
            }
            if isinstance(fn, dict) {
                fn["arguments"] = "{}";
            } else {
                setattr(fn, "arguments", "{}");
            }
        }
    }
    return damaged;
}


impl _raise_if_empty_truncation(finish_reason: str, content: any, tool_calls: any) {
    if finish_reason == "length"
        and not tool_calls
        and not str(content or "").strip() {
        raise OutputTruncatedError(
            "The model hit max_tokens before it produced any text or tool call "
            "(the budget went to reasoning). Raise max_tokens or lower the "
            "reasoning effort."
        );
    }
}


impl _truncated_call_ids(message: dict[str, any], finish_reason: str) -> set[str] {
    if finish_reason != "length" {
        return set();
    }
    ids: set[str] = set();
    for tc in ((message or {}).get("tool_calls") or []) {
        ids.add(str(response_field(tc, "id") or ""));
    }
    return ids;
}


impl _image_prompt(mt_run: MTRuntime) -> str {
    parts: list[str] = [];

    def keep(text: str) {
        trimmed = text.strip();
        if trimmed {
            parts.append(trimmed);
        }
    }
    for msg in mt_run.get_msg_list() {
        role = msg.get("role") if isinstance(msg, dict) else msg?.role;
        if str(role) not in ("system", "user") {
            continue;
        }
        content = msg.get("content") if isinstance(msg, dict) else msg?.content;
        if isinstance(content, str) {
            keep(content);
            continue;
        }
        for block in content or [] {
            if not isinstance(block, dict) {
                continue;
            }
            if block.get("type") != "text" {
                raise ConfigurationError(
                    "An Image return type is served by an image-generation call, "
                    "which takes text only, so the "
                    f"{block.get('type')} argument of this call cannot be sent. "
                    "byLLM has no image-editing path yet."
                );
            }
            keep(str(block.get("text") or ""));
        }
    }
    return "\n".join(parts);
}


impl _images_from_response(response: dict[str, any]) -> list[Image] {
    images: list[Image] = [];
    for raw in response.get("data") or [] {
        item = raw if isinstance(raw, dict) else response_dict(raw);
        encoded = item.get("b64_json");
        if encoded {
            images.append(Image(url=base64.b64decode(str(encoded))));
            continue;
        }
        url = item.get("url");
        if url {
            images.append(Image(url=str(url)));
            continue;
        }
        raise OutputConversionError(
            f"An image result carried neither b64_json nor url: {sorted(item)}"
        );
    }
    if not images {
        raise OutputConversionError("The model returned no image for this call.");
    }
    return images;
}

impl _close_stream(stream: any) {
    source = stream?.completion_stream or stream;
    close = source?.close;
    if callable(close) {
        try {
            close();
        } except Exception {}
    }
}

impl _aclose_stream(stream: any) {
    import inspect;
    close = stream?.aclose or stream?.close;
    if not callable(close) {
        return;
    }
    try {
        closing = close();
        if inspect.isawaitable(closing) {
            await closing;
        }
    } except Exception {}
}
