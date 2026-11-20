"""Compaction sizes what it keeps in tokens, not in messages.

The trigger is a token ratio, so what compaction keeps and what it asks the summariser to
shrink are budgeted in tokens too. These tests pin that with the default settings, which
keep three assistant rounds.
"""

import litellm;

import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { MockLLM }
import from support { call, capture_loguru, fail, finish, roles, sent_messages }


"""A tool result of `size` characters: 4 characters is about one token."""
def chunk(size: int) -> str {
    return "x" * size;
}


"""One assistant round and its results: an int for one call, a list for parallel calls."""
def make_round(idx: int, result_chars: any) -> list[any] {
    sizes = result_chars if isinstance(result_chars, list) else [result_chars];
    ids = [f"call_{idx}_{n}" for n in range(len(sizes))];
    return [
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {"id": i, "function": {"name": "search", "arguments": "{}"}}
                for i in ids
            ]
        }
    ]
        + [
            {
                "role": "tool",
                "content": "r" * chars,
                "tool_call_id": i,
                "name": "search"
            } for (i, chars) in zip(ids, sizes)
        ];
}


"""A system and user preamble, then `round_count` rounds of the same size."""
def history(round_count: int, result_chars: any) -> list[any] {
    messages: list[any] = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Do the thing."}
    ];
    for idx in range(1, round_count + 1) {
        messages += make_round(idx, result_chars);
    }
    return messages;
}


"""What compaction returns in a 4000-token window, whose tail budget is 1000 tokens."""
def compact(
    messages: list[any], keep_recent: int = 3, summariser: any = None
) -> list[any] {
    return list(
        _byllm_llm_mod._default_compact(
            messages, keep_recent, summariser or MockLLM(outputs=["S"]), ctx_window=4000
        )
    );
}


"""The `key` of every message with this role; "id" means the first tool call's."""
def field(messages: list[any], role: str, key: str) -> list[any] {
    return [
        m["tool_calls"][0]["id"] if key == "id" else m[key]
        for m in messages
        if m["role"] == role
    ];
}


"""One turn in a 1000-token window. Returns the model and the log it wrote."""
def one_turn(
    outputs: list[any], tools: list[any], on_compaction: any = None
) -> tuple[MockLLM, str] {
    llm = MockLLM(ctx_window=1000, outputs=outputs);

    def ask(q: str) -> str by llm(tools=tools, on_compaction=on_compaction);

    with capture_loguru() as logs {
        assert ask("go") == "ok";
    }
    return (llm, logs.text());
}


test "the default settings compact when the threshold is crossed after two rounds" {
    (llm, _) = one_turn(
        [
            call("chunk", {"size": 1200}, usage={"prompt_tokens": 100}),
            call("chunk", {"size": 1200}, usage={"prompt_tokens": 900}),
            "SUMMARY_TEXT",
            finish("ok")
        ],
        [chunk]
    );
    # The third request is the summariser's: it saw only the first round.
    assert [len(m) for m in llm.sent("messages")] == [2, 4, 2, 5];
    assert roles(llm, 3) == ["system", "user", "user", "assistant", "tool"];
    assert "SUMMARY_TEXT" in sent_messages(llm, 3)[2]["content"];
}


test "the kept tail is the newest rounds that fit the token budget" {
    cases = [
        ("every requested round fits", 1000, ["call_2_0", "call_3_0", "call_4_0"]),
        ("the oldest round is dropped to fit", 1500, ["call_3_0", "call_4_0"]),
        ("the newest round is kept however large", 6000, ["call_4_0"])
    ];
    for (label, result_chars, expected) in cases {
        got = field(compact(history(4, result_chars)), "assistant", "id");
        assert got == expected , f"{label}: kept {got}";
    }
}


