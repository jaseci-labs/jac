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
    import from byllm.observability { get_observer, EventType }
    observer = get_observer();
    observer.start_trace();
    invoke_start = time.monotonic();

    max_iters = (
        mt_run.call_params.get("max_react_iterations")
        or self.call_params.get("max_react_iterations")
        or _call_params_config.get("max_react_iterations")
        or 0
    );
    tool_names = [t.get_name() for t in mt_run.tools if not t.is_finish_tool()];
    observer.emit_event(EventType.INVOKE_START, self.model_name,
        caller_name=getattr(mt_run.mtir.caller, "__name__", "?"),
        has_tools=len(mt_run.tools) > 0, tool_names=tool_names,
        is_streaming=mt_run.stream, max_react_iterations=int(max_iters));

    # If streaming without tools, stream immediately.
    # No INVOKE_END here — timing is meaningless before the generator runs.
    # The consumer will see LLM_REQUEST/LLM_RESPONSE from dispatch_streaming.
    if mt_run.stream and len(mt_run.tools) == 0 {
        return self.dispatch_streaming(mt_run);
    }

    iter_count = 0;
    # Invoke the LLM and handle tool calls (ReAct loop).
    while True {
        iter_count += 1;
        iter_start = time.monotonic();
        observer.emit_event(EventType.REACT_ITERATION_START, self.model_name, iteration=iter_count);

        if int(max_iters) > 0 and iter_count > int(max_iters) {
            observer.emit_event(EventType.INVOKE_END, self.model_name,
                total_iterations=iter_count - 1, duration_ms=(time.monotonic() - invoke_start) * 1000,
                finish_reason="max_iterations", has_output=True);
            # If streaming, reuse the existing streaming final-answer path
            if mt_run.stream {
                return self._stream_final_answer(mt_run);
            }
            # Non-streaming: disable tools and ask for final answer once
            final_instruction = Message(
                role=MessageRole.USER,
                content="Based on the tool calls and their results above, provide only your final answer.",
            );
            mt_run.add_message(final_instruction);
            original_tools = mt_run.tools;
            mt_run.tools = [];
            try {
                final_resp = self.dispatch_no_streaming(mt_run);
                return final_resp.output;
            } finally {
                mt_run.tools = original_tools;
            }
        }
        resp = self.dispatch_no_streaming(mt_run);
        if resp.tool_calls {
            observer.emit_event(EventType.REACT_ITERATION_END, self.model_name,
                iteration=iter_count, duration_ms=(time.monotonic() - iter_start) * 1000,
                num_tool_calls=len(resp.tool_calls),
                has_finish_tool=any(tc.is_finish_call() for tc in resp.tool_calls));
            for tool_call in resp.tool_calls {
                if tool_call.is_finish_call() {
                    mt_run.add_message(tool_call());
                    output = tool_call.get_output();
                    observer.emit_event(EventType.FINISH_TOOL_CALLED, self.model_name,
                        call_id=tool_call.call_id, output_type=type(output).__name__,
                        output_preview=str(output)[:200]);
                    observer.emit_event(EventType.INVOKE_END, self.model_name,
                        total_iterations=iter_count, duration_ms=(time.monotonic() - invoke_start) * 1000,
                        finish_reason="finish_tool", has_output=True);
                    if mt_run.stream {
                        return self._stream_final_answer(mt_run);
                    }
                    return output;
                } else {
                    mt_run.add_message(tool_call());
                }
            }
        } else {
            observer.emit_event(EventType.REACT_ITERATION_END, self.model_name,
                iteration=iter_count, duration_ms=(time.monotonic() - iter_start) * 1000,
                num_tool_calls=0, has_finish_tool=False);
            break;
        }
    }
    observer.emit_event(EventType.INVOKE_END, self.model_name,
        total_iterations=iter_count, duration_ms=(time.monotonic() - invoke_start) * 1000,
        finish_reason="no_tool_calls", has_output=resp.output is not None);
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
    params = {
        "model": self.model_name,
        "api_base": (
            self.config.get("base_url")
            or self.config.get("host")
            or self.config.get("api_base")
            or _model_config.get("base_url")
        ),
        "messages": mt_run.get_msg_list(),
        "tools": mt_run.get_tool_list() or None,
        "response_format": mt_run.get_output_schema(),
        "api_key": self.api_key or None,
        "temperature": self.call_params.get("temperature", default_temp),
        "max_tokens": self.call_params.get("max_tokens", default_max_tokens),
    };

    # Forward reasoning/thinking params to LiteLLM when present
    # Anthropic extended thinking: thinking={"type": "enabled", "budget_tokens": N}
    thinking = self.call_params.get("thinking") or mt_run.call_params.get("thinking");
    if thinking {
        params["thinking"] = thinking;
    }
    # OpenAI o-series / DeepSeek / others: reasoning_effort="low"|"medium"|"high"
    reasoning_effort = self.call_params.get("reasoning_effort") or mt_run.call_params.get("reasoning_effort");
    if reasoning_effort {
        params["reasoning_effort"] = reasoning_effort;
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
    import from byllm.observability { get_observer, EventType }
    observer = get_observer();

    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params: {log_params}");

    observer.emit_event(EventType.LLM_REQUEST, self.model_name,
        num_messages=len(params.get("messages", [])),
        has_tools=params.get("tools") is not None,
        temperature=params.get("temperature", 0));

    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    llm_start = time.monotonic();
    try {
        response = self.model_call_no_stream(params);
    } except Exception as e {
        observer.emit_event(EventType.LLM_ERROR, self.model_name,
            error_type=type(e).__name__, error_message=str(e)[:500],
            duration_ms=(time.monotonic() - llm_start) * 1000);
        raise;
    }
    llm_duration_ms = (time.monotonic() - llm_start) * 1000;

    message: LiteLLMMessage = response.get("choices", [])[0].get("message");  # type: ignore
    mt_run.add_message(message);
    output_content: str = message.get("content") or "";  # type: ignore
    self.log_info(f"LLM call completed with response: {output_content}");
    output_value = mt_run.parse_response(output_content);

    # Extract reasoning/thinking content (model-specific)
    reasoning = (message or {}).get("reasoning_content") or "";
    if not reasoning {
        # Anthropic extended thinking: extract from thinking_blocks
        for block in ((message or {}).get("thinking_blocks") or []) {
            if block.get("type") == "thinking" {
                reasoning += block.get("thinking", "");
            }
        }
    }

    tool_calls: list[ToolCall] = [];
    tool_calls_list = (message or {}).get("tool_calls") or [];
    for tool_call in tool_calls_list {
        if tool := mt_run.get_tool(tool_call.function.name) {
            args_json = json.loads(tool_call.function.arguments);
            args = tool.parse_arguments(args_json);
            tool_calls.append(ToolCall(call_id=tool_call.id, tool=tool, args=args));
        } else {
            raise RuntimeError(
                f"Attempted to call tool: '{tool_call.function.name}' which was not present."
            ) ;
        }
    }

    observer.emit_event(EventType.LLM_RESPONSE, self.model_name,
        duration_ms=llm_duration_ms, output_length=len(output_content),
        output_preview=output_content[:500],
        reasoning_preview=reasoning[:500],
        num_tool_calls=len(tool_calls_list),
        tool_call_names=[tc.function.name for tc in tool_calls_list]);

    return CompletionResult(output=output_value, tool_calls=tool_calls,);
}

