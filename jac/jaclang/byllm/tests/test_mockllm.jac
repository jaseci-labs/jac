"""MockLLM's own contract: what each queued output becomes, and what is recorded.

MockLLM is public API that users test their own apps with, so each promise in the
byLLM reference's "What each output becomes" table is pinned here.
"""

import from jaclang.byllm.lib {
    MockLLM,
    Model,
    MockToolCall,
    MockRawResponse,
    MockError,
    StreamEvent
}
import from jaclang.byllm.exceptions { OutputConversionError }


obj Person {
    has name: str,
        age: int;
}

enum Mood { HAPPY = "happy", SAD = "sad" }

enum Level { LOW = 1, HIGH = 2 }

obj Team {
    has lead: Person,
        crew: dict[str, list[Person]],
        nick: str | None = None;
}


test "a string answers a str call, and every request is recorded" {
    # outputs= and the older config={"outputs": ...} build the same queue.
    for m in [
        MockLLM(outputs=["Hello Ada"]),
        MockLLM(model_name="mockllm", config={"outputs": ["Hello Ada"]})
    ] {
        def greet(name: str) -> str by m();

        assert greet("Ada") == "Hello Ada";
        assert len(m.seen) == 1;
        assert "Ada" in str(m.sent("messages")[0]) , "the request must be the one byLLM built";
        assert "Ada" in m.seen_prompts[0];
        assert m.exhausted();
    }

    # Two mocks never share a queue or a record, even when one is built bare.
    first = MockLLM(outputs=["a", "b"]);
    def once(q: str) -> str by first();
    once("x");
    second = MockLLM();
    assert second.outputs == [] and second.seen == [] , (
        f"a fresh mock must start empty, got {second.outputs} / {second.seen}"
    );
    assert first.outputs == ["b"] , f"the first mock keeps its own queue, got {first.outputs}";

    # Replacing the queue after construction works under either name, so code
    # written before `outputs=` existed keeps working.
    via_config = MockLLM(model_name="mockllm", config={"outputs": []});
    via_config.config["outputs"] = ["from config"];
    via_attr = MockLLM(outputs=["stale"]);
    via_attr.outputs = ["from outputs"];
    def ask_config(q: str) -> str by via_config();
    def ask_attr(q: str) -> str by via_attr();
    assert ask_config("x") == "from config";
    assert ask_attr("x") == "from outputs";
}


test "typed values round-trip through the real parser" {
    import from pydantic { TypeAdapter }
    ada = Person(name="Ada", age=36);
    team = Team(lead=ada, crew={"ops": [ada, Person(name="Bo", age=4)]}, nick="core");

    m_who = MockLLM(outputs=[ada]);
    m_age = MockLLM(outputs=[36]);
    m_ratio = MockLLM(outputs=[2.5]);
    m_flag = MockLLM(outputs=[True]);
    m_nothing = MockLLM(outputs=[None]);
    m_mood = MockLLM(outputs=[Mood.SAD]);
    m_level = MockLLM(outputs=[Level.HIGH]);
    m_pair = MockLLM(outputs=[[1, 2]]);
    m_moods = MockLLM(outputs=[[Mood.HAPPY, Mood.SAD]]);
    m_counts = MockLLM(outputs=[{"a": 1, "b": 2}]);
    m_team = MockLLM(outputs=[team]);
    m_union_int = MockLLM(outputs=[7]);
    # A string is a valid answer for these three return types, so it is the value.
    m_union_str = MockLLM(outputs=["x"]);
    m_optional_str = MockLLM(outputs=["hi"]);
    m_enum_text = MockLLM(outputs=["sad"]);

    def who -> Person by m_who();
    def age -> int by m_age();
    def ratio -> float by m_ratio();
    def flag -> bool by m_flag();
    def nothing -> int | None by m_nothing();
    def mood -> Mood by m_mood();
    def level -> Level by m_level();
    def pair -> list[int] by m_pair();
    def moods -> list[Mood] by m_moods();
    def counts -> dict[str, int] by m_counts();
    def crew -> Team by m_team();
    def union_int -> int | str by m_union_int();
    def union_str -> int | str by m_union_str();
    def optional_str -> str | None by m_optional_str();
    def enum_text -> Mood by m_enum_text();

    for (label, call, want, ty) in [
        ("obj", who, ada, Person),
        ("int", age, 36, int),
        ("float", ratio, 2.5, float),
        ("bool", flag, True, bool),
        ("None for an optional", nothing, None, int | None),
        ("str enum member", mood, Mood.SAD, Mood),
        ("int enum member", level, Level.HIGH, Level),
        ("list", pair, [1, 2], list[int]),
        ("list of enums", moods, [Mood.HAPPY, Mood.SAD], list[Mood]),
        ("dict", counts, {"a": 1, "b": 2}, dict[str, int]),
        ("obj holding a dict of obj lists and an optional", crew, team, Team),
        ("int for int | str", union_int, 7, int | str),
        ("str for int | str", union_str, "x", int | str),
        ("str for str | None", optional_str, "hi", str | None),
        ("enum value as a string", enum_text, Mood.SAD, Mood)
    ] {
        got = call();
        adapter = TypeAdapter(ty);
        assert adapter.dump_python(got, mode="json")
            == adapter.dump_python(want, mode="json") , f"{label}: got {got!r}";
    }
    assert m_who.sent("response_format")[0] is not None , "a typed call must request a schema";
}


