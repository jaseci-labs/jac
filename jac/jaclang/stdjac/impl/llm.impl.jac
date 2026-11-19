impl on_usage(f: Callable[[ByUsage], None]) {
    _usage_hooks.append(f);
}

impl model_name -> str {
    return os.environ.get("JAC_LLM_MODEL", "")
        or setting_of("llm.model", DEFAULT_MODEL);
}

impl usage_of(record: dict[str, any]) -> ByUsage {
    def count(key: str) -> int {
        value = record.get(key);
        return int(value) if isinstance(value, (int, float)) else 0;
    }
    return ByUsage(
        requests=1,
        input_tokens=count("prompt_tokens"),
        output_tokens=count("completion_tokens"),
        cache_read_tokens=count("cache_read_input_tokens"),
        cache_write_tokens=count("cache_creation_input_tokens"),
        model=str(record.get("model", "") or "")
    );
}

impl _report_usage(payload: dict[str, any]) -> None {
    record = payload.get("usage");
    if not isinstance(record, dict) or not record {
        return;
    }
    usage = usage_of(record);
    for f in _usage_hooks {
        f(usage);
    }
}

impl _the_model -> NeoModel {
    name = model_name();
    held = _models.get(name);
    if held is None {
        if not _models {
            register_llm_call_hook(_report_usage);
        }
        held = NeoModel(model_name=name);
        _models[name] = held;
    }
    return held;
}

impl _api_message(m: Message) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    texts = [
        p.text
        for p in m.parts
        if p.kind == PartKind.TEXT
    ];
    calls = [
        p
        for p in m.parts
        if p.kind == PartKind.TOOL_CALL
    ];
    results = [
        p
        for p in m.parts
        if p.kind == PartKind.TOOL_RESULT
    ];
    if texts or calls {
        turn: dict[str, any] = {"role": m.role, "content": "\n".join(texts)};
        if calls {
            turn["tool_calls"] = [
                {
                    "id": p.id,
                    "type": "function",
                    "function": {"name": p.name, "arguments": p.input or "{}"}
                } for p in calls
            ];
        }
        out.append(turn);
    }
    for p in results {
        out.append(
            {"role": "tool", "tool_call_id": p.id, "name": p.name, "content": p.text}
        );
    }
    return out;
}

impl _kept_message(d: dict[str, any]) -> Message {
    role = str(d.get("role", "user") or "user");
    content = d.get("content", "");
    parts: list[Part] = [];
    if role == "tool" {
        return Message(
            role="user",
            parts=[
                Part(
                    kind=PartKind.TOOL_RESULT,
                    id=str(d.get("tool_call_id", "") or ""),
                    name=str(d.get("name", "") or ""),
                    text=_text_of(content)
                )
            ]
        );
    }
    text = _text_of(content);
    if text {
        parts.append(Part(kind=PartKind.TEXT, text=text));
    }
    for tc in (d.get("tool_calls") or []) {
        if not isinstance(tc, dict) {
            continue;
        }
        raw_fn = tc.get("function");
        fn: dict[str, any] = raw_fn if isinstance(raw_fn, dict) else {};
        arguments = fn.get("arguments", "");
        parts.append(
            Part(
                kind=PartKind.TOOL_CALL,
                id=str(tc.get("id", "") or ""),
                name=str(fn.get("name", "") or ""),
                input=arguments if isinstance(arguments, str) else json.dumps(arguments)
            )
        );
    }
    return Message(role=role, parts=parts);
}

impl _text_of(content: any) -> str {
    if isinstance(content, str) {
        return content;
    }
    if isinstance(content, list) {
        pieces: list[str] = [];
        for item in content {
            if isinstance(item, dict) and isinstance(item.get("text"), str) {
                pieces.append(item["text"]);
            } elif isinstance(item, str) {
                pieces.append(item);
            }
        }
        return "\n".join(pieces);
    }
    return "" if content is None else str(content);
}

impl ConversationView.init(self: ConversationView, history: list[Message]) {
    list.__init__(self);
    self.history = history;
    for m in history {
        self.extend(_api_message(m));
    }
}

impl ConversationView.__setitem__(self: ConversationView, key: any, value: any) {
    list.__setitem__(self, key, value);
    if isinstance(key, slice) {
        self.history[:] = [
            _kept_message(d)
            for d in self
            if isinstance(d, dict)
        ];
    }
}

impl _loop_action(action: any) -> any {
    if action == IterationAction.ABORT_WITH_SUMMARY {
        return ByllmAction.ABORT_WITH_SUMMARY;
    }
    return ByllmAction.CONTINUE;
}

impl _guard(f: Callable[[IterationContext], IterationAction]) -> Callable[[any], any] {
    def guard(ctx: any) -> any {
        usage = ByUsage(
            requests=max(int(getattr(ctx, "iteration", 1)) - 1, 0),
            input_tokens=int(getattr(ctx, "total_tokens", 0) or 0)
        );
        return _loop_action(
            f(
                IterationContext(
                    iteration=int(getattr(ctx, "iteration", 0)), usage=usage
                )
            )
        );
    }
    return guard;
}

