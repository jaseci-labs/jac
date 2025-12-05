impl MockLLM.init(model_name: str, **kwargs: object) -> None {
    logger.remove();  # remove default stderr sink
    logger.add(sys.stdout);
    super.init(model_name, **kwargs);
}

impl MockLLM.dispatch_no_streaming(mtir: MTIR) -> CompletionResult {
    params = self.make_model_params(mtir);
    output = self.config["outputs"].pop(0);  # type: ignore
    if isinstance(output, MockToolCall) {
        self.log_info(
            f"Mock LLM call completed with tool call:\n{output.to_tool_call()}"
        );
        return CompletionResult(output=None, tool_calls=[output.to_tool_call()],);
    }
    self.log_info(
        f"Mock LLM call completed with response:\n{output} with params:\n{params}"
    );
    return CompletionResult(output=output, tool_calls=[],);
}

impl MockLLM.dispatch_streaming(mtir: MTIR) -> Generator[str, None, None] {
    output = self.config["outputs"].pop(0);  # type: ignore
    if mtir.stream {
        while output {
            chunk_len = random.randint(3, 10);
            yield output[:chunk_len];  # Simulate token chunk
            time.sleep(random.uniform(0.01, 0.05));  # Simulate network delay
            output = output[chunk_len:];
        }
    }
}
