"""A tool call truncated at max_tokens (finish_reason == "length") must surface a
clear truncation error, not execute the tool with partial arguments."""

import types;
import from unittest { mock }
import from byllm.lib { Model }


def save_data(name: str, payload: str) -> str {
    return f"saved {name} ({len(payload)} bytes)";
}


test "truncated tool call surfaces a max_tokens error, not missing-arg" {
    conv: list[dict] = [];
    llm = Model(model_name="gpt-4o");

    # iter 1: tool-call args cut off at max_tokens (valid JSON, missing `payload`);
    # iter 2: a normal reply so the ReAct loop ends.
    calls = [0];
    def fake(params: dict) -> dict {
        calls[0] += 1;
        if calls[0] == 1 {
            tc = types.SimpleNamespace(
                id="c1",
                function=types.SimpleNamespace(
                    name="save_data", arguments='{"name": "x"}'
                )
            );
            msg = {"role": "assistant", "content": "", "tool_calls": [tc]};
            return {
                "choices": [{"message": msg, "finish_reason": "length"}],
                "model": "gpt-4o",
                "usage": {}
            };
        }
        done = {"role": "assistant", "content": "done", "tool_calls": []};
        return {
            "choices": [{"message": done, "finish_reason": "stop"}],
            "model": "gpt-4o",
            "usage": {}
        };
    }

    def run(task: str) -> str by llm(
        tools=[save_data], conversation=conv, stream=False
    );

    with mock.patch.object(llm, "model_call_no_stream", fake) {
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
