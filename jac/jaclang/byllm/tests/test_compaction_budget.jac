"""Compaction sizes what it keeps in tokens, not in messages.

The trigger is a token ratio, so what compaction keeps and what it asks the summariser to
shrink are budgeted in tokens too. These tests pin that with the default settings, which
keep three assistant rounds.
"""

import litellm;

import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { MockLLM }
import from support { call, capture_loguru, fail, finish, roles, sent_messages }


def step -> str {
    return "stepped";
}


# About 300 tokens: bigger than the tail budget of a 1000-token window.
def read_chunk -> str {
    return "x" * 1200;
}


# About 10000 tokens: far over the tail budget of a 1000-token window.
def read_huge -> str {
    return "x" * 40000;
}


def make_round(idx: int, result_chars: int) -> list[any] {
    return [
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": f"call_{idx}",
                    "function": {"name": "search", "arguments": f'{{"q":"q{idx}"}}'}
                }
            ]
        },
        {
            "role": "tool",
            "content": "r" * result_chars,
            "tool_call_id": f"call_{idx}",
            "name": "search"
        }
    ];
}


def make_parallel_round(idx: int, result_chars: list[int]) -> list[any] {
    return [
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": f"call_{idx}_{n}",
                    "function": {"name": "search", "arguments": "{}"}
                } for n in range(len(result_chars))
            ]
        }
    ]
        + [
            {
                "role": "tool",
                "content": "r" * chars,
                "tool_call_id": f"call_{idx}_{n}",
                "name": "search"
            } for (n, chars) in enumerate(result_chars)
        ];
}


def history(round_count: int, result_chars: int) -> list[any] {
    messages: list[any] = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Do the thing."}
    ];
    for idx in range(1, round_count + 1) {
        messages += make_round(idx, result_chars);
    }
    return messages;
}


def kept_call_ids(compacted: list[any]) -> list[str] {
    return [
        m["tool_calls"][0]["id"]
        for m in compacted
        if m["role"] == "assistant"
    ];
}


test "the default settings compact when the threshold is crossed after two rounds" {
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            call("read_chunk", usage={"prompt_tokens": 100}),
            call("read_chunk", usage={"prompt_tokens": 900}),
            "SUMMARY_TEXT",
            finish("ok")
        ]
    );

    def ask(q: str) -> str by llm(tools=[read_chunk]);

    assert ask("go") == "ok";
    # The third request is the summariser's: it saw only the first round.
    assert [len(m) for m in llm.sent("messages")] == [2, 4, 2, 5];
    assert roles(llm, 3) == ["system", "user", "user", "assistant", "tool"];
    assert "SUMMARY_TEXT" in sent_messages(llm, 3)[2]["content"];
}


test "the kept tail is the newest rounds that fit the token budget" {
    # A 4000-token window gives a tail budget of 1000 tokens.
    cases = [
        ("every requested round fits", 1000, ["call_2", "call_3", "call_4"]),
        ("the oldest round is dropped to fit", 1500, ["call_3", "call_4"]),
        ("the newest round is kept however large", 6000, ["call_4"])
    ];
    for (label, result_chars, expected) in cases {
        compacted: list[any] = list(
            _byllm_llm_mod._default_compact(
                history(4, result_chars), 3, MockLLM(outputs=["S"]), ctx_window=4000
            )
        );
        assert kept_call_ids(compacted) == expected , (
            f"{label}: kept {kept_call_ids(compacted)}"
        );
    }
}


test "a context overflow caused by one huge tool result is recovered by truncating it" {
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            call("read_huge"),
            fail(
                litellm.exceptions.ContextWindowExceededError(
                    message="ctx exceeded", model="mockllm", llm_provider="openai"
                )
            ),
            finish("ok")
        ]
    );

    def ask(q: str) -> str by llm(tools=[read_huge]);

    assert ask("go") == "ok";
    # The overflowing request, then the retry; only the retry carries the clipped result.
    overflowed = sent_messages(llm, 1)[-1]["content"];
    retried = sent_messages(llm, 2)[-1]["content"];
    assert len(overflowed) == 40000;
    assert len(retried) < 2000;
    assert retried.startswith("x" * 100);
    assert "[truncated" in retried;
    assert llm.exhausted();
}


test "a tail over the token budget has its tool results truncated in a copy" {
    # A 4000-token window gives a tail budget of 1000 tokens.
    messages = history(1, 1000) + make_parallel_round(2, [8000, 8000]);
    original_results = [
        m["content"]
        for m in messages
        if m["role"] == "tool"
    ];
    compacted: list[any] = list(
        _byllm_llm_mod._default_compact(
            messages, 3, MockLLM(outputs=["S"]), ctx_window=4000
        )
    );

    # The two results of the kept round share the budget: 2000 characters each.
    clipped = [
        m["content"]
        for m in compacted
        if m["role"] == "tool"
    ];
    assert len(clipped) == 2;
    for content in clipped {
        assert 2000 <= len(content) < 2100;
        assert "[truncated: 6000 characters removed]" in content;
    }
    assert [
        m["content"]
        for m in messages
        if m["role"] == "tool"
    ]
        == original_results;
}


test "a tail within the token budget is kept as it is" {
    messages = history(3, 1000);
    compacted: list[any] = list(
        _byllm_llm_mod._default_compact(
            messages, 3, MockLLM(outputs=["S"]), ctx_window=4000
        )
    );

    assert compacted[2:] == messages[2:];
}


test "a slice too small to be worth a summariser call is left alone" {
    # A 4000-token window skips slices under 200 tokens (800 characters).
    cases = [("a few small results", 100, 0), ("results past the minimum", 1000, 1)];
    for (label, result_chars, summariser_calls) in cases {
        messages = history(3, result_chars);
        summariser = MockLLM(outputs=["S"]);
        compacted: list[any] = list(
            _byllm_llm_mod._default_compact(messages, 1, summariser, ctx_window=4000)
        );

        assert len(summariser.seen) == summariser_calls , (
            f"{label}: {len(summariser.seen)} summariser calls"
        );
        assert (compacted == messages) == (summariser_calls == 0) , label;
    }
}


test "a threshold crossing with nothing worth summarising neither fails nor calls the summariser" {
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            call("step", usage={"prompt_tokens": 100}),
            call("step", usage={"prompt_tokens": 900}),
            finish("ok")
        ]
    );

    def ask(q: str) -> str by llm(tools=[step]);

    with capture_loguru() as logs {
        assert ask("go") == "ok";
    }
    assert [len(m) for m in llm.sent("messages")] == [2, 4, 6];
    assert "Compacting message history" in logs.text();
    assert "could not reduce the message history" in logs.text();
}


test "a history still over the threshold after compaction lets the call continue" {
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            call("read_chunk", usage={"prompt_tokens": 100}),
            call("read_chunk", usage={"prompt_tokens": 900}),
            "SUMMARY_TEXT",
            call("read_chunk", usage={"prompt_tokens": 850}),
            finish("ok")
        ]
    );

    def ask(q: str) -> str by llm(tools=[read_chunk]);

    with capture_loguru() as logs {
        assert ask("go") == "ok";
    }
    assert llm.exhausted();
    assert "still at or above threshold" in logs.text();
}
