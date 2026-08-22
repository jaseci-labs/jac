"""Tool-argument streaming: `tool_call_delta` (jaseci-labs/jac#7997).

byllm used to read only `delta.content`, so a caller learned a tool was being
invoked only once every argument had been generated. The feature is
display-only and opt-in; each test pins one invariant."""

import litellm;
import types;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole, Tool }
import from jaclang.byllm.exceptions { FinishToolError, OutputConversionError }

glob RETRY: str = "__retry__",
     SHIPPED_DEFAULTS: dict = {
         "enabled": False,
         "min_chars": 48,
         "min_interval": 0.15,
         "max_per_call": 200
     };


def write_file(path: str, content: str) -> str {
    return f"wrote {len(content)} chars to {path}";
}


def read_file(path: str) -> str {
    return f"read {path}";
}


"""One chunk: prose when `content` is set, else an argument fragment. Only a
call's FIRST fragment carries `id` and `name`, as litellm delivers them."""
def _chunk(
    content: str = "", frag: str = "", call_id: str = "", name: str = "", index: int = 0
) -> any {
    calls = None;
    if not content {
        fn = types.SimpleNamespace(name=(name or None), arguments=frag);
        calls = [
            types.SimpleNamespace(
                index=index, id=(call_id or None), type="function", function=fn
            )
        ];
    }
    return types.SimpleNamespace(
        usage=None,
        choices=[
            types.SimpleNamespace(
                delta=types.SimpleNamespace(
                    content=(content or None), tool_calls=calls
                ),
                finish_reason=None
            )
        ]
    );
}


"""Split `args` into `size`-char fragments and wrap them as one call's chunks."""
def _frags(args: str, tool: str, call_id: str, size: int = 12, index: int = 0) -> list {
    out: list = [];
    for i in range(0, len(args), size) {
        first = i == 0;
        out.append(
            _chunk(
                frag=args[i:i + size],
                call_id=(call_id if first else ""),
                name=(tool if first else ""),
                index=index
            )
        );
    }
    return out;
}


"""What `stream_chunk_builder` returns for `calls`, each (id, name, args)."""
def _rebuilt(calls: list) -> dict {
    tcs = [
        types.SimpleNamespace(
            id=c[0],
            type="function",
            function=types.SimpleNamespace(name=c[1], arguments=c[2])
        ) for c in calls
    ];
    return {
        "choices": [
            {
                "message": {"role": "assistant", "content": "", "tool_calls": tcs},
                "finish_reason": "tool_calls"
            }
        ],
        "model": "gpt-4o",
        "usage": {}
    };
}


