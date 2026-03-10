"""Post-initialization hook for MockLLM.

Configures logging to stdout.
"""
impl MockLLM.postinit -> None {
    logger.remove();  # remove default stderr sink
    logger.add(sys.stdout);
}

"""Dispatch the mock LLM call without streaming.

Pops the next output from the configured 'outputs' list and returns it.
Supports both regular outputs and MockToolCall objects.
"""
impl MockLLM.dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);
    message = "{'role': 'assistant', 'content': {'text': 'Mock response'}}";
    mt_run.add_message(message);
    output = self.config["outputs"].pop(0);  # type: ignore
    if isinstance(output, MockToolCall) {
        self.log_info(
            f"Mock LLM call completed with tool call:\n{output.to_tool_call()}"
        );
        return CompletionResult(output=None, tool_calls=[output.to_tool_call()],);
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
    return CompletionResult(output=output, tool_calls=[],);
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
}
