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
    try {
        return self._invoke_react_loop(mt_run);
    } finally {
        mt_run.write_back_conversation();
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
    iter_count = 0;
    last_tool = "";
    last_result = "";
    total_tokens = 0;
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
        } except OutputConversionError {
            # gpt-4o returned plain text that can't be parsed — attempt recovery.
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
        if resp.tool_calls {
            # Split at first finish_tool — anything after it is discarded.
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

            # Always route through dispatch_batch — one code path for both modes.
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
            # the model skipped the expected workflow — attempt recovery.
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
                    tag = " [SEQUENTIAL: has side-effects — must be called alone, never batch with other tools]";
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
                    "\n\nKEY TEST: For each tool ask — 'Can I fill in ALL of this tool's arguments RIGHT NOW"
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
    log = f"""
    {MAGENTA}[SYSTEM]{RESET}
    {log_params["messages"][0]["content"]}
    {MAGENTA}[USER]{RESET}
    {log_params["messages"][1]["content"][0]['text']
        if isinstance(log_params["messages"][1]["content"], list)
        else log_params["messages"][1]["content"]}
    {MAGENTA}[TOOL]{RESET}
    {log_params["messages"][3]["content"]
        if len(log_params["messages"]) > 3
        else "No tools provided."}
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
    try {
        response = self.model_call_no_stream(params);
    } except Exception {
        # Log with model_name on failure so verbose output is still captured
        self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");
        raise;
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
    mt_run.add_message(message);
    output_content: str = message.get("content") or "";  # type: ignore
    self.log_info(f"LLM call completed with response: {output_content}");
    tool_calls: list[ToolCall] = [];
    tool_calls_list = (message or {}).get("tool_calls") or [];
    for tool_call in tool_calls_list {
        if tool := mt_run.get_tool(tool_call.function.name) {
            args_json = json.loads(tool_call.function.arguments);
            args = tool.parse_arguments(args_json);
            tool_calls.append(ToolCall(call_id=tool_call.id, tool=tool, args=args));
        } else {
            raise UnknownToolError(
                f"Attempted to call tool: '{tool_call.function.name}' which was not present."
            );
        }
    }
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
    # Force text generation — tool_choice="none" tells the LLM
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
        for token in self.dispatch_streaming(mt_run) {
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
        iter_count = 0;
        last_tool = "";
        last_result = "";
        total_tokens = 0;
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
                resp = self.dispatch_no_streaming(mt_run);
            } except OutputConversionError {
                # gpt-4o returned plain text that can't be parsed — attempt recovery.
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

            # Metrics: emit LLM call duration for this iteration
            yield StreamEvent(
                event_type="llm_timing",
                data={"duration_ms": _llm_ms, "iteration": iter_count}
            );

            # Yield thought if the LLM produced reasoning text
            if resp.output and str(resp.output).strip() {
                yield StreamEvent(
                    event_type="thought",
                    data={"content": str(resp.output).strip(), "iteration": iter_count}
                );
            }

            if resp.tool_calls {
                # Split at first finish_tool — normalizes history for both modes.
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
                            truncated_result = result_msg.content[:max_result_len];
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
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
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
            } else {
                # No tool calls — check if recovery is needed.
                # (OutputConversionError catch above handles real Model;
                # this branch handles MockLLM which bypasses parse_response.)
                recovery_resp = self._attempt_recovery(mt_run);
                if recovery_resp is None {
                    # Plain string return or no finish_tool — yield and exit
                    yield StreamEvent(
                        event_type="steps_done", data={"iterations": iter_count}
                    );
                    if resp.output {
                        yield StreamEvent(
                            event_type="chunk", data={"content": str(resp.output)}
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