def _plain(text: str) -> dict {
    return {
        "choices": [
            {
                "message": {"role": "assistant", "content": text, "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "model": "gpt-4o",
        "usage": {}
    };
}


"""Drive `_invoke_streaming` over scripted turns. `turns` holds one entry per
LLM round: chunks, or RETRY to drop the stream. `rebuilts` is parallel to it.
`enabled` False means the caller never opts in, i.e. the shipped default.
`bounds` stands in for `[byllm.tool_stream]`, so a run never depends on the
jac.toml of whoever is running the suite."""
def _run(
    turns: list,
    rebuilts: list,
    tools: list,
    enabled: bool = True,
    bounds: dict | None = None,
    tolerate_errors: bool = False,
    probe: dict | None = None
) -> list {
    llm = Model(model_name="gpt-4o");
    wrapped = [Tool(func=t) for t in tools];
    wrapped.append(Tool.make_finish_tool(str));
    mt = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=str,
        stream=True,
        tools=wrapped,
        call_params=({"stream_tool_args": True} if enabled else {}),
        mtir=None
    );
    if probe is not None {
        probe["mt"] = mt;
    }
    at = [0];

    def _stream(params: dict) -> any {
        i = at[0];
        at[0] += 1;
        if i >= len(turns) {
            return [_chunk(content="all done")];
        }
        if turns[i] == RETRY {
            raise litellm.APIConnectionError(
                message="dropped", llm_provider="openai", model="gpt-4o"
            );
        }
        # A callable turn is a generator factory, for streams that raise midway.
        if callable(turns[i]) {
            return turns[i]();
        }
        return turns[i];
    }

    def _no_stream(mt_arg: any) -> any {
        return _byllm_llm_mod.CompletionResult(output="done", tool_calls=[], usage={});
    }

    # Only the OutputConversionError handler calls this; a real one would need a
    # non-str resp_type, which these turns do not use.
    def _recovered(mt_arg: any) -> any {
        return _byllm_llm_mod.CompletionResult(
            output="recovered", tool_calls=[], usage={}
        );
    }

    def _rebuild(seen: list) -> dict {
        i = at[0] - 1;
        if i < len(rebuilts) and rebuilts[i] is not None {
            return rebuilts[i];
        }
        return _plain("all done");
    }

    resolved = dict(bounds) if bounds else dict(SHIPPED_DEFAULTS);
    cfg = _byllm_llm_mod.get_byllm_config();

    def _tool_stream_cfg -> dict {
        return dict(resolved);
    }

    events: list = [];
    with mock.patch.object(llm, "model_call_with_stream", _stream), mock.patch.object(
        _byllm_llm_mod.litellm, "stream_chunk_builder", _rebuild
    ), mock.patch.object(cfg, "get_tool_stream_config", _tool_stream_cfg), mock.patch.object(
        llm, "dispatch_no_streaming", _no_stream
    ), mock.patch.object(llm, "_attempt_recovery", _recovered) {
        try {
            for ev in llm._invoke_streaming(mt) {
                events.append(ev);
            }
        } except Exception as err {
            # Only compaction-style scenarios opt in; anything else must surface.
            if not tolerate_errors {
                raise err;
            }
        }
    }
    return events;
}


def _kinds(events: list) -> list {
    return [e.event_type for e in events];
}


def _of(events: list, kind: str) -> list {
    return [
        e
        for e in events
        if e.event_type == kind
    ];
}


glob BODY: str = '{"path": "main.jac", "content": "' + ("x" * 400) + '"}';


test "disabled is the shipped default and changes nothing" {
    # Deliberately isolated: this must keep passing even if every other part of
    # the feature is broken, because it is the upgrade-safety guarantee.
    events = _run(
        [_frags(BODY, "write_file", "c1")],
        [_rebuilt([("c1", "write_file", BODY)])],
        [write_file],
        enabled=False
    );

    assert len(_of(events, "tool_call_delta")) == 0 , f"deltas leaked while disabled: {_kinds(
        events
    )}";
    calls = _of(events, "tool_call");
    assert len(calls) >= 1 , f"the tool call vanished: {_kinds(events)}";
    assert calls[0].data.get("args", {}).get("path") == "main.jac" , calls[0].data;
    assert len(_of(events, "tool_result")) >= 1 , f"the tool never ran: {_kinds(
        events
    )}";
}


test "the gate opens per call or from jac.toml" {
    def gate(enabled: bool, bounds: dict | None) -> list {
        return _of(
            _run(
                [_frags(BODY, "write_file", "c1")],
                [_rebuilt([("c1", "write_file", BODY)])],
                [write_file],
                enabled=enabled,
                bounds=bounds
            ),
            "tool_call_delta"
        );
    }

    assert len(gate(True, None)) > 0 , "the per-call override did not enable streaming";
    assert len(
        gate(
            False,
            {
                "enabled": True,
                "min_chars": 48,
                "min_interval": 0.15,
                "max_per_call": 200
            }
        )
    )
        > 0 , "[byllm.tool_stream] enabled did not enable streaming";
}


