"""The `conversation=<list>` kwarg: what byLLM writes back into the caller's list.

byLLM appends to the caller's list in place. The system prompt and finish_tool
plumbing are filtered out on the way; a real tool result is not.
"""

import from jaclang.byllm.exceptions { FinishToolError }
import from jaclang.byllm.types { Message, MessageRole, ToolCallResultMsg }
import from jaclang.byllm.lib { MockLLM }
import from litellm.types.utils {
    ChatCompletionMessageToolCall,
    Function,
    Message as LiteLLMMessage
}
import from support { call, calls, finish, mk_run, say, sent_messages }


def get_weather(city: str) -> str {
    return f"sunny in {city}";
}


"""Every message in `history` with the given role."""
def by_role(history: list[dict[str, any]], role: str) -> list[dict[str, any]] {
    return [
        m
        for m in history
        if m.get("role") == role
    ];
}


"""One conversation carried across two turns, sharing the caller's list."""
def ask_twice(history: list[dict[str, any]]) -> tuple[any, ...] {
    llm = MockLLM(
        outputs=[
            call("get_weather", {"city": "Paris"}),
            finish("Paris is sunny."),
            finish("Yes, still sunny in Paris.")
        ]
    );

    def ask(message: str) -> str by llm(tools=[get_weather], conversation=history);

    first = ask("How is Paris?");
    turn1_len = len(history);
    second = ask("And again?");
    return (llm, first, second, turn1_len);
}


test "the caller's list is mutated in place, not replaced" {
    history: list[dict[str, any]] = [
        {"role": "user", "content": "PRIOR_SESSION_USER_TURN"}
    ];
    before = id(history);

    ask_twice(history);

    assert id(history) == before , "write_back_conversation must mutate the caller's list";
    assert any(
        "PRIOR_SESSION_USER_TURN" in str(m.get("content", ""))
        for m in by_role(history, "user")
    ) , f"a pre-seeded dict must survive the round trip: {history}";
}


test "scaffolding and finish_tool are filtered out, a real tool result is not" {
    history: list[dict[str, any]] = [
        {"role": "user", "content": "PRIOR_SESSION_USER_TURN"}
    ];
    ask_twice(history);

    roles = [m.get("role") for m in history];
    assert "system" not in roles , f"the system prompt is scaffolding, not conversation: {roles}";

    tool_msgs = by_role(history, "tool");
    assert len(tool_msgs) == 1 , f"expected the one real tool result, got {len(
        tool_msgs
    )}";
    assert tool_msgs[0].get("name") == "get_weather" , (
        f"only finish_tool should be filtered, got name={tool_msgs[0].get('name')!r}"
    );
    assert "tool_call_id" in tool_msgs[0] , (
        f"a tool result needs its call id to be replayable: {tool_msgs[0]}"
    );
    for m in history {
        assert m.get("name") != "finish_tool" , f"finish_tool is plumbing and leaked: {m}";
    }
}


test "a second turn grows the same list and keeps every earlier message" {
    history: list[dict[str, any]] = [
        {"role": "user", "content": "PRIOR_SESSION_USER_TURN"}
    ];
    (llm, first, second, turn1_len) = ask_twice(history);

    assert first == "Paris is sunny." , f"got {first!r}";
    assert second == "Yes, still sunny in Paris." , f"got {second!r}";
    assert len(history) > turn1_len , "the second turn must append, not overwrite";

    users = by_role(history, "user");
    assert len(users) == 3 , (
        f"expected the pre-seeded turn plus two asked turns, got {len(users)}"
    );
    contents = [str(m.get("content", "")) for m in users];
    assert any("PRIOR_SESSION_USER_TURN" in c for c in contents) , (
        f"the pre-seeded message was dropped on turn 2: {contents}"
    );
    assert any("Paris" in c for c in contents) , f"turn 1's message was dropped: {contents}";
}


"""Drive one streamed turn and return what the caller saw."""
def stream_turn(llm: MockLLM, history: list[dict[str, any]], message: str) -> str {
    def ask(msg: str) -> str by llm(
        tools=[get_weather], conversation=history, stream=True
    );

    text = "";
    for tok in ask(message) {
        text += tok;
    }
    return text;
}


"""Every entry must be a dict, and the streamed answer must be among them."""
def assert_written_back(label: str, history: list[dict[str, any]], answer: str) {
    for m in history {
        assert isinstance(m, dict) , (
            f"{label}: history holds dicts, got {type(m).__name__}"
        );
    }
    assistants = [
        str(m.get("content", ""))
        for m in history
        if m.get("role") == "assistant"
    ];
    assert assistants , f"{label}: the streamed assistant message is missing";
    assert any(answer in c for c in assistants) , (
        f"{label}: the streamed answer is not in history: {assistants}"
    );
}


