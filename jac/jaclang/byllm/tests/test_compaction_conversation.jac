"""Compaction over a `conversation=` history that already holds tool calls: the call
must reach the summariser, and the model, in the same shape as one made during the turn."""

import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm._optdeps.litellm { LiteLLMMessage }
import from support { call, finish, say }


glob LOOKUP_CALL: list[dict[str, any]] = [
         {
             "id": "call_seed",
             "type": "function",
             "function": {"name": "lookup", "arguments": "{\"q\": \"x\"}"}
         }
     ],
     RESULT_MSG: dict[str, any] = {
         "role": "tool",
         "tool_call_id": "call_seed",
         "name": "lookup",
         "content": "SEEDED_RESULT"
     };


def lookup(q: str) -> str {
    return "found";
}


"""One prior tool exchange, seeded the way a caller holds it. The first message is the
slot compaction treats as the task, so the exchange sits in the part it summarises."""
def seeded_history(tool_call_msg: any, result_msg: any = None) -> list[any] {
    return [
        {"role": "user", "content": "OLD_QUESTION"},
        tool_call_msg,
        result_msg if result_msg is not None else dict(RESULT_MSG),
        {"role": "assistant", "content": "OLD_ANSWER"}
    ];
}


"""Each shape a caller can hold an assistant tool call in, with what its summariser
line must then contain."""
def tool_call_rows -> list[tuple[str, any, list[str]]] {
    bare = {"role": "assistant", "content": "", "tool_calls": LOOKUP_CALL};
    with_text = {
        "role": "assistant",
        "content": "LET_ME_CHECK",
        "tool_calls": LOOKUP_CALL
    };
    second = {
        "id": "call_two",
        "type": "function",
        "function": {"name": "count", "arguments": "{\"n\": 2}"}
    };
    two = {"role": "assistant", "content": "", "tool_calls": LOOKUP_CALL + [second]};
    called = "[assistant] called: lookup({\"q\": \"x\"})";
    return [
        ("dict", bare, [called]),
        ("litellm message", LiteLLMMessage(**bare), [called]),
        ("dict, with text", with_text, ["LET_ME_CHECK", "called: lookup("]),
        (
            "litellm message, with text",
            LiteLLMMessage(**with_text),
            ["LET_ME_CHECK", "called: lookup("]
        ),
        ("two calls", two, ["called: lookup({\"q\": \"x\"}); count({\"n\": 2})"])
    ];
}


"""Run one turn over `history` in which the first reply crosses the compaction
threshold. Returns the model, so a test reads what was sent."""
def ask_with_compaction(history: list[any]) -> MockLLM {
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            call("lookup", {"q": "y"}, usage={"prompt_tokens": 900}),
            say("SUMMARY"),
            finish("done")
        ]
    );

    def ask(question: str) -> str by llm(
        tools=[lookup], conversation=history, keep_recent_iterations=1
    );

    ask("NEW_QUESTION");
    return llm;
}


"""The messages the first request carried, for a turn that needs no compaction."""
def sent_messages(history: list[any]) -> list[any] {
    llm = MockLLM(outputs=[finish("done")]);

    def ask(question: str) -> str by llm(tools=[lookup], conversation=history);

    ask("NEW_QUESTION");
    return list(llm.sent("messages")[0]);
}


"""The text handed to the summariser: its request, minus the instruction."""
def summariser_input(llm: MockLLM) -> str {
    requests = [
        sent
        for sent in llm.sent("messages")
        if sent[0].get("content") == "You are a concise summariser."
    ];
    assert len(requests) == 1 , f"expected one summariser call, got {len(requests)}";
    return str(requests[0][1]["content"]).split("\n\n", 1)[1];
}


test "a tool call from conversation= reaches the summariser as a called line" {
    for (shape, msg, wants) in tool_call_rows() {
        text = summariser_input(ask_with_compaction(seeded_history(msg)));
        for want in wants {
            assert want in text , f"{shape}: {want!r} is missing from:\n{text}";
        }
        assert "Message(" not in text , f"{shape}: a Python repr leaked into:\n{text}";
    }
}


test "the model is sent a tool call from conversation= as a dict" {
    for (shape, msg, _) in tool_call_rows() {
        sent = sent_messages(seeded_history(msg));
        assert all(isinstance(m, dict) for m in sent) , (
            f"{shape}: every message is sent as a dict: {[
                type(m).__name__ for m in sent
            ]}"
        );
        calls = [
            m["tool_calls"]
            for m in sent
            if m.get("tool_calls")
        ];
        assert calls[0][0]["function"]["name"] == "lookup" , (
            f"{shape}: the tool call must survive the round trip: {calls}"
        );
    }
}


test "a wrapped tool result and a provider's own fields survive the round trip" {
    rich = {
        "role": "assistant",
        "content": "",
        "reasoning_content": "THOUGHT",
        "tool_calls": LOOKUP_CALL
    };
    sent = sent_messages(
        seeded_history(LiteLLMMessage(**rich), LiteLLMMessage(**RESULT_MSG))
    );
    assert all(isinstance(m, dict) for m in sent) , (
        f"every message is sent as a dict: {[type(m).__name__ for m in sent]}"
    );
    assert any(m.get("tool_call_id") == "call_seed" for m in sent) , (
        f"the tool result must stay linked to its call: {sent}"
    );
    assert any("reasoning_content" in m for m in sent) , (
        f"a provider's own fields must survive the unwrap: {sent}"
    );
}
