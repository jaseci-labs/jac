impl MockLLM.postinit -> None {
    import from jaclang.byllm._optdeps.loguru { HAS_LOGURU }
    if HAS_LOGURU {
        logger.remove();
        logger.add(sys.stdout);
    }
}

impl MockLLM.dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    params = self.make_model_params(mt_run);

    self.seen_prompts.append(
        "\n".join([str(getattr(m, "content", m)) for m in mt_run.messages])
    );
    output = self.config["outputs"].pop(0);

    if isinstance(output, MockError) {
        raise output.error;
    }
    message = "{'role': 'assistant', 'content': {'text': 'Mock response'}}";
    mt_run.add_message(message);

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

    if isinstance(output, MockRawResponse) {
        return CompletionResult(
            output=mt_run.parse_response(output.content), tool_calls=[], usage=usage
        );
    }

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

impl MockLLM.adispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
    return self.dispatch_no_streaming(mt_run);
}

impl MockLLM.dispatch_streaming(mt_run: MTRuntime) -> Generator[str, None, None] {
    output = self.config["outputs"].pop(0);
    if mt_run.stream {
        while output {
            chunk_len = random.randint(3, 10);
            yield output[:chunk_len];
            time.sleep(random.uniform(0.01, 0.05));
            output = output[chunk_len:];
        }
    }

    self._usage_history.append({});
}
