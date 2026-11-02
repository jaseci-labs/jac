"""A model's reasoning, and any other field a provider puts on its reply: kept, sent
back, streamed, counted and reported, whatever path the tool loop takes."""

import from pathlib { Path }
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.config_loader { get_byllm_config, reset_byllm_config }
import from jaclang.byllm.telemetry { register_llm_call_hook, unregister_llm_call_hook }
import from support {
    call,
    capture_loguru,
    chunk_text,
    event_types,
    events_of,
    fail,
    finish,
    fixture_path,
    say
}


def get_weather(city: str) -> str {
    return f"sunny in {city}";
}


# Not a multiple of the 200-char merge size, so a short tail is left to flush.
glob THINK: str = "REASONING " + ("step by step " * 20),
     USAGE: dict[str, any] = {
         "prompt_tokens": 10,
         "completion_tokens": 9,
         "total_tokens": 19,
         "completion_tokens_details": {"reasoning_tokens": 7}
     },
     SIGNED: dict[str, any] = {
         "type": "thinking",
         "thinking": THINK,
         "signature": "SIG"
     },
     # (label, fields, kept when streamed). litellm's stream builder drops a thinking
     # block with no text, and provider_specific_fields.
     KINDS: list[tuple[str, dict[str, any], bool]] = [
         ("reasoning text", {"reasoning_content": THINK}, True),
         (
             "signed thinking",
             {"reasoning_content": THINK, "thinking_blocks": [SIGNED]},
             True
         ),
         ("encrypted only", {"thinking_blocks": [SIGNED | {"thinking": ""}]}, False),
         (
             "provider specific",
             {"provider_specific_fields": {"reasoning_details": [{"text": THINK}]}},
             False
         ),
         ("nothing", {}, True)
     ],
     # (label, stream, logging, tools, restream after finish_tool)
     PATHS: list[tuple[str, bool, bool, bool, bool]] = [
         ("whole replies", False, False, True, False),
         ("stream", True, False, True, False),
         ("stream, finish_tool restream", True, False, True, True),
         ("stream with events", True, True, True, False),
         ("stream with events, no tools", True, True, False, False)
     ],
     FIELDS: list[str] = [
         "reasoning_content",
         "thinking_blocks",
         "reasoning_details",
         "provider_specific_fields"
     ];


"""One turn; returns the StreamEvents of a logging stream, else []."""
def turn(
    llm: MockLLM,
    history: list[any],
    path: tuple[str, bool, bool, bool, bool],
    message: str
) -> list[any] {
    (_, stream, logging, tools, _) = path;
    def ask(msg: str) -> str by llm(
        tools=[get_weather] if tools else [],
        conversation=history,
        stream=stream,
        logging=logging
    );
    out: any = ask(message);
    return list(out) if stream else [];
}


"""The provider fields of `m`, missing ones as None."""
def pick(m: dict[str, any]) -> dict[str, any] {
    return {k: m.get(k) for k in FIELDS};
}


test "a reply's own fields are kept, sent back, streamed, counted and reported on every path" {
    def broken(record: dict[str, any]) {
        raise RuntimeError("a hook that raises must not break the call");
    }
    for path in PATHS {
        (path_name, stream, logging, tools, restream) = path;
        for (kind, fields, streams) in KINDS {
            if stream and not streams {
                continue;
            }
            label = f"{path_name}, {kind}";
            # provider_specific_fields arrive lifted onto the reply itself.
            want = dict(fields);
            want.update(want.pop("provider_specific_fields", None) or {});
            replies: list[any] = [];
            for answer in ["Paris is sunny.", "Still sunny."] {
                if tools {
                    replies.append(
                        call(
                            "get_weather", {"city": "Paris"}, fields=fields, usage=USAGE
                        )
                    );
                }
                if restream {
                    replies.append(finish(answer, fields=fields, usage=USAGE));
                }
                replies.append(say(answer, fields=fields, usage=USAGE));
            }
            calls = len(replies);
            llm = MockLLM(outputs=replies, chunk_size=40);
            records: list[dict[str, any]] = [];
            register_llm_call_hook(broken);
            register_llm_call_hook(records.append);
            history: list[any] = [];
            try {
                first = turn(llm, history, path, "How is Paris?");
                held = [dict(m) for m in history];
                second = turn(llm, history, path, "Still sunny?");
            } finally {
                unregister_llm_call_hook(broken);
                unregister_llm_call_hook(records.append);
            }
            # Kept, and nothing invented.
            for m in held {
                assert m.get("role") != "assistant" or pick(m) == pick(want) , (
                    f"{label}: kept {pick(m)}, sent {want}"
                );
            }
            # Turn 2 resends turn 1 unchanged, so the provider's prompt cache matches.
            assert list(llm.sent("messages")[-1])[1:1 + len(held)] == held , (
                f"{label}: turn 2 changed what turn 1 left in the history"
            );
            # One hook record per model call, with the full reply and its usage. A
            # streamed call without tools stores no reply and reports no call.
            assert len(records) == (calls if tools else 0) , f"{label}: {len(
                records
            )} records";
            assert not tools
                or [m["role"] for m in records[0]["new_messages"][:2]]
                    == ["system", "user"] , (
                f"{label}: the first record carries the prompt"
            );
            for rec in records {
                usage = rec["usage"];
                got = (
                    rec["reply"].get("reasoning_content"),
                    rec["call_kind"],
                    usage.get("reasoning_tokens")
                );
                assert got
                    == (want.get("reasoning_content"), usage.get("call_kind"), 7) , (
                    f"{label}: hook record {rec}"
                );
            }
            if not logging {
                continue;
            }
            # Reasoning streams on its own channel, merged, before the answer.
            for evs in (first, second) {
                answering = False;
                for kind_ in event_types(evs) {
                    answering = answering or kind_ in ("thought", "chunk");
                    assert not (answering and kind_ == "reasoning") , (
                        f"{label}: reasoning after the answer began: {event_types(evs)}"
                    );
                }
            }
            events = first + second;
            texts = [str(e.data["content"]) for e in events_of(events, "reasoning")];
            visible = chunk_text(events)
                + str([e.data for e in events_of(events, "thought")]);
            assert "REASONING" not in visible , f"{label}: reasoning leaked into the answer";
            assert "".join(texts) == want.get("reasoning_content", "") * calls
                and len(texts) <= 2 * calls , f"{label}: reasoning events {texts}";
        }
    }
    before = len(records);
    turn(MockLLM(outputs=[say("ok")]), [], PATHS[0], "hi");
    assert len(records) == before , "an unregistered hook must not fire";
}


