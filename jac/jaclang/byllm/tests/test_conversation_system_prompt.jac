"""The system prompt belongs to the call, never to the caller's `conversation=` list.

Compaction hands back copies of the messages, the system prompt among them, and
whatever the list holds is replayed on the next call.
"""

import from jaclang.byllm.lib { MockLLM }
import from support { call, capture_loguru, finish, roles, say }


"""Big enough that the built-in compaction has something worth summarising."""
def read -> str {
    return "result " * 80;
}


"""Keeps the system prompt and the task, as the `on_compaction` docs describe."""
def keep_two(msgs: list[any], keep_recent: int) -> list[any] {
    return [msgs[0], msgs[1]];
}


test "a compaction does not store the system prompt, so the next turn sends one" {
    rows = [
        ("a hook that keeps it", keep_two, []),
        ("the built-in compaction", None, [say("SUMMARY")])
    ];
    for (label, hook, summary) in rows {
        history: list[dict[str, any]] = [];
        llm = MockLLM(
            ctx_window=1000,
            outputs=[
                call("read", usage={"prompt_tokens": 100}),
                call("read", usage={"prompt_tokens": 850})
            ]
                + summary
                + [finish("first"), finish("second")]
        );

        def ask(q: str) -> str by llm(
            tools=[read],
            conversation=history,
            on_compaction=hook,
            keep_recent_iterations=1
        );

        with capture_loguru() as logs {
            ask("one");
        }
        assert "reduced message list" in logs.text() , f"{label}: did not compact";
        ask("two");

        stored = [m["role"] for m in history];
        assert "system" not in stored , f"{label}: stored {stored}";
        last = roles(llm, len(llm.sent("messages")) - 1);
        assert last.count("system") == 1 , f"{label}: the next turn sent {last}";
    }
}


test "a system message already stored in the list is not replayed or kept" {
    history: list[dict[str, any]] = [
        {"role": "system", "content": "STORED_SYSTEM_PROMPT"},
        {"role": "user", "content": "earlier question"},
        {"role": "assistant", "content": "earlier answer"}
    ];
    llm = MockLLM(outputs=[say("ok")]);

    def ask(q: str) -> str by llm(conversation=history);

    ask("next question");

    assert roles(llm) == ["system", "user", "assistant", "user"] , f"sent: {roles(
        llm
    )}";
    assert "STORED_SYSTEM_PROMPT" not in str(llm.sent("messages")[0]);
    assert [m["role"] for m in history] == ["user", "assistant", "user", "assistant"];
}
