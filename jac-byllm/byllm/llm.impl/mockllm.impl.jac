"""Post-initialization hook for MockLLM.

Configures logging to stdout.
"""
impl MockLLM.postinit -> None {
    logger.remove();  # remove default stderr sink
    logger.add(sys.stdout);
}

"""Dispatch the mock LLM call without streaming.

Pops the next output from the configured 'outputs' list. Each entry may be a
plain MockToolCall/string or a (MockToolCall, usage_dict) tuple to inject
token-usage metadata for compaction threshold tests. The tuple form is only
recognised when the first element is a MockToolCall and the second is a dict
with only known usage keys - this avoids colliding with real tuple return types.
"""
impl MockLLM.dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);
    message = "{'role': 'assistant', 'content': {'text': 'Mock response'}}";
    mt_run.add_message(message);
    output = self.config["outputs"].pop(0);  # type: ignore
    # Unpack (payload, usage) tuple when tests need to inject usage metadata.
    # Both conditions must hold to avoid colliding with real tuple return types:
    #   1. first element is a MockToolCall or list[MockToolCall] (never a real LLM output type)
    #   2. second element is a dict with only known usage keys (or empty)
    _usage_keys = ["prompt_tokens", "completion_tokens", "total_tokens"];
    usage: dict[str, object] = {};
    if isinstance(output, tuple) and len(output) == 2 {
        first = output[0];
        second = output[1];
        first_is_tool = (
            isinstance(first, MockToolCall)
            or (
                isinstance(first, list)
                and len(first) > 0
                and isinstance(first[0], MockToolCall)
            )
        );
        second_is_usage = isinstance(second, dict)
        and all(k in _usage_keys for k in second.keys());
        if first_is_tool and second_is_usage {
            output = first;
            usage = second;
        }
    }
    # Support batch tool calls: list[MockToolCall] -> multiple ToolCalls in one response.
    if isinstance(output, list)
    and len(output) > 0
    and isinstance(output[0], MockToolCall) {
        tool_calls = [o.to_tool_call() for o in output];
        self.log_info(
            f"Mock LLM call completed with {len(tool_calls)} batch tool calls"
        );
        return CompletionResult(output=None, tool_calls=tool_calls, usage=usage);
    }
    if isinstance(output, MockToolCall) {
        self.log_info(
            f"Mock LLM call completed with tool call:\n{output.to_tool_call()}"
        );
        return CompletionResult(
            output=None, tool_calls=[output.to_tool_call()], usage=usage
        );
    }
    log_params = self.format_prompt(params);
    params.pop("api_key", None);
    if bool(self.config.get("show_params", False)) {
        self.log_info(f"Mock LLM Call Parameters: {params}");
    } else {
        self.log_info(
            f"Mock LLM call completed with response: {output} with params: {log_params}"
        );
    }
    return CompletionResult(output=output, tool_calls=[], usage=usage);
}

"""Dispatch the mock LLM call with streaming.

Simulates streaming by yielding random-sized chunks with artificial delays.
"""
impl MockLLM.dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None] {
    output = self.config["outputs"].pop(0);  # type: ignore
    if mt_run.stream {
        while output {
            chunk_len = random.randint(3, 10);
            yield output[:chunk_len];  # Simulate token chunk
            time.sleep(random.uniform(0.01, 0.05));  # Simulate network delay
            output = output[chunk_len:];
        }
    }
    # Record a usage entry so the end-of-stream usage event fires.
    self._usage_history.append({});
}
