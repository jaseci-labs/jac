def _mock_jsonable(value: object) -> object {
    import from jaclang.runtime.object_interop { fields, is_record }
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
    if is_record(value) and not isinstance(value, type) {
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


def _mock_takes_string(response_format: object) -> bool {
    if not isinstance(response_format, dict) {
        return False;
    }
    spec = response_format.get("json_schema");
    schema = spec.get("schema") if isinstance(spec, dict) else None;
    props = schema.get("properties") if isinstance(schema, dict) else None;
    answer = props.get("schema_object_wrapper") if isinstance(props, dict) else None;
    if not isinstance(answer, dict) {
        return False;
    }
    options = answer.get("anyOf");
    choices: list[any] = options if isinstance(options, list) else [answer];
    return any(isinstance(c, dict) and c.get("type") == "string" for c in choices);
}


def _mock_turn(
    output: object, text_is_value: bool = False
) -> MockRawResponse | MockError {
    counters = ("prompt_tokens", "completion_tokens", "total_tokens");
    usage: dict[str, any] | None = None;
    if isinstance(output, tuple)
        and len(output) == 2
        and isinstance(output[1], dict)
        and (not output[1] or any(k in output[1] for k in counters)) {
        usage = dict(output[1]);
        output = output[0];
    }
    if isinstance(output, MockError) {
        if output.reply is None {
            return output;
        }
        if output.content or output.after {
            raise ValueError(
                "MockError takes content= with after=, or reply=, not both"
            );
        }
        reply = _mock_turn(output.reply, text_is_value);
        if not isinstance(reply, MockRawResponse) {
            raise ValueError("MockError(reply=...) cannot be another MockError");
        }
        return MockError(error=output.error, reply=reply);
    }
    if isinstance(output, MockRawResponse) {
        if usage is None {
            return output;
        }
        return MockRawResponse(
            content=output.content,
            tool_calls=list(output.tool_calls),
            usage=usage,
            finish_reason=output.finish_reason,
            model=output.model,
            unnamed_fragments=output.unnamed_fragments
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
        content = json.dumps({"schema_object_wrapper": output})
            if text_is_value
            else output;
        return MockRawResponse(content=content, usage=usage);
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
    payload: dict[str, any] = {
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
    model: str,
    delta: dict[str, any],
    finish_reason: str | None = None,
    usage: dict[str, any] | None = None
) -> object {
    payload: dict[str, any] = {
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


obj _MockStream {
    has chunks: Iterator[object],
        logging_obj: object;

    def __iter__ -> _MockStream {
        return self;
    }

    def __next__ -> object {
        return next(self.chunks);
    }
}


def _mock_chunks(turn: MockRawResponse, model: str, size: int) -> list[object] {
    out: list[object] = [];
    first = True;
    text = turn.content;
    for i in range(0, len(text), size) {
        delta: dict[str, any] = {"content": text[i:i + size]};
        if first {
            delta["role"] = "assistant";
        }
        out.append(_mock_chunk(model, delta));
        first = False;
    }
    for (index, (call_id, name, args)) in enumerate(_mock_tool_calls(turn)) {
        pieces = [args[i:i + size] for i in range(0, len(args), size)] or [""];
        for (n, piece) in enumerate(pieces) {
            frag: dict[str, any] = {"index": index, "function": {"arguments": piece}};
            if n == 0 {
                frag["type"] = "function";
                if not turn.unnamed_fragments {
                    frag["id"] = call_id;
                    frag["function"]["name"] = name;
                }
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

impl MockLLM._current_queue -> list[any] {
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

impl MockLLM._next_reply(params: dict[str, any]) -> MockRawResponse | MockError {
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
    return _mock_turn(queue.pop(0), _mock_takes_string(params.get("response_format")));
}

def _mock_image_response(output: object, model: str) -> dict[str, any] {
    if isinstance(output, MockError) {
        raise output.error;
    }
    data: list[dict[str, any]] = [];
    items: list[any] = output if isinstance(output, list) else [output];
    for item in items {
        source = item.url if isinstance(item, Image) else item;
        if isinstance(source, (bytes, bytearray, memoryview)) {
            data.append({"b64_json": base64.b64encode(bytes(source)).decode("utf-8")});
        } elif isinstance(source, str) {
            data.append({"url": source});
        } else {
            raise TypeError(
                f"MockLLM cannot serve a {type(item).__name__} as a generated "
                "image; queue image bytes, a url string, or an Image"
            );
        }
    }
    return {"model": model, "data": data};
}


impl MockLLM.model_call_image(params: dict[str, any]) -> dict[str, any] {
    self.seen.append(params);
    self.seen_prompts.append(str(params.get("prompt") or ""));
    queue = self._current_queue();
    if not queue {
        raise IndexError(
            f"MockLLM has no queued output left for call {len(self.seen)}"
        );
    }
    return _mock_image_response(queue.pop(0), params.get("model") or self.model_name);
}

impl MockLLM.model_call_no_stream(params: dict[str, any]) -> object {
    require_optional("litellm", "llm");
    turn = self._next_reply(params);
    if isinstance(turn, MockError) {
        raise turn.error;
    }
    return _mock_response(turn, turn.model or params.get("model") or self.model_name);
}

impl MockLLM.model_call_with_stream(params: dict[str, any]) -> Iterable[object] {
    require_optional("litellm", "llm");
    stream = self._stream_reply(params);
    if self.logging_obj is not None {
        return _MockStream(chunks=stream, logging_obj=self.logging_obj);
    }
    return stream;
}

impl MockLLM._stream_reply(params: dict[str, any]) -> Generator[object, None, None] {
    turn = self._next_reply(params);
    model = params.get("model") or self.model_name;
    if isinstance(turn, MockError) {
        partial: list[object] = [];
        if isinstance(turn.reply, MockRawResponse) {
            partial = _mock_chunks(
                turn.reply, turn.reply.model or model, self.chunk_size
            );
        } elif turn.content {
            partial = _mock_chunks(
                MockRawResponse(content=turn.content), model, self.chunk_size
            )[:turn.after];
        }
        for chunk in partial {
            yield chunk;
        }
        raise turn.error;
    }
    for chunk in _mock_chunks(turn, turn.model or model, self.chunk_size) {
        yield chunk;
    }
}

impl MockLLM.sent(key: str) -> list[any] {
    return [p.get(key) for p in self.seen];
}

impl MockLLM.exhausted -> bool {
    return not self._current_queue();
}
