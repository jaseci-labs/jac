def _mock_jsonable(value: object) -> object {
    import from dataclasses { fields, is_dataclass }
    import from enum { Enum }
    import from jaclang.runtime.archetype { Archetype }
    if value is None or isinstance(value, (bool, int, float, str)) {
        return value;
    }
    if isinstance(value, Enum) {
        return _mock_jsonable(value.value);
    }
    if isinstance(value, dict) {
        return {str(k): _mock_jsonable(v) for (k, v) in value.items()};
    }
    if isinstance(value, (list, tuple, set)) {
        return [_mock_jsonable(v) for v in value];
    }
    if hasattr(value, "model_dump") {
        model: any = value;
        return _mock_jsonable(model.model_dump());
    }
    if isinstance(value, Archetype) {
        return {
            k: _mock_jsonable(v)
            for (k, v) in vars(value).items()
            if not k.startswith("_")
        };
    }
    if is_dataclass(value) and not isinstance(value, type) {
        return {
            f.name: _mock_jsonable(getattr(value, f.name))
            for f in fields(value)
            if not f.name.startswith("_")
        };
    }
    if hasattr(value, "isoformat") {
        stamp: any = value;
        return stamp.isoformat();
    }
    raise TypeError(
        f"MockLLM cannot encode a {type(value).__name__} as model output; "
        "queue MockRawResponse with the JSON a model would send"
    );
}


def _mock_turn(output: object) -> MockRawResponse | MockError {
    counters = ("prompt_tokens", "completion_tokens", "total_tokens");
    usage: dict | None = None;
    if isinstance(output, tuple)
        and len(output) == 2
        and isinstance(output[1], dict)
        and (not output[1] or any(k in output[1] for k in counters)) {
        usage = dict(output[1]);
        output = output[0];
    }
    if isinstance(output, MockError) {
        return output;
    }
    if isinstance(output, MockRawResponse) {
        if usage is None {
            return output;
        }
        return MockRawResponse(
            content=output.content,
            tool_calls=list(output.tool_calls),
            usage=usage,
            finish_reason=output.finish_reason
        );
    }
    if isinstance(output, MockToolCall) {
        return MockRawResponse(tool_calls=[output], usage=usage);
    }
    if isinstance(output, list)
        and output
        and all(isinstance(c, MockToolCall) for c in output) {
        return MockRawResponse(tool_calls=list(output), usage=usage);
    }
    if isinstance(output, str) {
        return MockRawResponse(content=output, usage=usage);
    }
    return MockRawResponse(
        content=json.dumps({"schema_object_wrapper": _mock_jsonable(output)}),
        usage=usage
    );
}


def _mock_tool_calls(turn: MockRawResponse) -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    for (i, tc) in enumerate(turn.tool_calls) {
        name: str = tc.tool
            if isinstance(tc.tool, str)
            else str(getattr(tc.tool, "__name__", type(tc.tool).__name__));
        args: str = tc.args
            if isinstance(tc.args, str)
            else json.dumps(_mock_jsonable(tc.args));
        out.append((tc.call_id or f"call_{i + 1}", name, args));
    }
    return out;
}


def _mock_finish_reason(turn: MockRawResponse) -> str {
    if turn.finish_reason {
        return turn.finish_reason;
    }
    return "tool_calls" if turn.tool_calls else "stop";
}


def _mock_response(turn: MockRawResponse, model: str) -> object {
    tool_calls = [
        {
            "id": call_id,
            "type": "function",
            "function": {"name": name, "arguments": args}
        } for (call_id, name, args) in _mock_tool_calls(turn)
    ];
    payload: dict = {
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": turn.content,
                    "tool_calls": tool_calls or None
                },
                "finish_reason": _mock_finish_reason(turn)
            }
        ]
    };
    if turn.usage {
        payload["usage"] = dict(turn.usage);
    }
    return litellm.ModelResponse(**payload);
}