test "deltas precede the call, name the tool, and leave execution untouched" {
    body = '{"path": "main.jac", "content": "hello world"}';
    events = _run(
        [[_chunk(content="Writing it. ")] + _frags(body, "write_file", "c1", size=5)],
        [_rebuilt([("c1", "write_file", body)])],
        [write_file]
    );
    kinds = _kinds(events);

    deltas = _of(events, "tool_call_delta");
    assert len(deltas) > 0 , f"no deltas emitted: {kinds}";
    assert kinds.index("tool_call_delta") < kinds.index("tool_call") , f"deltas must precede the call: {kinds}";
    assert deltas[0].data.get("tool") == "write_file" , f"the first delta must name the tool: {deltas[
        0
    ].data}";

    # Display is advisory: what ran is still whatever stream_chunk_builder rebuilt.
    calls = _of(events, "tool_call");
    assert calls[0].data.get("args", {}).get("content") == "hello world" , calls[
        0
    ].data;
    results = _of(events, "tool_result");
    assert "wrote 11 chars to main.jac" in str(results[0].data.get("result", "")) , results[
        0
    ].data;

    # A parallel batch must keep each call's fragments under its own id.

    a = '{"path": "a.jac", "content": "aaa"}';
    b = '{"path": "b.jac"}';
    events = _run(
        [
            _frags(a, "write_file", "c1", size=10, index=0)
                + _frags(b, "read_file", "c2", size=8, index=1)
        ],
        [_rebuilt([("c1", "write_file", a), ("c2", "read_file", b)])],
        [write_file, read_file]
    );

    joined: dict = {};
    for d in _of(events, "tool_call_delta") {
        cid = d.data.get("call_id", "");
        joined[cid] = joined.get(cid, "") + str(d.data.get("arg_fragment", ""));
    }
    assert "c1" in joined and "c2" in joined , f"both calls should stream under their own id: {list(
        joined.keys()
    )}";
    assert "a.jac" in joined["c1"] and "b.jac" in joined["c2"] , joined;
    assert "b.jac" not in joined["c1"] , f"fragments crossed calls: {joined}";
}


test "coalescing is bounded, and the bounds come from config" {
    def under(min_chars: int, max_per_call: int, size: int) -> list {
        return _of(
            _run(
                [_frags(BODY, "write_file", "c1", size=size)],
                [_rebuilt([("c1", "write_file", BODY)])],
                [write_file],
                enabled=False,
                bounds={
                    "enabled": True,
                    "min_chars": min_chars,
                    "min_interval": 30.0,
                    "max_per_call": max_per_call
                }
            ),
            "tool_call_delta"
        );
    }

    # A provider that fragments pathologically must not become a flood.
    sent = len(range(0, len(BODY), 2));
    assert len(under(48, 200, 2)) < sent / 4 , f"expected coalescing, got {len(
        under(48, 200, 2)
    )} events for {sent} fragments";

    # min_interval is pinned high above, so only min_chars can publish here.
    tight = under(8, 500, 8);
    loose = under(4000, 500, 8);
    assert len(tight) > len(loose) , f"min_chars was ignored: {len(
        tight
    )} events at 8 chars vs {len(loose)} at 4000";

    assert len(under(8, 3, 8)) <= 4 , f"max_per_call was ignored: {len(
        under(8, 3, 8)
    )} events with a cap of 3";

    # Hitting the cap must be visible: a consumer rendering the fragments is
    # otherwise showing a silently truncated value as if it were complete.
    capped = under(8, 3, 8);
    marks = [
        d
        for d in capped
        if d.data.get("truncated")
    ];
    assert len(marks) == 1 , f"the cap must be announced exactly once, got {len(
        marks
    )}";
    assert marks[0] is capped[-1] , "the truncation mark must be the call's last delta";
}


