"""Compaction over a `conversation=` history that already holds tool calls.

A tool call that comes back in through `conversation=` must reach the summariser, and
the model, in the same shape as one made during the turn: a dict.
"""

import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm._optdeps.litellm { LiteLLMMessage }
import from support { call, finish, say }


glob LOOKUP_CALL: list[dict[str, any]] = [
         {
             "id": "call_seed",
             "type": "function",
             "function": {"name": "lookup", "arguments": "{\"q\": \"x\"}"}
         }
     ];


def lookup(q: str) -> str {
    return "found";
}


"""One prior tool exchange, seeded the way a caller holds it. The first message is the
slot compaction treats as the task, so the exchange sits in the part it summarises."""
def seeded_history(tool_call_msg: any) -> list[any] {
    return [
        {"role": "user", "content": "OLD_QUESTION"},
        tool_call_msg,
        {
            "role": "tool",
            "tool_call_id": "call_seed",
            "name": "lookup",
            "content": "SEEDED_RESULT"
        },
        {"role": "assistant", "content": "OLD_ANSWER"}
    ];
}


"""The assistant tool-call message in each shape a caller can hold it in."""
def tool_call_shapes(content: str = "") -> list[tuple[str, any]] {
    msg = {"role": "assistant", "content": content, "tool_calls": LOOKUP_CALL};
    return [("dict", msg), ("litellm message", LiteLLMMessage(**msg))];
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
    for (shape, msg) in tool_call_shapes() {
        text = summariser_input(ask_with_compaction(seeded_history(msg)));
        assert "[assistant] called: lookup({\"q\": \"x\"})" in text , (
            f"{shape}: the tool call must read as a called line:\n{text}"
        );
        assert "Message(" not in text , f"{shape}: a Python repr leaked into:\n{text}";
    }
}


test "a tool call with text keeps both in the summariser input" {
    for (shape, msg) in tool_call_shapes("LET_ME_CHECK") {
        text = summariser_input(ask_with_compaction(seeded_history(msg)));
        assert "LET_ME_CHECK" in text , f"{shape}: the assistant text is lost:\n{text}";
        assert "called: lookup(" in text , f"{shape}: the tool call is lost:\n{text}";
    }
}


test "the model is sent a tool call from conversation= as a dict" {
    for (shape, msg) in tool_call_shapes() {
        history = seeded_history(msg);
        llm = MockLLM(outputs=[finish("done")]);

        def ask(question: str) -> str by llm(tools=[lookup], conversation=history);

        ask("NEW_QUESTION");
        sent = llm.sent("messages")[0];
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
