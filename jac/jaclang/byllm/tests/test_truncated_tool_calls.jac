"""A tool call truncated at max_tokens (finish_reason == "length") must surface a
clear truncation error, not execute the tool with partial arguments."""

import from jaclang.byllm.lib { Model }
import from support_tests { call, say, scripted }


def save_data(name: str, payload: str) -> str {
    return f"saved {name} ({len(payload)} bytes)";
}


test "truncated tool call surfaces a max_tokens error, not missing-arg" {
    conv: list[dict] = [];
    llm = Model(model_name="gpt-4o");

    def run(task: str) -> str by llm(
        tools=[save_data], conversation=conv, stream=False
    );

    # Turn 1 is valid JSON cut off before `payload`; turn 2 ends the ReAct loop.
    with scripted(
        llm, [call("save_data", {"name": "x"}, finish_reason="length"), say("done")]
    ) {
        run("save a big payload");
    }

    tool_result = [
        m
        for m in conv
        if isinstance(m, dict) and m.get("role") == "tool"
    ][0];
    content = str(tool_result.get("content"));
    assert "max_tokens" in content , content;
    assert "missing" not in content , content;
}