test "reasoning params reach the model only when set, from by llm() or jac.toml" {
    enabled = {"type": "enabled"};
    keys = ("reasoning_effort", "thinking", "extra_body");
    for given in [
        ("low", None, None),
        (None, enabled, None),
        (None, None, {"thinking": enabled}),
        (None, None, None)
    ] {
        llm = MockLLM(outputs=[say("ok")]);
        def answer(q: str) -> str by llm(
            reasoning_effort=given[0], thinking=given[1], extra_body=given[2]
        );
        answer("hi");
        sent = llm.seen[0];
        for (key, want) in zip(keys, given) {
            assert sent.get(key) == want and (want is not None or key not in sent) , (
                f"{given}: {key} sent as {sent.get(key)!r}"
            );
        }
    }
    reset_byllm_config();
    try {
        params = get_byllm_config(
            Path(fixture_path("reasoning_config"))
        ).get_call_params_config();
        assert tuple(params.get(k) for k in keys) == ("low", enabled, None) , f"jac.toml: {params}";
    } finally {
        reset_byllm_config();
    }
}


test "compaction counts reasoning, and the hook then reports the rebuilt request" {
    records: list[dict[str, any]] = [];
    def drop_reasoning(msgs: list[any], keep_recent: int) -> list[any] {
        return [
            m | {"reasoning_content": None} if isinstance(m, dict) else m for m in msgs
        ];
    }
    big = {"reasoning_content": THINK * 10};
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            call(
                "get_weather",
                {"city": "Galle"},
                fields=big,
                usage={"prompt_tokens": 900}
            ),
            say("done")
        ]
    );
    def ask(q: str) -> str by llm(
        tools=[get_weather], threshold_ratio=0.80, on_compaction=drop_reasoning
    );
    register_llm_call_hook(records.append);
    try {
        with capture_loguru() as logs {
            assert ask("Find Galle") == "done";
        }
    } finally {
        unregister_llm_call_hook(records.append);
    }
    assert "reduced message list" in logs.text() , f"dropping only reasoning is a reduction:\n{logs.text()}";
    flags = [r["after_compaction"] for r in records];
    assert flags.count(True) == 1 , f"after_compaction flags {flags}";
    rebuilt = records[flags.index(True)]["new_messages"];
    assert rebuilt[0]["role"] == "system" , f"the call after compaction reports the whole rebuilt request: {rebuilt}";
}


test "a stream litellm cannot rebuild still keeps the reasoning it carried" {
    think = {"reasoning_content": THINK};
    no_builder = RuntimeError("no builder");
    for (path, replies) in [
        (PATHS[3], [say("Paris is sunny.", fields=think)]),
        (
            PATHS[2],
            [
                finish("Paris is sunny.", fields=think),
                say("Paris is sunny.", fields=think)
            ]
        )
    ] {
        history: list[any] = [];
        with mock.patch.object(
            _byllm_llm_mod.litellm, "stream_chunk_builder", side_effect=no_builder
        ) {
            turn(MockLLM(outputs=replies), history, path, "How is Paris?");
        }
        reply = history[-1];
        assert (reply.get("content"), reply.get("reasoning_content"))
            == ("Paris is sunny.", THINK) , f"{path[0]}: {reply}";
    }
}


test "reasoning streams while the model is still thinking" {
    llm = MockLLM(
        outputs=[
            fail(
                ValueError("dropped"),
                reply=say("", fields={"reasoning_content": THINK})
            )
        ]
    );
    def ask(q: str) -> str by llm(stream=True, logging=True);
    seen: list[str] = [];
    try {
        events: any = ask("hi");
        for ev in events {
            seen.append(ev.event_type);
        }
    } except ValueError {}
    assert "reasoning" in seen , f"no reasoning before the stream ended: {seen}";
}


obj Place {
    has city: str;
}


test "hook records show the request as sent: the parallel hint, and a typed-output retry" {
    records: list[dict[str, any]] = [];
    hinted = MockLLM(outputs=[say("ok")]);
    def ask(q: str) -> str by hinted(tools=[get_weather], parallelize=True);
    retried = MockLLM(
        outputs=[say('{"city": '), say('{"schema_object_wrapper": {"city": "Galle"}}')]
    );
    def place -> Place by retried();
    register_llm_call_hook(records.append);
    try {
        ask("hi");
        assert place().city == "Galle";
    } finally {
        unregister_llm_call_hook(records.append);
    }
    system = records[0]["new_messages"][0];
    assert "scheduling rules" in str(system["content"]) , f"system prompt recorded as {system}";
    retry = records[-1];
    assert retry["after_compaction"]
        and "output parser reported" in str(retry["new_messages"]) , (
        f"the retry record misses its feedback: {retry}"
    );
}
