"""Test the `conversation=<list>` kwarg: in-place write-back, scaffolding
filtering, multi-turn growth, and pre-seeded dict round-trip."""
import from byllm.lib { MockLLM, MockToolCall }


def get_weather(city: str) -> str {
    return f"sunny in {city}";
}


# Stub matched by-name to byllm's auto-injected finish_tool.
def finish_tool(final_output: str) -> str {
    return final_output;
}


glob llm = MockLLM(
         model_name="mockllm",
         config={
             "outputs": [
                 # Turn 1: tool call → finish
                 MockToolCall(tool=get_weather, args={"city": "Paris"}),
                 MockToolCall(
                     tool=finish_tool, args={"final_output": "Paris is sunny."}
                 ),
                 # Turn 2: finish only
                 MockToolCall(
                     tool=finish_tool,
                     args={"final_output": "Yes, still sunny in Paris."}
                 )
             ]
         }
     ),
     history: list = [];


def ask(message: str) -> str by llm(tools=[get_weather], conversation=history);


glob prior_marker = "PRIOR_SESSION_USER_TURN";
with entry {
    history.append({"role": "user", "content": prior_marker});
}

glob history_id_before = id(history),
     r1 = ask("How is Paris?");

# The caller's list ref is stable — `write_back_conversation` mutates
# the same list object.
with entry {
    assert id(history) == history_id_before;

    # Pre-seeded dict survives the round-trip (Message.from_dict → Message → dict).
    assert any(
        m.get("role") == "user" and prior_marker in str(m.get("content", ""))
        for m in history
    ) , f"pre-seeded user dict was lost: {history}";
}

# Scaffolding (SYSTEM) and MockLLM's raw-string placeholders are excluded.
glob roles = [m.get("role") for m in history];
with entry {
    assert "system" not in roles , f"SYSTEM should be excluded, got {roles}";
    assert roles.count("user") == 2 , (
        f"expected 2 user msgs (pre-seeded + turn1), got {roles}"
    );
}

# Real tool result is preserved with name + tool_call_id.
glob tool_msgs = [
         m
         for m in history
         if m.get("role") == "tool"
     ];

with entry {
    assert len(tool_msgs) == 1 , f"expected 1 tool msg, got {len(tool_msgs)}";
    assert tool_msgs[0].get("name") == "get_weather" , (
        f"only finish_tool should be filtered; got name={tool_msgs[0].get('name')}"
    );
    assert "tool_call_id" in tool_msgs[0] , "tool_call_id field missing";

    # finish_tool entries must NOT appear under any role.
    for m in history {
        assert m.get("name") != "finish_tool" , f"finish_tool leaked: {m}";
    }
}

glob turn1_len = len(history);

# Turn 2 — same list grows; pre-seed + turn-1 messages both survive.
with entry {
    ask("And again?");
    assert len(history) > turn1_len , "history did not grow on turn 2";
}

glob user_msgs = [
         m
         for m in history
         if m.get("role") == "user"
     ];

with entry {
    assert len(user_msgs) == 3 , (
        f"expected 3 user msgs (pre-seeded + turn1 + turn2), got {len(user_msgs)}"
    );
}

glob user_contents = [str(m.get("content", "")) for m in user_msgs];
with entry {
    assert any(prior_marker in c for c in user_contents) , "pre-seeded msg lost on turn 2";
    assert any("Paris" in c for c in user_contents) , "turn-1 user message lost";

    print("CONV_PARAM_PASS");
}