test "a bare string for a typed return that cannot be a string is parsed like model text" {
    m_int = MockLLM(outputs=["36"]);
    m_optional_int = MockLLM(outputs=["x"]);
    def age -> int by m_int();
    def maybe_age -> int | None by m_optional_int();
    for (label, call) in [("int", age), ("int | None", maybe_age)] {
        raised = False;
        try {
            call();
        } except (OutputConversionError, IndexError) {
            raised = True;
        }
        assert raised , f"{label}: a string is not a valid answer, so it must fail as model text";
    }
}


test "a tool call resolves by name against the tools the call offers" {
    for (label, queued, expect_ran) in [
        ("offered, by function", "add", True),
        ("offered, by name", "add-by-name", True),
        ("not offered", "secret", False)
    ] {
        ran: list[str] = [];
        def add(a: int, b: int) -> int {
            ran.append("add");
            return a + b;
        }
        def secret -> str {
            ran.append("secret");
            return "leaked";
        }
        tool = add
            if queued == "add"
            else ("add" if queued == "add-by-name" else secret);
        args = {} if queued == "secret" else {"a": 2, "b": 3};
        m = MockLLM(
            outputs=[
                MockToolCall(tool=tool, args=args),
                MockToolCall(tool="finish_tool", args={"final_output": "done"})
            ]
        );
        def calc(q: str) -> str by m(tools=[add]);

        assert calc("2+3") == "done" , label;
        assert (len(ran) > 0) == expect_ran , f"{label}: ran {ran}";
        if not expect_ran {
            assert "unknown tool" in str(m.sent("messages")[1]) , (
                f"{label}: the model must be told the tool is unknown"
            );
        }
    }

    # A direct conversion keeps the id, so its tool result answers the same call.
    def lookup(q: str) -> str {
        return q;
    }
    tc = MockToolCall(tool=lookup, args={"q": "x"}, call_id="call_7").to_tool_call();
    assert tc.call_id == "call_7" , f"got {tc.call_id!r}";
    assert tc().tool_call_id == "call_7" , "the tool result must answer the same call";
}