"""Dispatch the LLM call with streaming.

Makes a streaming API call and yields content chunks as they arrive.
Events fire lazily as the generator is consumed — LLM_REQUEST on first
iteration, LLM_RESPONSE after the last chunk.
"""
impl BaseLLM.dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None] {
    import from byllm.observability { get_observer, EventType }
    observer = get_observer();

    params = self.make_model_params(mt_run);
    log_params = self.format_prompt(params);
    self.log_info(f"Calling LLM: {self.model_name} with params:\n{log_params}");

    observer.emit_event(EventType.LLM_REQUEST, self.model_name,
        num_messages=len(params.get("messages", [])),
        has_tools=params.get("tools") is not None,
        temperature=params.get("temperature", 0), streaming=True);

    self.api_base = params.pop("api_base", DEFAULT_BASE_URL);
    params.pop("api_key", None);
    llm_start = time.monotonic();
    try {
        response = self.model_call_with_stream(params);
        for chunk in response {
            if chunk?.choices and chunk?.choices?[0]?.delta {
                delta = chunk.choices[0].delta;
                yield delta.content or "";
            }
        }
        observer.emit_event(EventType.LLM_RESPONSE, self.model_name,
            duration_ms=(time.monotonic() - llm_start) * 1000, streaming=True);
    } except Exception as e {
        observer.emit_event(EventType.LLM_ERROR, self.model_name,
            error_type=type(e).__name__, error_message=str(e)[:500],
            duration_ms=(time.monotonic() - llm_start) * 1000);
        raise;
    }
}

"""Make a direct model call without streaming.

Subclasses must implement this to define how the actual LLM API is called.
Should return the raw API response object.
"""
impl BaseLLM.model_call_no_stream(params: dict) -> dict {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call without streaming."
    ) ;
}

"""Make a direct model call with streaming.

Subclasses must implement this to define how the actual LLM API is called.
Should return a generator that yields response chunks.
"""
impl BaseLLM.model_call_with_stream(params: dict) -> Generator[str, None, None] {
    raise NotImplementedError(
        "Subclasses must implement this method for LLM call with streaming."
    ) ;
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
    mt_run.add_message(final_instruction);
    # Remove tools and make a streaming call to get the real-time answer
    # We temporarily clear tools so the LLM just responds with text
    original_tools = mt_run.tools;
    mt_run.tools = [];
    try {
        # Make the actual streaming call - this is REAL streaming from the LLM!
        yield from self.dispatch_streaming(mt_run);
    } finally {
        # Restore tools (though we're done at this point)
        mt_run.tools = original_tools;
    }
}
