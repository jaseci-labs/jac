"""A reply cut off at max_tokens, or one with nothing in it, never passes as a finished
answer, and a blank reply is never sent back to the model or saved."""

import asyncio;
import contextlib;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { EmptyReplyError, Model, OutputTruncatedError }
import from support { call, chunk_text, finish, say, scripted, stream_events }


def save_data(name: str, payload: str) -> str {
    return f"saved {name} ({len(payload)} bytes)";
}


"""Assistant turns in `msgs` with blank text, which Anthropic is sent as placeholder text."""
def _blank_replies(msgs: list[any]) -> list[any] {
    return [
        m
        for m in msgs
        if isinstance(m, dict)
            and m.get("role") == "assistant"
            and isinstance(m.get("content"), str)
            and not m["content"].strip()
    ];
}


"""One scripted turn in `mode`: (answer or raised error, conversation). No request
in it may carry a blank assistant reply."""
def _turn(
    replies: list[any], mode: str, iters: int
) -> tuple[any, list[dict[str, any]]] {
    conv: list[dict[str, any]] = [];
    llm = Model(model_name="gpt-4o");

    def run(task: str) -> str by llm(
        tools=[save_data],
        conversation=conv,
        stream=(mode != "plain"),
        logging=mode.startswith("events"),
        max_react_iterations=iters
    );

    async def arun(task: str) -> str by llm(conversation=conv);

    # "events, no builder": litellm cannot rebuild the streamed chunks.
    builder = mock.patch.object(
        _byllm_llm_mod.litellm,
        "stream_chunk_builder",
        side_effect=RuntimeError("no builder")
    )
        if mode == "events, no builder"
        else contextlib.nullcontext();
    with scripted(llm, replies) as fake, builder {
        answer: any = None;
        try {
            if mode == "async" {
                answer = asyncio.run(arun("save a big payload"));
            } else {
                out = run("save a big payload");
                if mode == "streamed" {
                    out = "".join(out);
                } elif mode.startswith("events") {
                    evs = stream_events(out);
                    kinds = [ev.event_type for ev in evs];
                    assert kinds.count("steps_done") <= 1 , f"steps_done sent again: {kinds}";
                    out = chunk_text(evs);
                }
                answer = out;
            }
        } except (OutputTruncatedError, EmptyReplyError) as e {
            answer = e;
        }
        for sent in fake.sent("messages") {
            assert not _blank_replies(sent) , f"{mode}: a blank reply was sent: {sent}";
        }
        return (answer, conv);
    }
}


test "a reply cut off at max_tokens, or empty, never passes as a finished answer" {
    rows: list[tuple[str, list[any], any, int]] = [
        (
            "cut-off tool call",
            [call("save_data", {"name": "x"}, finish_reason="length"), say("done")],
            "done",
            0
        ),
        (
            "empty cut-off reply",
            [say("", finish_reason="length")],
            OutputTruncatedError,
            0
        ),
        (
            "committed answer, empty cut-off restatement",
            [finish("saved it"), say("", finish_reason="length")],
            "saved it",
            0
        ),
        (
            "empty committed answer, empty cut-off restatement",
            [finish(""), say("", finish_reason="length")],
            "",
            0
        ),
        (
            "empty cut-off forced final answer",
            [
                call("save_data", {"name": "x", "payload": "y"}),
                say("", finish_reason="length")
            ],
            OutputTruncatedError,
            1
        ),
        (
            "cut-off text",
            [say("partial answer", finish_reason="length")],
            "partial answer",
            0
        ),
        (
            "empty stop, twice",
            [say(""), say("")],
            {
                "plain": EmptyReplyError,
                "streamed": EmptyReplyError,
                "events": EmptyReplyError,
                "async": ""
            },
            0
        ),
        (
            "empty stop, then an answer",
            [say(""), say("saved it")],
            {
                "plain": "saved it",
                "streamed": "saved it",
                "events": "saved it",
                "async": ""
            },
            0
        ),
        (
            "an empty stop after each round of tool work",
            [
                call("save_data", {"name": "x", "payload": "y"}),
                say(""),
                call("save_data", {"name": "z", "payload": "w"}),
                say(""),
                finish("saved it")
            ],
            "saved it",
            0
        ),
        (
            "cut-off finish_tool answer, after part of it streamed",
            [
                call(
                    "finish_tool",
                    {"final_output": "partial ans"},
                    finish_reason="length"
                ),
                finish("saved it")
            ],
            {
                "plain": "saved it",
                "streamed": OutputTruncatedError,
                "events": "saved it"
            },
            0
        )
    ];
    for (label, replies, by_mode, iters) in rows {
        modes = ["plain", "streamed", "events", "events, no builder"];
        if not any(r.tool_calls for r in replies) {
            modes.append("async");
        }
        for mode in modes {
            (answer, conv) = _turn(replies, mode, iters);
            where = f"{label} / {mode}";
            expected = by_mode[mode.split(",")[0]]
                if isinstance(by_mode, dict)
                else by_mode;
            assert conv , f"{where}: conversation was not written back";
            assert not _blank_replies(conv) , f"{where}: a blank reply was saved: {conv}";
            if expected is OutputTruncatedError {
                assert isinstance(answer, OutputTruncatedError)
                    and "max_tokens" in str(answer) , f"{where}: got {answer!r}";
            } elif expected is EmptyReplyError {
                assert isinstance(answer, EmptyReplyError) , f"{where}: got {answer!r}";
            } else {
                assert answer == expected , f"{where}: got {answer!r}";
            }
            if replies[0].tool_calls
                and replies[0].tool_calls[0].tool == "save_data"
                and replies[0].finish_reason == "length" {
                results = [
                    str(m.get("content"))
                    for m in conv
                    if isinstance(m, dict) and m.get("role") == "tool"
                ];
                assert results
                    and "max_tokens" in results[0]
                    and "missing" not in results[0] , f"{where}: {results}";
            }
        }
    }
}
