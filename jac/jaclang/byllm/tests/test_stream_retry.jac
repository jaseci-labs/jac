"""A streamed answer that drops mid-stream and is retried: what the caller ends up with."""

import asyncio;
import from litellm.exceptions { InternalServerError }
import from jaclang.byllm.types { IterationAction, IterationContext, StreamEvent }
import from jaclang.byllm.lib { MockLLM }
import from support { call, event_types, fail, finish, mk_run, say }


def save_data(name: str) -> str {
    return name;
}


def _dropped(content: str = "partial text here") -> any {
    return fail(
        InternalServerError(message="boom", llm_provider="openai", model="gpt-4o"),
        content=content,
        after=1 if content else 0
    );
}


def _summarize_after_first(ctx: IterationContext) -> IterationAction {
    return IterationAction.ABORT_WITH_SUMMARY;
}


def _reply_text(msg: any) -> str {
    return str(msg.get("content", "") if isinstance(msg, dict) else msg.content);
}


"""(what the caller ends with, what a reset discarded) from a `logging=True` turn."""
def _fold(events: list[StreamEvent]) -> tuple[str, str] {
    (shown, discarded) = ("", "");
    for ev in events {
        if ev.event_type == "stream_reset" {
            (shown, discarded) = ("", discarded + shown);
        } elif ev.event_type == "chunk" {
            shown += ev.data.get("content", "");
        }
    }
    return (shown, discarded);
}


test "a retried answer replaces the attempt that failed" {
    setups = {
        "finish": ([finish("COMMITTED")], {}),
        "cutoff": ([call("save_data", {"name": "x"})], {"max_react_iterations": 1}),
        "abort": (
            [call("save_data", {"name": "x"})],
            {"on_iteration": _summarize_after_first}
        ),
        "recovery": ([say("seven"), finish(7)], {}),
        "none": ([], {})
    };
    cut = say("", finish_reason="length");
    rows = [
        ("after finish_tool", "finish", say("full answer"), "full answer"),
        ("after finish_tool, empty retry", "finish", say(""), "COMMITTED"),
        ("after finish_tool, cut-off retry", "finish", cut, "COMMITTED"),
        ("at max_react_iterations", "cutoff", say("full answer"), "full answer"),
        ("on ABORT_WITH_SUMMARY", "abort", say("full answer"), "full answer"),
        ("after recovery", "recovery", say("full answer"), "full answer"),
        ("with no tools", "none", say("full answer"), "full answer"),
        ("with no tools, empty retry", "none", say(""), "")
    ];
    for (label, ending, retry, expected) in rows {
        (lead, params) = setups[ending];
        mt = mk_run(
            resp_type=int if ending == "recovery" else str,
            tools=[] if ending == "none" else [save_data],
            stream=True,
            call_params=params
        );
        llm = MockLLM(outputs=lead + [_dropped(), retry]);
        (shown, discarded) = _fold(list(llm._invoke_streaming(mt)));
        assert discarded == "partial text" , f"{label}: reset discarded {discarded!r}";
        assert shown == expected , f"{label}: the caller ends with {shown!r}";
        if ending != "none" {
            stored = _reply_text(mt.messages[-1]);
            assert stored == expected , f"{label}: the conversation stored {stored!r}";
        }
    }
}


"""What a plain `stream=True` call delivered, the error that ended it, and its conversation."""
def _plain_turn(ending: str, attempts: list[any]) -> tuple[str, any, list[any]] {
    lead = [finish("COMMITTED")] if ending == "finish" else [];
    llm = MockLLM(outputs=lead + attempts);
    parts: list[str] = [];
    history: list[any] = [];
    if ending == "async" {
        async def ask_async(task: str) -> str by llm(stream=True);

        async def drain -> any {
            try {
                stream: any = await ask_async("go");
                async for token in stream {
                    parts.append(token);
                }
            } except Exception as e {
                return e;
            }
            return None;
        }
        error = asyncio.run(drain());
        return ("".join(parts), error, history);
    }

    def ask(task: str) -> str by llm(
        tools=[save_data] if ending == "finish" else [],
        stream=True,
        conversation=history
    );

    try {
        for token in ask("go") {
            parts.append(token);
        }
    } except Exception as e {
        return ("".join(parts), e, history);
    }
    return ("".join(parts), None, history);
}


test "a plain stream never replays text it has already delivered" {
    rows = [
        ("dropped before any text", [_dropped(""), say("full answer")], "full answer"),
        ("dropped after text", [_dropped(), say("full answer")], "partial text")
    ];
    for ending in ["none", "finish", "async"] {
        for (label, attempts, expected) in rows {
            (text, error, history) = _plain_turn(ending, attempts);
            where = f"{ending} / {label}";
            assert text == expected , f"{where}: the caller received {text!r}";
            if expected == "partial text" {
                assert isinstance(error, InternalServerError) , f"{where}: got {error!r}";
            } else {
                assert error is None , f"{where}: unexpected {error!r}";
            }
            fragments = [
                m
                for m in history
                if "partial" in str(m.get("content"))
            ];
            assert not fragments , f"{where}: the conversation kept {fragments}";
        }
    }
}


test "a logging stream that fails for good leaves no fragment in the conversation" {
    history: list[dict[str, any]] = [];
    llm = MockLLM(outputs=[finish("COMMITTED"), _dropped()]);

    def ask(task: str) -> str by llm(
        tools=[save_data],
        stream=True,
        logging=True,
        stream_num_retries=0,
        conversation=history
    );

    error: any = None;
    try {
        list(ask("go"));
    } except Exception as e {
        error = e;
    }
    assert isinstance(error, InternalServerError) , f"got {error!r}";
    assert history , "the conversation was not written back";
    assert not [
        m
        for m in history
        if "partial" in str(m.get("content"))
    ] , str(history);
}


test "a typed call with a stream_handler parses only the retried answer, without reasoning" {
    seen: list[StreamEvent] = [];
    llm = MockLLM(
        outputs=[
            _dropped("[9, 9, 9, 9, 9, 9"),
            say("[1, 2]", fields={"reasoning_content": "Let me think. " * 30})
        ]
    );

    def pick(options: str) -> list[int] by llm(
        stream=True, logging=True, stream_handler=seen.append
    );

    assert pick("go") == [1, 2];
    kinds = event_types(seen);
    assert "stream_reset" in kinds
        and kinds.index("stream_reset") > kinds.index("chunk") , (
        f"the failed attempt must reach the handler, then a reset: {kinds}"
    );
    assert "reasoning" in kinds , f"the handler never received the reasoning: {kinds}";
}