test "a streamed answer arrives in chunks, with queued usage attached" {
    # A provider's usage can carry more than the three counters; the extra
    # fields must not turn the (text, usage) pair into a typed answer.
    for (label, queued_usage, expect_cached) in [
        (
            "token counters",
            {"prompt_tokens": 7, "completion_tokens": 3, "total_tokens": 10},
            0
        ),
        (
            "richer provider usage",
            {
                "prompt_tokens": 7,
                "completion_tokens": 3,
                "total_tokens": 10,
                "cache_read_input_tokens": 4,
                "prompt_tokens_details": {"cached_tokens": 4},
                "cost": 0.5
            },
            4
        )
    ] {
        m = MockLLM(outputs=[("Paris is sunny right now.", queued_usage)]);
        def ask(q: str) -> str by m(stream=True, logging=True);

        events = list(ask("weather"));
        chunks = [
            e
            for e in events
            if isinstance(e, StreamEvent) and e.event_type == "chunk"
        ];
        usage = [
            e
            for e in events
            if isinstance(e, StreamEvent) and e.event_type == "usage"
        ];
        assert len(chunks) > 1 , f"{label}: expected several chunks, got {len(chunks)}";
        assert "".join([str(c.data.get("content", "")) for c in chunks])
            == "Paris is sunny right now." , f"{label}: the text must arrive as text";
        total = usage[-1].data["total"] if usage else {};
        assert total.get("total_tokens") == 10 , f"{label}: got {total}";
        assert total.get("cache_read_input_tokens") == expect_cached , f"{label}: got {total}";
    }
}


test "a queued error is raised, and an empty queue says which call ran out" {
    for (label, outputs, kind, fragment) in [
        ("queued error", [MockError(error=RuntimeError("boom"))], RuntimeError, "boom"),
        ("empty queue", [], IndexError, "no queued output left for call 1")
    ] {
        m = MockLLM(outputs=outputs);
        def ask(q: str) -> str by m();
        message = "";
        try {
            ask("x");
        } except kind as e {
            message = str(e);
        }
        assert fragment in message , f"{label}: got {message!r}";
    }
}


test "a reply names the model that answered, whole or streamed" {
    params = {"model": "asked-model", "messages": []};
    served = MockRawResponse(content="hi", model="served-model");
    for (label, reply, expect) in [
        ("no model on the reply", MockRawResponse(content="hi"), "asked-model"),
        ("a fallback model on the reply", served, "served-model"),
        ("the same, with usage attached", (served, {"total_tokens": 3}), "served-model")
    ] {
        whole: any = MockLLM(outputs=[reply]).model_call_no_stream(params);
        assert whole.model == expect , f"{label}: the whole reply named {whole.model}";
        named: set[str] = set();
        for chunk in MockLLM(outputs=[reply]).model_call_with_stream(params) {
            piece: any = chunk;
            named.add(piece.model);
        }
        assert named == {expect} , f"{label}: the stream named {named}";
    }
}


def _streamed_calls(stream: Iterable[object]) -> list[any] {
    fragments: list[any] = [];
    for chunk in stream {
        piece: any = chunk;
        if piece.choices {
            for fragment in piece.choices[0].delta.tool_calls or [] {
                fragments.append(fragment);
            }
        }
    }
    return fragments;
}


def _streamed_args(stream: Iterable[object]) -> str {
    return "".join([str(f.function.arguments or "") for f in _streamed_calls(stream)]);
}


test "tool-call fragments name their call unless the reply says otherwise" {
    args = '{"path": "a.jac", "content": "hello world"}';
    for (label, unnamed, usage) in [
        ("named", False, None),
        ("unnamed", True, None),
        ("unnamed, with usage attached", True, {"total_tokens": 3})
    ] {
        reply = MockRawResponse(
            tool_calls=[MockToolCall(tool="write_file", args=args, call_id="c1")],
            unnamed_fragments=unnamed
        );
        queued: object = (reply, usage) if usage is not None else reply;
        fragments = _streamed_calls(
            MockLLM(chunk_size=8, outputs=[queued]).model_call_with_stream(
                {"model": "m", "messages": []}
            )
        );
        assert len(fragments) > 1 , f"{label}: expected several fragments";
        assert "".join([str(f.function.arguments or "") for f in fragments]) == args , (
            f"{label}: the arguments must arrive whole"
        );
        named = [
            f
            for f in fragments
            if f.id or f.function.name
        ];
        assert len(named) == (0 if unnamed else 1) , (
            f"{label}: got {len(named)} fragments carrying an id or name"
        );
    }
}