"""One streamed turn: a tool call, the finish call, then the answer."""
def _stream_replies(answer: str = "Paris is sunny right now.") -> list[any] {
    return [call("get_weather", {"city": "Paris"}), finish(answer), say(answer)];
}


test "a streamed answer is written back as dicts, whatever the history was seeded with" {
    # write_back has to run after the generator exhausts, and every entry is
    # persisted as a dict no matter what the caller seeded the list with.
    for (label, seed) in [
        ("empty", []),
        ("dict", [{"role": "user", "content": "PRIOR_DICT"}]),
        ("Message", [Message(role=MessageRole.USER, content="PRIOR_MESSAGE")])
    ] {
        history = list(seed);
        llm = MockLLM(outputs=_stream_replies());
        answer = stream_turn(llm, history, "How is Paris?");
        assert answer , f"{label}: the stream produced nothing";
        assert_written_back(label, history, answer);
    }
}


test "a second streamed turn grows the same history and keeps the first answer" {
    history: list[dict[str, any]] = [];
    # Distinct answers per turn: identical ones would let the second overwrite
    # the first with both assertions below still passing.
    llm = MockLLM(
        outputs=_stream_replies("Paris is sunny right now.")
            + _stream_replies("Paris is still sunny.")
    );

    first = stream_turn(llm, history, "How is Paris?");
    assert_written_back("turn 1", history, first);
    after_first = len(history);

    second = stream_turn(llm, history, "Still sunny?");
    assert second != first , f"the two turns must differ, both gave {first!r}";
    assert len(history) > after_first , (
        f"history did not grow: was {after_first}, now {len(history)}"
    );
    assert_written_back("turn 2, first answer", history, first);
    assert_written_back("turn 2, second answer", history, second);

    # Two per turn: the assistant turn that called the tool, then the answer.
    assert len(by_role(history, "assistant")) == 4 , (
        f"expected four assistant messages, got {len(by_role(history, 'assistant'))}"
    );
    assert len(by_role(history, "user")) == 2 , (
        f"expected two user messages, got {len(by_role(history, 'user'))}"
    );
}


glob RAN: list[str] = [];


def mul(a: int, b: int) -> int {
    RAN.append(f"mul({a},{b})");
    return a * b;
}


def _mul(call_id: str) -> tuple[any, ...] {
    return ("mul", {"a": 2, "b": 3}, call_id);
}


def _fin(call_id: str = "cf") -> tuple[any, ...] {
    return ("finish_tool", {"final_output": "6"}, call_id);
}


"""(calls no result answers, results no call asked for) in `messages`."""
def dangling(messages: list[any]) -> tuple[list[str], list[str]] {
    asked = {str(tc["id"]) for m in messages for tc in (m.get("tool_calls") or [])};
    answered = {
        str(m.get("tool_call_id"))
        for m in messages
        if m.get("role") == "tool"
    };
    return (sorted(asked - answered), sorted(answered - asked));
}

"""Each tool result's content in `messages`, by call id."""
def results(messages: list[any]) -> dict[str, str] {
    return {
        str(m.get("tool_call_id")): str(m.get("content"))
        for m in messages
        if m.get("role") == "tool"
    };
}


test "no tool call is left unanswered, wherever finish_tool sits in the batch" {
    for (label, entries, ran, skipped) in [
        ("last", [_mul("c1"), _fin()], ["mul(2,3)"], []),
        ("middle", [_mul("c1"), _fin(), _mul("c2")], ["mul(2,3)"], ["c2"]),
        ("first", [_fin(), _mul("c1"), _mul("c2")], [], ["c1", "c2"]),
        ("two finishes", [_mul("c1"), _fin(), _fin("cf2")], ["mul(2,3)"], [])
    ] {
        # events=False runs the sync tool loop, events=True the event loop.
        for events in [False, True] {
            where = f"{label}, events={events}";
            RAN.clear();
            history: list[dict[str, any]] = [];
            llm = MockLLM(
                outputs=[calls(entries)] + ([say("FINAL")] if events else [])
            );

            def ask(q: str) -> str by llm(
                tools=[mul], conversation=history, stream=events, logging=events
            );

            out = ask("go");
            if events {
                list(out);
            }
            assert RAN == ran , f"{where}: ran {RAN}";
            for n in range(len(llm.seen)) {
                assert dangling(sent_messages(llm, n))[0] == [] , f"{where}: request {n}";
            }
            assert dangling(history) == ([], []) , f"{where}: saved {history}";
            names = [str(m.get("name")) for m in history]
                + [
                    str(tc["function"]["name"]) for m in history
                    for tc in (m.get("tool_calls") or [])
                ];
            assert "finish_tool" not in names , f"{where}: finish_tool was saved";
            for cid in skipped {
                note = results(history).get(cid, "");
                assert "not executed" in note.lower() , f"{where}: {cid} saved as {note!r}";
            }
        }
    }
}


