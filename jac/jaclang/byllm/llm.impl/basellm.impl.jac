def _should_parallelize(mt_run: MTRuntime) -> bool {
    per_call = mt_run.call_params.get("parallelize");
    if per_call is True {
        return True;
    }
    if per_call is False {
        return False;
    }

    return get_byllm_config().get_parallel_config().get("enabled", False);
}


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


def _retry_sleep(attempt: int) {
    base = _streaming_config.get("retry_backoff", 1.0);
    time.sleep(min(base * (2 ** max(0, attempt - 1)), 10.0));
}


async def _aretry_sleep(attempt: int) {
    import asyncio;
    base = _streaming_config.get("retry_backoff", 1.0);
    await asyncio.sleep(min(base * (2 ** max(0, attempt - 1)), 10.0));
}


def _is_prompt_caching_eligible(model_name: str) -> bool {
    pc_config = _byllm_config.get_prompt_caching_config();
    if not pc_config.get("enabled", True) {
        return False;
    }
    name = model_name.lower();
    return name.startswith("anthropic/") or name.startswith("claude-");
}


def _mark_message_for_caching(msg: dict) {
    content = msg.get("content");
    if isinstance(content, str) {
        msg["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    } elif isinstance(content, list) and len(content) > 0 {
        content[-1]["cache_control"] = _CACHE_CONTROL_EPHEMERAL;
    }
}


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


def _litellm_ctx_window(model_name: str) -> int {
    try {
        info = litellm.get_model_info(model_name);
        return int(info.get("max_input_tokens") or info.get("max_tokens") or 0);
    } except Exception {
        return 0;
    }
}


def _copy_for_compaction(model: BaseLLM) -> BaseLLM {
    import copy;
    m = copy.copy(model);
    m.call_params = {"compaction_enabled": False};

    m._usage_history = [];
    return m;
}


def _default_compact(messages: list, keep_recent: int, model: BaseLLM) -> list {
    if len(messages) < 4 {
        return messages;
    }

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

    compact_slice = messages[2:i + 1];
    if not compact_slice {
        return messages;
    }

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


impl BaseLLM._maybe_compact(
    mt_run: MTRuntime, usage: object, just_compacted: bool, cp: dict
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
        self._compact_messages(mt_run, int(cp["keep_recent"]), cp["model"]);
        return True;
    }
    return False;
}


impl BaseLLM._emergency_compact_retry(
    mt_run: MTRuntime, just_compacted: bool, cp: dict
) -> CompletionResult {
    if not bool(cp["enabled"]) {
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
    self._compact_messages(mt_run, int(cp["keep_recent"]), cp["model"]);
    return self.dispatch_no_streaming(mt_run);
}


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


impl BaseLLM.__call__(**kwargs: object) -> BaseLLM {
    self.call_params = kwargs;
    return self;
}

impl BaseLLM.invoke(mt_run: MTRuntime) -> object {
    handler = mt_run.call_params.get("stream_handler");
    if mt_run.stream and handler is not None {
        return self._invoke_with_handler(mt_run, handler);
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
    mt_run: MTRuntime, base_msgs: list, base_scaffolding: list, reason: str, output: str
) -> None {
    mt_run.messages = list(base_msgs);
    mt_run._scaffolding_ids = list(base_scaffolding);
    mt_run._has_final_output = False;
    mt_run._final_output = None;
    mt_run.add_scaffolding_message(self._typed_retry_feedback(mt_run, reason, output));
}


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


impl BaseLLM._typed_retry_exhausted(
    attempts: int, cause: object, raw: str
) -> OutputConversionError {
    err = OutputConversionError(
        f"typed-output generation failed after {attempts} attempt(s) " + f"({attempts - 1} retries); last error: {cause}"
    );
    err.raw_output = raw;
    return err;
}


impl BaseLLM._typed_retry_feedback(
    mt_run: MTRuntime, reason: str, prev_output: str
) -> Message {
    rt = mt_run.resp_type;
    type_name = rt.__name__
        if (rt is not None and hasattr(rt, "__name__"))
        else str(rt);

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
        self._usage_history = [];
        accumulated = "";
        _seen_resets = mt_run._stream_reset_count;
        try {
            for token in self.dispatch_streaming(mt_run) {
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
            if mt_run.stream {
                return self._stream_final_answer(mt_run);
            }
            return self._force_final_answer(mt_run);
        }
        try {
            resp = self.dispatch_no_streaming(mt_run);
        } except litellm.exceptions.ContextWindowExceededError {
            resp = self._emergency_compact_retry(mt_run, just_compacted, _cp);
            just_compacted = True;
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
        usage = resp.usage or {};
        total_tokens += int(
            usage.get("total_tokens", 0)
                if isinstance(usage, dict)
                else getattr(usage, "total_tokens", 0)
        );

        just_compacted = self._maybe_compact(mt_run, usage, just_compacted, _cp);
        if resp.tool_calls {
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

impl BaseLLM.make_model_params(mt_run: MTRuntime) -> dict {
    default_temp = _call_params_config.get("temperature", 0.7);
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

    if "tool_choice" in mt_run.call_params {
        params["tool_choice"] = mt_run.call_params["tool_choice"];
    }

    params = inject_schema_hint(params);

    if not self.supports_native_tools {
        params = inject_tool_hint(params);
    }

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

impl BaseLLM.log_info(message: str) -> None {
    verbose = self.config.get("verbose", _model_config.get("verbose", False));
    if bool(verbose) {
        logger.info(message);
    }
}

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


impl BaseLLM.dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);

    log_params = self.format_prompt(params);
    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    attempt = 0;
    while True {
        try {
            response = self.model_call_no_stream(params);
            break;
        } except Exception as e {
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

            self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");
            raise;
        }
    }

    actual_model = response.get("model", self.model_name);
    self.log_info(f"Calling LLM: {actual_model} with params: {log_params}");

    message: LiteLLMMessage = response.get("choices", [])[0].get("message");

    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content: str = message.get("content") or "";
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

impl BaseLLM._should_retry_stream(
    mt_run: MTRuntime, e: Exception, attempt: int, usage_base: int = -1
) -> bool {
    if not (
        _is_transient_error(e) and attempt < self._resolve_stream_retries(mt_run)
    ) {
        return False;
    }
    if usage_base >= 0 {
        self._usage_history = self._usage_history[:usage_base];
    }
    mt_run._stream_reset_count += 1;
    self.log_info(
        f"Transient stream error ({type(e).__name__}); "
        f"retry {attempt + 1} on {self.model_name}"
    );
    return True;
}

impl BaseLLM.dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None] {
    params = self.make_model_params(mt_run);

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
            if self._should_retry_stream(mt_run, e, attempt, usage_base) {
                attempt += 1;
                _retry_sleep(attempt);
                continue;
            }
            raise;
        }
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
    chunks: list = [];
    content_buf = "";
    no_stream = False;
    finish_reason = "";
    attempt = 0;
    while True {
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
            no_stream = True;
            break;
        } except Exception as e {
            if self._should_retry_stream(mt_run, e, attempt) {
                attempt += 1;
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
    message: LiteLLMMessage = response.get("choices", [])[0].get("message");

    if not self.supports_native_tools {
        message = recover_tool_calls(message, [t.get_name() for t in mt_run.tools]);
    }
    _sanitize_tool_calls(message);
    mt_run.add_message(message);
    output_content: str = message.get("content") or "";
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
            if self._should_retry_stream(mt_run, e, attempt, usage_base) {
                attempt += 1;
                await _aretry_sleep(attempt);
                continue;
            }
            raise;
        }
    }
}

impl BaseLLM.model_call_no_stream(params: dict) -> dict {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call without streaming."
    );
}

impl BaseLLM.model_call_with_stream(params: dict) -> Generator[str, None, None] {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call with streaming."
    );
}

impl BaseLLM.model_call_no_stream_async(params: dict) -> dict {
    import asyncio;
    return await asyncio.to_thread(self.model_call_no_stream, params);
}

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


impl BaseLLM._stream_final_answer(mt_run: MTRuntime) -> Generator[str, None, None] {
    final_instruction = Message(
        role=MessageRole.USER,
        content="Based on the tool calls and their results above, provide your final answer. "
        "Be comprehensive and synthesize all the information gathered.",
    );
    mt_run.add_scaffolding_message(final_instruction);

    original_tools = mt_run.tools;
    finish_tool_obj = mt_run.get_tool("finish_tool");
    mt_run.tools = [finish_tool_obj] if finish_tool_obj else [];

    original_tool_choice = mt_run.call_params.pop("tool_choice", None);
    mt_run.call_params["tool_choice"] = "none";
    accumulated: str = "";
    try {
        for token in self.dispatch_streaming(mt_run) {
            accumulated += token;
            yield token;
        }
    } finally {
        mt_run.tools = original_tools;
        mt_run.call_params.pop("tool_choice", None);
        if original_tool_choice is not None {
            mt_run.call_params["tool_choice"] = original_tool_choice;
        }

        if accumulated {
            mt_run.add_message(
                Message(role=MessageRole.ASSISTANT, content=accumulated)
            );
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
    original_tools = mt_run.tools;
    mt_run.tools = [finish_tool_obj];
    try {
        return self.dispatch_no_streaming(mt_run);
    } finally {
        mt_run.tools = original_tools;
    }
}

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

impl BaseLLM._invoke_streaming(
    mt_run: MTRuntime
) -> Generator[StreamEvent, None, None] {
    self._usage_history = [];

    if len(mt_run.tools) == 0 {
        _seen_resets = mt_run._stream_reset_count;
        for token in self.dispatch_streaming(mt_run) {
            if mt_run._stream_reset_count != _seen_resets {
                _seen_resets = mt_run._stream_reset_count;
                yield StreamEvent(event_type="stream_reset", data={"scope": "answer"});
            }
            if token {
                yield StreamEvent(event_type="chunk", data={"content": token});
            }
        }
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
                _stream_out: list[CompletionResult] = [];
                _seen_resets = mt_run._stream_reset_count;
                for _tok in self.dispatch_streaming_with_tools(mt_run, _stream_out) {
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
                resp = self._emergency_compact_retry(mt_run, just_compacted, _cp);
                just_compacted = True;
            } except OutputConversionError {
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

            just_compacted = self._maybe_compact(mt_run, usage, just_compacted, _cp);

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

            if resp.tool_calls {
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

                    mt_run._final_output = finish_tc.get_output();
                    mt_run._has_final_output = True;
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
                    );

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
                    recovery_resp, iter_count, mt_run
                );
                break;
            }
        }
    }

    if self._usage_history {
        totals: dict = {};
        per_call_dicts: list = [];
        for u in self._usage_history {
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

    mt_run.write_back_conversation();
}