test "an abandoned stream is always announced alongside its deltas" {
    short = '{"path": "a.jac"}';
    big = '{"path": "a.jac", "content": "' + ("a" * 200) + '"}';

    # Compaction discards a stream WITHOUT incrementing _stream_reset_count, so
    # no counter-based guard sees it. Not transient, so byllm does not retry.
    def overflow -> any {
        for ch in _frags(big, "write_file", "c1") {
            yield ch;
        }
        raise litellm.exceptions.ContextWindowExceededError(
            message="too long", model="gpt-4o", llm_provider="openai"
        );
    }

    # Same staleness class, different handler: the response fails conversion
    # after deltas are already on screen, and that call will never run.
    def unconvertible -> any {
        for ch in _frags(big, "write_file", "c1") {
            yield ch;
        }
        raise OutputConversionError("could not convert");
    }

    # reset_first: a retry announces BEFORE the replacement's deltas; compaction
    # announces AFTER the deltas it is abandoning.
    cases = [
        (
            "retry/loop",
            [RETRY, _frags(BODY, "write_file", "c1")],
            [None, _rebuilt([("c1", "write_file", BODY)])],
            [write_file],
            True,
            False
        ),
        (
            "retry/flush",
            [RETRY, [_chunk(frag=short[i:i + 4]) for i in range(0, len(short), 4)]],
            [None, _rebuilt([("c1", "read_file", short)])],
            [read_file],
            True,
            False
        ),
        ("compaction", [overflow], [None], [write_file], False, True),
        ("conversion", [unconvertible], [None], [write_file], False, True)
    ];

    for (label, turns, rebuilts, tools, reset_first, tolerate) in cases {
        seen: dict = {};
        events = _run(turns, rebuilts, tools, tolerate_errors=tolerate, probe=seen);
        kinds = _kinds(events);

        assert "tool_call_delta" in kinds , f"[{label}] no deltas to reason about: {kinds}";
        assert "stream_reset" in kinds , f"[{label}] the abandoned stream was never announced: {kinds}";
        if reset_first {
            assert kinds.index("stream_reset") < kinds.index("tool_call_delta") , f"[{label}] reset must precede the replacement's deltas: {kinds}";
        } else {
            assert kinds.index("tool_call_delta") < kinds.index("stream_reset") , f"[{label}] the reset must follow the deltas it abandons: {kinds}";
        }
        # Announcing is only half of it: staged fragments for a call that never
        # ran must not survive to be drained into the next iteration.
        assert not seen["mt"]._tool_arg_deltas , f"[{label}] stale fragments left staged: {seen[
            'mt'
        ]._tool_arg_deltas}";
    }
}


# The streaming finish branch (jaseci-labs/jac#8169): heal misnamed arguments,
# feed back invocation failures as recoverable tool errors.
test "the streaming finish branch heals and recovers" {
    def _finish_args(payload: str, call_id: str) -> tuple {
        return (
            _frags(payload, "finish_tool", call_id),
            _rebuilt([(call_id, "finish_tool", payload)])
        );
    }

    (heal_turn, heal_rebuilt) = _finish_args('{"output": "healed answer"}', "h1");
    events = _run([heal_turn], [heal_rebuilt], [write_file]);
    assert "steps_done" in _kinds(events) , f"never finished: {_kinds(events)}";

    attempts = [0];

    def finish_tool(final_output: str) -> str {
        attempts[0] += 1;
        if attempts[0] == 1 {
            raise FinishToolError("simulated finish invocation failure");
        }
        return final_output;
    }

    (bad, bad_rebuilt) = _finish_args('{"final_output": "first try"}', "b1");
    (good, good_rebuilt) = _finish_args('{"final_output": "second try"}', "b2");
    events = _run([bad, good], [bad_rebuilt, good_rebuilt], [finish_tool]);
    # finish_tc() and get_output() each invoke the tool: pin survival, not count.
    assert attempts[0] > 1 , f"the failed finish call was never retried: {attempts[0]}";
    assert "steps_done" in _kinds(events) , f"never recovered: {_kinds(events)}";
}