impl _streams_events(caller: any) -> bool {
    try {
        hint = typing.get_type_hints(caller).get("return");
    } except Exception {
        return False;
    }
    origin = typing.get_origin(hint);
    args = typing.get_args(hint);
    return origin in (AbcIterator, typing.Iterator)
        and bool(args)
        and args[0] is ByEvent;
}

impl _as_text_caller(caller: any) -> any {
    def shim(*args: any, **kwargs: any) -> str {
        return "";
    }
    functools.update_wrapper(shim, caller);
    hints = dict(getattr(caller, "__annotations__", {}) or {});
    hints["return"] = str;
    shim.__annotations__ = hints;
    return shim;
}

impl NeoModel.__call__(**kwargs: object) -> NeoModel {
    call = copy.copy(self);
    call.call_params = kwargs;
    call.plugin_args = [];
    return call;
}

impl NeoModel.invoke(mt_run: any) -> any {
    mt_run = self._prepared(mt_run);
    mtir = mt_run?.mtir;
    if mtir is not None and _streams_events(mtir.caller) {
        return self._events(mtir);
    }
    return super.invoke(mt_run);
}

impl NeoModel.ainvoke(mt_run: any) -> any {
    return await super.ainvoke(self._prepared(mt_run));
}

impl NeoModel._prepared(mt_run: any) -> any {
    mtir = mt_run?.mtir;
    if mtir is None or not self.plugin_args {
        return mt_run;
    }
    if not any(
        [a is given for a in mtir.args.values() for given in self.plugin_args]
    ) {
        return mt_run;
    }
    self._drop_plugin_args(mtir);
    return mtir.runtime;
}

impl NeoModel._drop_plugin_args(mtir: MTIR) -> None {
    if not self.plugin_args {
        return;
    }
    for key in list(mtir.args.keys()) {
        if any([mtir.args[key] is given for given in self.plugin_args]) {
            del mtir.args[key];
        }
    }
}

impl NeoModel._events(mtir: MTIR) -> Iterator[ByEvent] {
    params = dict(mtir.call_params);
    params["stream"] = True;
    params["stream_handler"] = _stream_marker;
    streamed = MTIR(_as_text_caller(mtir.caller), mtir.args, params, mtir.ir_info);
    runtime = streamed.runtime;
    answer: list[str] = [];
    for ev in self._invoke_streaming(runtime) {
        kind = ev.event_type;
        d = ev.data;
        if kind == "chunk" {
            text = str(d.get("content", "") or "");
            answer.append(text);
            yield ByEvent(kind=ByEventKind.TEXT, text=text);
        } elif kind == "stream_reset" and d.get("scope") == "answer" {
            answer = [];
        } elif kind == "tool_call" {
            yield ByEvent(
                kind=ByEventKind.TOOL_CALL,
                tool=str(d.get("tool", "")),
                call_id=str(d.get("call_id", "")),
                args=dict(d.get("args") or {})
            );
        } elif kind == "tool_result" {
            yield ByEvent(
                kind=ByEventKind.TOOL_RESULT,
                tool=str(d.get("tool", "")),
                call_id=str(d.get("call_id", "")),
                result=str(d.get("result", "") or "")
            );
        } elif kind == "usage_step" {
            raw_total = d.get("total");
            total: dict[str, any] = raw_total if isinstance(raw_total, dict) else {};
            usage = usage_of(total);
            usage.requests = int(d.get("requests", 1) or 1);
            yield ByEvent(kind=ByEventKind.USAGE, usage=usage);
        }
    }
    yield ByEvent(kind=ByEventKind.DONE, text="".join(answer));
}

impl _stream_marker(event: any) {}

impl llm(
    max_tokens: int = 4000,
    reasoning_effort: str = "",
    max_output_retries: int = 1,
    timeout: int = 60,
    num_retries: int = 0,
    tools: list[any] = [],
    max_react_iterations: int = 8,
    on_iteration: any = None,
    system_prompt: str = "",
    conversation: list[Message] | None = None,
    parallelize: bool = False,
    select: any = 1,
    intent: str = ""
) -> any {
    params: dict[str, any] = {
        "max_tokens": max_tokens,
        "max_react_iterations": max_react_iterations,
        "max_output_retries": max_output_retries,
        "timeout": timeout,
        "stream_num_retries": num_retries,
        "parallelize": parallelize,
        "select": select,
        "intent": intent
    };
    if tools {
        params["tools"] = list(tools);
    }
    if reasoning_effort {
        params["reasoning_effort"] = reasoning_effort;
    }
    if system_prompt {
        params["system_prompt"] = system_prompt;
    }
    if on_iteration is not None {
        params["on_iteration"] = _guard(on_iteration);
    }
    if conversation is not None {
        params["conversation"] = ConversationView(conversation);
    }
    call = _the_model()(**params);
    if conversation is not None {
        call.plugin_args = [conversation];
    }
    return call;
}