def _asked(ids: list[str], content: str = "") -> dict[str, any] {
    return {
        "role": "assistant",
        "content": content,
        "tool_calls": [
            {
                "id": i,
                "type": "function",
                "function": {"name": "mul", "arguments": "{}"}
            } for i in ids
        ]
    };
}


def _result(call_id: str, name: str = "mul") -> dict[str, any] {
    return {"role": "tool", "tool_call_id": call_id, "name": name, "content": "r"};
}


def _as_dict(msg: any) -> dict[str, any] {
    if isinstance(msg, dict) {
        return msg;
    }
    return msg.to_dict() if msg?.to_dict else msg.model_dump();
}


test "a saved history drops calls without a result, and finish_tool in any form" {
    q = {"role": "user", "content": "go"};
    lone_finish = _asked(["cf"], "done");
    lone_finish["tool_calls"][0]["function"]["name"] = "finish_tool";
    as_object = LiteLLMMessage(
        role="assistant",
        content="",
        tool_calls=[
            ChatCompletionMessageToolCall(
                id=i, function=Function(name="mul", arguments="{}")
            ) for i in ["a", "z"]
        ]
    );
    rows = [
        (
            "half answered",
            [q, _asked(["a", "b"]), _result("a")],
            ["user", "assistant a", "tool"]
        ),
        ("none answered", [q, _asked(["a"])], ["user"]),
        (
            "none answered, with text",
            [q, _asked(["a"], "thinking")],
            ["user", "assistant"]
        ),
        (
            "an id reused by a later answered call",
            [q, _asked(["c1"]), q, _asked(["c1"]), _result("c1")],
            ["user", "user", "assistant c1", "tool"]
        ),
        (
            "a lone finish_tool whose result is a dict, as after a compaction",
            [q, lone_finish, _result("cf", "finish_tool")],
            ["user"]
        ),
        (
            "a message object",
            [
                q,
                as_object,
                ToolCallResultMsg(content="r", tool_call_id="a", name="mul")
            ],
            ["user", "assistant a", "tool"]
        )
    ];
    for (label, messages, expected) in rows {
        before = str(messages);
        saved: list[str] = [];
        for m in mk_run(tools=[mul], messages=messages).get_history_for_persist() {
            d = _as_dict(m);
            assert d.get("tool_calls") != [] , f"{label}: an empty tool_calls list was saved";
            ids = " ".join(str(tc["id"]) for tc in (d.get("tool_calls") or []));
            saved.append(f"{d.get('role')} {ids}".strip());
        }
        assert saved == expected , f"{label}: saved {saved}";
        assert str(messages) == before , f"{label}: the run's own messages were edited";
    }
}


"""A finish_tool that fails on its first call."""
def _flaky_finish -> any {
    attempts = [0];

    def finish_tool(final_output: str) -> str {
        attempts[0] += 1;
        if attempts[0] == 1 {
            raise FinishToolError("finish failed once");
        }
        return final_output;
    }
    return finish_tool;
}


test "a failed finish_tool retries with the call after it answered" {
    for events in [False, True] {
        RAN.clear();
        llm = MockLLM(
            outputs=[calls([_fin(), _mul("c2")]), finish("second try")]
                + ([say("FINAL")] if events else [])
        );

        def ask(q: str) -> str by llm(
            tools=[mul, _flaky_finish()], stream=events, logging=events
        );

        out = ask("go");
        if events {
            list(out);
        }
        retry = sent_messages(llm, 1);
        notes = results(retry);
        assert dangling(retry)[0] == [] , f"events={events}: the retry leaves a call unanswered";
        assert "not executed" in notes.get("c2", "").lower() , f"events={events}: {notes}";
        assert "finish failed once" in notes.get("cf", "") , f"events={events}: {notes}";
        assert RAN == [] , f"events={events}: a call after finish_tool ran: {RAN}";
    }
}
