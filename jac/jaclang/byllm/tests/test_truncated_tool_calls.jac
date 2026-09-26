"""A reply truncated at max_tokens (finish_reason == "length") must never pass as a
finished answer: a cut-off tool call surfaces a max_tokens error instead of running
with partial arguments, and a reply with no text and no tool call raises
OutputTruncatedError instead of returning an empty answer."""

import from jaclang.byllm.lib { Model, OutputTruncatedError }
import from support { call, say, scripted }


def save_data(name: str, payload: str) -> str {
    return f"saved {name} ({len(payload)} bytes)";
}


"""Run one scripted turn in `mode` and return (answer or raised error, conversation)."""
def _turn(replies: list[any], mode: str) -> tuple[any, list[dict[str, any]]] {
    conv: list[dict[str, any]] = [];
    llm = Model(model_name="gpt-4o");

    def plain(task: str) -> str by llm(
        tools=[save_data], conversation=conv, stream=False
    );

    def streamed(task: str) -> str by llm(
        tools=[save_data], conversation=conv, stream=True
    );

    """Built the way a streaming agent is: tools, streamed, with logging."""
    def events(task: str) -> str by llm(
        tools=[save_data], conversation=conv, stream=True, logging=True
    );

    with scripted(llm, replies) {
        try {
            if mode == "plain" {
                return (plain("save a big payload"), conv);
            }
            text = "";
            for item in (streamed if mode == "streamed" else events)(
                "save a big payload"
            ) {
                if isinstance(item, str) {
                    text += item;
                } elif getattr(item, "event_type", "") == "chunk" {
                    text += str(item.data.get("content", ""));
                }
            }
            return (text, conv);
        } except OutputTruncatedError as e {
            return (e, conv);
        }
    }
}


test "a reply cut off at max_tokens never passes as a finished answer" {
    rows: list[dict[str, any]] = [
        # Valid JSON cut off before `payload`: the tool must not run.
        {
            "case": "cut-off tool call",
            "replies": [
                call("save_data", {"name": "x"}, finish_reason="length"),
                say("done")
            ],
            "answer": "done",
            "tool_error": True
        },
        # The whole budget went to reasoning: no answer exists.
        {
            "case": "empty cut-off reply",
            "replies": [say("", finish_reason="length")],
            "answer": OutputTruncatedError,
            "tool_error": False
        },
        # Cut-off text is still the model's text.
        {
            "case": "cut-off text",
            "replies": [say("partial answer", finish_reason="length")],
            "answer": "partial answer",
            "tool_error": False
        },
        # An empty reply that stopped normally is the model's choice.
        {
            "case": "empty stop",
            "replies": [say("", finish_reason="stop")],
            "answer": "",
            "tool_error": False
        }
    ];
    for row in rows {
        for mode in ["plain", "streamed", "events"] {
            (answer, conv) = _turn(row["replies"], mode);
            where = row["case"] + " / " + mode;
            if row["answer"] is OutputTruncatedError {
                assert isinstance(answer, OutputTruncatedError) , where
                    + ": got "
                    + repr(answer);
                assert "max_tokens" in str(answer) , where + ": " + str(answer);
            } else {
                assert answer == row["answer"] , where + ": got " + repr(answer);
            }
            tool_results = [
                str(m.get("content"))
                for m in conv
                if isinstance(m, dict) and m.get("role") == "tool"
            ];
            if row["tool_error"] {
                assert tool_results and "max_tokens" in tool_results[0] , where
                    + ": "
                    + str(tool_results);
                assert "missing" not in tool_results[0] , where
                    + ": "
                    + tool_results[0];
            }
        }
    }
}
