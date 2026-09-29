"""Tool-argument streaming: `tool_call_delta` (jaseci-labs/jac#7997).

byllm used to read only `delta.content`, so a caller learned a tool was being
invoked only once every argument had been generated. The feature is
display-only and opt-in; each test pins one invariant."""

import litellm;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { MockLLM, MockRawResponse, MockToolCall }
import from jaclang.byllm.exceptions { FinishToolError, OutputConversionError }
import from support { call, calls, event_types, events_of, fail, mk_run, say }

glob SHIPPED_DEFAULTS: dict[str, any] = {
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


"""A dropped connection, which byLLM retries."""
def _dropped -> Exception {
    return litellm.APIConnectionError(
        message="dropped", llm_provider="openai", model="gpt-4o"
    );
}


"""Drive `_invoke_streaming` over `replies`, streamed `chunk_size` chars at a time.
Once they run out the model answers "all done".

    enabled        False means the caller never opts in, i.e. the shipped default
    bounds         stands in for `[byllm.tool_stream]`, so a run never depends on
                   the jac.toml of whoever is running the suite
    resp_type      the run's return type; anything but `str` lets byLLM recover
                   a reply that fails conversion
    probe          receives the run's MTRuntime as probe["mt"]
"""
def _run(
    replies: list[any],
    tools: list[any],
    enabled: bool = True,
    bounds: dict[str, any] | None = None,
    chunk_size: int = 12,
    resp_type: type = str,
    probe: dict[str, any] | None = None
) -> list[any] {
    llm = MockLLM(
        model_name="gpt-4o", outputs=replies + [say("all done")], chunk_size=chunk_size
    );
    mt = mk_run(
        resp_type=resp_type,
        tools=tools,
        stream=True,
        call_params=({"stream_tool_args": True} if enabled else {})
    );
    if probe is not None {
        probe["mt"] = mt;
    }

    resolved = dict(bounds) if bounds else dict(SHIPPED_DEFAULTS);
    cfg = _byllm_llm_mod.get_byllm_config();

    def _tool_stream_cfg -> dict[str, any] {
        return dict(resolved);
    }

    events: list[any] = [];
    with mock.patch.object(cfg, "get_tool_stream_config", _tool_stream_cfg) {
        for ev in llm._invoke_streaming(mt) {
            events.append(ev);
        }
    }
    return events;
}


glob BODY: str = '{"path": "main.jac", "content": "' + ("x" * 400) + '"}';


test "disabled is the shipped default and changes nothing" {
    # Deliberately isolated: this must keep passing even if every other part of
    # the feature is broken, because it is the upgrade-safety guarantee.
    events = _run(
        [call("write_file", BODY, call_id="c1")], [write_file], enabled=False
    );

    assert len(events_of(events, "tool_call_delta")) == 0 , (
        f"deltas leaked while disabled: {event_types(events)}"
    );
    tool_calls = events_of(events, "tool_call");
    assert len(tool_calls) >= 1 , f"the tool call vanished: {event_types(events)}";
    assert tool_calls[0].data.get("args", {}).get("path") == "main.jac" , (
        tool_calls[0].data
    );
    assert len(events_of(events, "tool_result")) >= 1 , (
        f"the tool never ran: {event_types(events)}"
    );
}


test "the gate opens per call or from jac.toml" {
    def gate(enabled: bool, bounds: dict[str, any] | None) -> list[any] {
        return events_of(
            _run(
                [call("write_file", BODY, call_id="c1")],
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
        [
            MockRawResponse(
                content="Writing it. ",
                tool_calls=[MockToolCall(tool="write_file", args=body, call_id="c1")]
            )
        ],
        [write_file],
        chunk_size=5
    );
    kinds = event_types(events);

    deltas = events_of(events, "tool_call_delta");
    assert len(deltas) > 0 , f"no deltas emitted: {kinds}";
    assert kinds.index("tool_call_delta") < kinds.index("tool_call") , f"deltas must precede the call: {kinds}";
    assert deltas[0].data.get("tool") == "write_file" , f"the first delta must name the tool: {deltas[
        0
    ].data}";

    # Display is advisory: what ran is still whatever stream_chunk_builder rebuilt.
    tool_calls = events_of(events, "tool_call");
    assert tool_calls[0].data.get("args", {}).get("content") == "hello world" , (
        tool_calls[0].data
    );
    results = events_of(events, "tool_result");
    assert "wrote 11 chars to main.jac" in str(results[0].data.get("result", "")) , results[
        0
    ].data;

    # A parallel batch must keep each call's fragments under its own id.

    a = '{"path": "a.jac", "content": "aaa"}';
    b = '{"path": "b.jac"}';
    events = _run(
        [calls([("write_file", a, "c1"), ("read_file", b, "c2")])],
        [write_file, read_file],
        chunk_size=8
    );

    joined: dict[str, any] = {};
    for d in events_of(events, "tool_call_delta") {
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
    def under(min_chars: int, max_per_call: int, size: int) -> list[any] {
        return events_of(
            _run(
                [call("write_file", BODY, call_id="c1")],
                [write_file],
                enabled=False,
                chunk_size=size,
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
    # A tool is announced as soon as its name arrives; the rest waits for the flush.
    assert len(loose) == 2 and loose[0].data.get("tool") == "write_file" , (
        f"expected the announcement and the final flush, got {[d.data for d in loose]}"
    );
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
    overflow = litellm.exceptions.ContextWindowExceededError(
        message="too long", model="gpt-4o", llm_provider="openai"
    );
    # Same staleness class, different handler: the response fails conversion
    # after deltas are already on screen, that call never runs, and byLLM
    # recovers with one more (non-streamed) call that answers directly.
    unconvertible = OutputConversionError("could not convert");

    # reset_first: a retry announces BEFORE the replacement's deltas; compaction
    # announces AFTER the deltas it is abandoning. Unnamed fragments are never
    # announced mid-stream, so retry/flush publishes them only when the stream ends.
    cases = [
        (
            "retry/loop",
            [fail(_dropped()), call("write_file", BODY, call_id="c1")],
            [write_file],
            12,
            str,
            True
        ),
        (
            "retry/flush",
            [
                fail(_dropped()),
                call("read_file", short, call_id="c1", unnamed_fragments=True)
            ],
            [read_file],
            4,
            str,
            True
        ),
        (
            "compaction",
            [fail(overflow, reply=call("write_file", big, call_id="c1"))],
            [write_file],
            12,
            str,
            False
        ),
        (
            "conversion",
            [fail(unconvertible, reply=call("write_file", big, call_id="c1")), 7],
            [write_file],
            12,
            int,
            False
        )
    ];

    for (label, replies, tools, size, resp_type, reset_first) in cases {
        seen: dict[str, any] = {};
        events = _run(replies, tools, chunk_size=size, resp_type=resp_type, probe=seen);
        kinds = event_types(events);

        assert "steps_done" in kinds , f"[{label}] the run never finished: {kinds}";
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
    events = _run(
        [call("finish_tool", '{"output": "healed answer"}', call_id="h1")], [write_file]
    );
    assert "steps_done" in event_types(events) , (
        f"never finished: {event_types(events)}"
    );

    attempts = [0];

    def finish_tool(final_output: str) -> str {
        attempts[0] += 1;
        if attempts[0] == 1 {
            raise FinishToolError("simulated finish invocation failure");
        }
        return final_output;
    }

    events = _run(
        [
            call("finish_tool", {"final_output": "first try"}, call_id="b1"),
            call("finish_tool", {"final_output": "second try"}, call_id="b2")
        ],
        [finish_tool]
    );
    # finish_tc() and get_output() each invoke the tool: pin survival, not count.
    assert attempts[0] > 1 , f"the failed finish call was never retried: {attempts[0]}";
    assert "steps_done" in event_types(events) , (
        f"never recovered: {event_types(events)}"
    );
}