def _mock_chunk(
    model: str, delta: dict, finish_reason: str | None = None, usage: dict | None = None
) -> object {
    payload: dict = {
        "id": "chunk",
        "object": "chat.completion.chunk",
        "created": 1,
        "model": model,
        "choices": []
            if usage
            else [{"index": 0, "delta": delta, "finish_reason": finish_reason}]
    };
    if usage {
        payload["usage"] = usage;
    }
    return litellm.ModelResponseStream(**payload);
}


def _mock_chunks(turn: MockRawResponse, model: str, size: int) -> list {
    out: list = [];
    first = True;
    text = turn.content;
    for i in range(0, len(text), size) {
        delta: dict = {"content": text[i:i + size]};
        if first {
            delta["role"] = "assistant";
        }
        out.append(_mock_chunk(model, delta));
        first = False;
    }
    for (index, (call_id, name, args)) in enumerate(_mock_tool_calls(turn)) {
        pieces = [args[i:i + size] for i in range(0, len(args), size)] or [""];
        for (n, piece) in enumerate(pieces) {
            frag: dict = {"index": index, "function": {"arguments": piece}};
            if n == 0 {
                frag["id"] = call_id;
                frag["type"] = "function";
                frag["function"]["name"] = name;
            }
            delta = {"tool_calls": [frag]};
            if first {
                delta["role"] = "assistant";
            }
            out.append(_mock_chunk(model, delta));
            first = False;
        }
    }
    out.append(_mock_chunk(model, {}, _mock_finish_reason(turn)));
    if turn.usage {
        out.append(_mock_chunk(model, {}, usage=dict(turn.usage)));
    }
    return out;
}


impl MockLLM.postinit -> None {
    _configure_litellm();
    queued = self.config.get("outputs");
    if self.outputs and queued {
        raise ValueError("MockLLM takes outputs= or config['outputs'], not both");
    }
    if queued is not None {
        self.outputs = queued;
    } elif self.outputs {
        self.config["outputs"] = self.outputs;
    }
    self._queue = self.outputs;
}

impl MockLLM._current_queue -> list {
    configured = self.config.get("outputs");
    if self.outputs is not self._queue {
        queue = self.outputs;
    } elif configured is not None and configured is not self._queue {
        queue = configured;
    } else {
        queue = self.outputs;
    }
    self._queue = queue;
    self.outputs = queue;
    if configured is not None {
        self.config["outputs"] = queue;
    }
    return queue;
}

impl MockLLM._next_reply(params: dict) -> MockRawResponse | MockError {
    self.seen.append(params);
    self.seen_prompts.append(
        "\n".join(
            [
                str(
                    m.get("content", "")
                        if isinstance(m, dict)
                        else getattr(m, "content", m)
                ) for m in params.get("messages") or []
            ]
        )
    );
    if bool(self.config.get("show_params", False)) {
        self.log_info(f"Mock LLM Call Parameters: {params}");
    }
    queue = self._current_queue();
    if not queue {
        raise IndexError(
            f"MockLLM has no queued output left for call {len(self.seen)}"
        );
    }
    return _mock_turn(queue.pop(0));
}

impl MockLLM.model_call_no_stream(params: dict) -> object {
    require_optional("litellm", "llm");
    turn = self._next_reply(params);
    if isinstance(turn, MockError) {
        raise turn.error;
    }
    return _mock_response(turn, params.get("model") or self.model_name);
}

impl MockLLM.model_call_with_stream(params: dict) -> Generator[object, None, None] {
    require_optional("litellm", "llm");
    turn = self._next_reply(params);
    model = params.get("model") or self.model_name;
    if isinstance(turn, MockError) {
        partial = _mock_chunks(
            MockRawResponse(content=turn.content), model, self.chunk_size
        )
            if turn.content
            else [];
        for chunk in partial[:turn.after] {
            yield chunk;
        }
        raise turn.error;
    }
    for chunk in _mock_chunks(turn, model, self.chunk_size) {
        yield chunk;
    }
}

impl MockLLM.sent(key: str) -> list {
    return [p.get(key) for p in self.seen];
}

impl MockLLM.exhausted -> bool {
    return not self._current_queue();
}