test "the kept tail's results are clipped on a copy only when they exceed the budget" {
    cases = [
        ("within the budget", history(3, 1000), [1000, 1000, 1000], False),
        (
            "over it, the two results of one round share it",
            history(1, 1000) + make_round(2, [8000, 8000]),
            [2000, 2000],
            True
        )
    ];
    for (label, messages, want_lens, clipped) in cases {
        before = field(messages, "tool", "content");
        got = field(compact(messages), "tool", "content");
        assert len(got) == len(want_lens) , f"{label}: {len(got)} results kept";
        for (content, want) in zip(got, want_lens) {
            assert want <= len(content) < want + 100 , (
                f"{label}: {len(content)} characters"
            );
            assert ("[truncated" in content) == clipped , label;
        }
        assert field(messages, "tool", "content") == before , f"{label}: the input was mutated";
    }
}


test "a slice too small to be worth a summariser call is left alone" {
    # A 4000-token window skips slices under 200 tokens (800 characters).
    cases = [("a few small results", 100, 0), ("results past the minimum", 1000, 1)];
    for (label, result_chars, summariser_calls) in cases {
        messages = history(3, result_chars);
        summariser = MockLLM(outputs=["S"]);
        compacted = compact(messages, 1, summariser);
        assert len(summariser.seen) == summariser_calls , (
            f"{label}: {len(summariser.seen)} summariser calls"
        );
        assert (compacted == messages) == (summariser_calls == 0) , label;
    }
}


test "a context overflow caused by one huge tool result is recovered by truncating it" {
    (llm, _) = one_turn(
        [
            call("chunk", {"size": 40000}),
            fail(
                litellm.exceptions.ContextWindowExceededError(
                    message="ctx exceeded", model="mockllm", llm_provider="openai"
                )
            ),
            finish("ok")
        ],
        [chunk]
    );
    # The overflowing request, then the retry; only the retry carries the clipped result.
    assert len(sent_messages(llm, 1)[-1]["content"]) == 40000;
    retried = sent_messages(llm, 2)[-1]["content"];
    assert len(retried) < 2000;
    assert retried.startswith("x" * 100);
    assert "[truncated" in retried;
    assert llm.exhausted();
}


test "a threshold crossing with nothing worth summarising neither fails nor summarises" {
    (llm, logs) = one_turn(
        [
            call("chunk", {"size": 8}, usage={"prompt_tokens": 100}),
            call("chunk", {"size": 8}, usage={"prompt_tokens": 900}),
            finish("ok")
        ],
        [chunk]
    );
    assert [len(m) for m in llm.sent("messages")] == [2, 4, 6];
    assert "Compacting message history" in logs;
    assert "could not reduce the message history" in logs;
}


test "a history still over the threshold after compaction lets the call continue" {
    (llm, logs) = one_turn(
        [
            call("chunk", {"size": 1200}, usage={"prompt_tokens": 100}),
            call("chunk", {"size": 1200}, usage={"prompt_tokens": 900}),
            "SUMMARY_TEXT",
            call("chunk", {"size": 1200}, usage={"prompt_tokens": 850}),
            finish("ok")
        ],
        [chunk]
    );
    assert llm.exhausted();
    assert "still at or above threshold" in logs;
}


test "a hook that shrinks a tool result without removing a message counts as a reduction" {
    def stub_results(msgs: list[any], keep_recent: int) -> list[any] {
        return [
            dict(m, content="[stubbed]") if m["role"] == "tool" else m for m in msgs
        ];
    }

    (llm, logs) = one_turn(
        [
            call("chunk", {"size": 1200}, usage={"prompt_tokens": 100}),
            call("chunk", {"size": 1200}, usage={"prompt_tokens": 900}),
            finish("ok")
        ],
        [chunk],
        on_compaction=stub_results
    );
    # Same message count, far fewer tokens: the next request carries the stub.
    assert len(sent_messages(llm, 2)) == 6;
    assert sent_messages(llm, 2)[3]["content"] == "[stubbed]";
    assert "could not reduce the message history" not in logs;
    assert "reduced message list from 5 to 5 messages" in logs;
}