test "a stream can drop partway through a reply, or after all of it" {
    params = {"model": "asked-model", "messages": []};
    args = '{"path": "a.jac", "content": "hello world"}';
    tool_call = MockRawResponse(
        tool_calls=[MockToolCall(tool="write_file", args=args, call_id="c1")]
    );
    dropped = RuntimeError("dropped");
    # chunk_size=8 splits "hello world" into "hello wo" and "rld".
    for (label, failing, expect_args, expect_text, expect_models) in [
        (
            "content, after=0 sends nothing",
            MockError(error=dropped, content="hello world"),
            "",
            "",
            set()
        ),
        (
            "content, after=1 sends the first chunk",
            MockError(error=dropped, content="hello world", after=1),
            "",
            "hello wo",
            {"asked-model"}
        ),
        (
            "content, after past the end sends it all",
            MockError(error=dropped, content="hello world", after=5),
            "",
            "hello world",
            {"asked-model"}
        ),
        (
            "reply, a tool call",
            MockError(error=dropped, reply=tool_call),
            args,
            "",
            {"asked-model"}
        ),
        (
            "reply, a queued string",
            MockError(error=dropped, reply="hello world"),
            "",
            "hello world",
            {"asked-model"}
        ),
        (
            "reply, from a fallback model, with usage",
            MockError(
                error=dropped,
                reply=(
                    MockRawResponse(content="hi", model="served-model"),
                    {"total_tokens": 3}
                )
            ),
            "",
            "hi",
            {"served-model"}
        )
    ] {
        delivered: list[object] = [];
        raised = "";
        try {
            for chunk in MockLLM(
                chunk_size=8, outputs=[failing]
            ).model_call_with_stream(
                params
            ) {
                delivered.append(chunk);
            }
        } except RuntimeError as e {
            raised = str(e);
        }
        assert raised == "dropped" , f"{label}: the error must still fire, got {raised!r}";
        texts: list[str] = [];
        models: set[str] = set();
        for chunk in delivered {
            piece: any = chunk;
            models.add(piece.model);
            if piece.choices {
                texts.append(str(piece.choices[0].delta.content or ""));
            }
        }
        assert _streamed_args(delivered) == expect_args , f"{label}: tool arguments";
        assert "".join(texts) == expect_text , f"{label}: text {texts}";
        assert models == expect_models , f"{label}: the stream named {models}";
    }

    # content= and after= are the partial-text form; they do not combine with reply=.
    for (label, bad) in [
        (
            "reply with content",
            MockError(error=RuntimeError("x"), reply="a", content="partial")
        ),
        ("reply with after", MockError(error=RuntimeError("x"), reply="a", after=1)),
        (
            "a reply that is itself an error",
            MockError(error=RuntimeError("x"), reply=MockError(error=RuntimeError("y")))
        )
    ] {
        message = "";
        try {
            MockLLM(outputs=[bad]).model_call_no_stream(params);
        } except ValueError as e {
            message = str(e);
        }
        assert message , f"{label}: must be rejected when it is dequeued";
    }
}


test "a stream carries litellm's logging object when given one" {
    marker = object();
    stream: any = MockLLM(logging_obj=marker, outputs=["hello"]).model_call_with_stream(
        {"model": "m", "messages": []}
    );
    assert stream.logging_obj is marker , "the stream must carry the logging object";
    first: any = next(stream);
    texts: list[str] = [];
    for chunk in [first, *stream] {
        piece: any = chunk;
        if piece.choices {
            texts.append(str(piece.choices[0].delta.content or ""));
        }
    }
    assert "".join(texts) == "hello" , "the stream must still deliver the reply";
}


test "MockRawResponse sends model text verbatim into the parser" {
    m = MockLLM(
        outputs=[
            MockRawResponse(
                content='{"schema_object_wrapper": {"name": "Bo", "age": 4}}'
            )
        ]
    );
    def who -> Person by m();
    p = who();
    assert p.name == "Bo" and p.age == 4;
}


test "Model(model_name='mockllm') delegates to MockLLM" {
    m = Model(model_name="mockllm", config={"outputs": ["via model"]});
    def ask(q: str) -> str by m();
    assert ask("x") == "via model";
}
