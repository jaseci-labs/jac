"""Shared helpers for the byLLM suite. `TESTING.md` holds the rules.

Tests fake the model with `MockLLM`, which replaces only the network call, so byLLM
builds the real request and parses the reply. The builders below script its turns:

    llm = MockLLM(outputs=[call("lookup", {"q": "x"}), say("done")]);
    def task(q: str) -> str by llm(tools=[lookup]);
    assert task("x") == "done";
    assert llm.sent("tools")[0] is not None;

A typed answer is queued as the value itself. For what a queue cannot say:

    scripted(model, replies)   a real `Model` answering from a queue
    ProviderLLM(...)           a served model, a stream `logging_obj`, a dropped stream

The file is not collected as a suite: it has no `test_` prefix by design.
"""

import logging;
import os;
import from typing { Generator }
import from unittest { mock }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.byllm.llm { BaseLLM }
import from jaclang.byllm.lib { MockLLM, MockToolCall, MockRawResponse, MockError }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole, StreamEvent, Tool }

glob FIXTURE_DIR: str = os.path.join(os.path.dirname(__file__), "fixtures"),
     TOKENS: dict[str, any] = {
         "prompt_tokens": 100,
         "completion_tokens": 20,
         "total_tokens": 120
     };


"""Model text; `finish_reason="length"` makes it a truncated turn."""
def say(
    content: str, usage: dict[str, any] | None = None, finish_reason: str = ""
) -> MockRawResponse {
    return MockRawResponse(content=content, usage=usage, finish_reason=finish_reason);
}


"""A single tool call; `args` may be a dict or an already-encoded JSON string."""
def call(
    name: str,
    args: dict[str, any] | str | None = None,
    call_id: str = "",
    usage: dict[str, any] | None = None,
    finish_reason: str = ""
) -> MockRawResponse {
    return calls(
        [(name, args if args is not None else {}, call_id)],
        usage=usage,
        finish_reason=finish_reason
    );
}


"""Several tool calls in one turn; each entry is (name, args) or (name, args, id)."""
def calls(
    entries: list[any], usage: dict[str, any] | None = None, finish_reason: str = ""
) -> MockRawResponse {
    return MockRawResponse(
        tool_calls=[
            MockToolCall(tool=e[0], args=e[1], call_id=e[2] if len(e) > 2 else "")
            for e in entries
        ],
        usage=usage,
        finish_reason=finish_reason
    );
}


def finish(
    output: object, call_id: str = "call_finish", usage: dict[str, any] | None = None
) -> MockRawResponse {
    return call("finish_tool", {"final_output": output}, call_id=call_id, usage=usage);
}


"""Raise `error` instead of answering. On a stream, `content` is delivered first and
the error fires after `after` of its chunks: `fail(err, content="partial", after=1)`."""
def fail(error: Exception, content: str = "", after: int = 0) -> MockError {
    return MockError(error=error, content=content, after=after);
}


"""Tool names as the model would see them in one recorded params dict."""
def tool_names(params: dict[str, any]) -> list[any] {
    return [t["function"]["name"] for t in (params.get("tools") or [])];
}


"""One streamed text chunk, as litellm delivers it."""
def text_chunk(text: str, model: str = "fake") -> object {
    import litellm;
    return litellm.ModelResponseStream(
        id="chunk",
        object="chat.completion.chunk",
        created=1,
        model=model,
        choices=[{"index": 0, "delta": {"content": text}, "finish_reason": None}]
    );
}


"""Serve `replies` from a real `Model` (or any BaseLLM) by swapping its network calls
for a MockLLM's, so the model's own request shaping stays real."""
obj Scripted {
    has model: BaseLLM,
        replies: list[any],
        chunk_size: int = 12,
        _patches: list[any] = [];

    def __enter__ -> MockLLM {
        fake = MockLLM(
            model_name=self.model.model_name,
            outputs=list(self.replies),
            chunk_size=self.chunk_size
        );
        for name in [
            "model_call_no_stream",
            "model_call_with_stream",
            "model_call_no_stream_async",
            "model_call_with_stream_async"
        ] {
            patch = mock.patch.object(self.model, name, getattr(fake, name));
            patch.start();
            self._patches.append(patch);
        }
        return fake;
    }

    def __exit__(*_exc: any) -> bool {
        for patch in reversed(self._patches) {
            patch.stop();
        }
        self._patches = [];
        return False;
    }
}


def scripted(model: BaseLLM, replies: list[any], chunk_size: int = 12) -> Scripted {
    return Scripted(model=model, replies=replies, chunk_size=chunk_size);
}


"""Clear the id and name on a streamed chunk's tool-call fragments."""
def _drop_call_names(chunk: any) {
    for choice in chunk.choices {
        for fragment in choice.delta.tool_calls or [] {
            fragment.id = None;
            fragment.function.name = None;
        }
    }
}


"""A stream carrying litellm's `logging_obj`, as its CustomStreamWrapper does."""
obj LoggedStream {
    has chunks: Iterable[object],
        logging_obj: object;

    def __iter__ -> Iterator[object] {
        return iter(self.chunks);
    }
}


"""A MockLLM for the provider details a reply queue cannot express.

    served_as      the model the provider reports, as after a router fallback
    logging_obj    carried on every stream, as litellm's CustomStreamWrapper does
    breaks[n]      raised once call n's chunks are out: a stream dropped mid-reply
    unnamed_args   streamed tool-call fragments carry arguments but no id or name
"""
obj ProviderLLM(MockLLM) {
    has served_as: str = "",
        logging_obj: object | None = None,
        breaks: dict[int, Exception] = {},
        unnamed_args: bool = False;

    override def model_call_no_stream(params: dict[str, any]) -> object {
        reply = super.model_call_no_stream(params);
        if self.served_as {
            setattr(reply, "model", self.served_as);
        }
        return reply;
    }

    override def model_call_with_stream(
        params: dict[str, any]
    ) -> Generator[object, None, None] {
        stream = self._served_stream(params, len(self.seen));
        if self.logging_obj is not None {
            wrapped: any = LoggedStream(chunks=stream, logging_obj=self.logging_obj);
            return wrapped;
        }
        return stream;
    }

    def _served_stream(
        params: dict[str, any], call: int
    ) -> Generator[object, None, None] {
        for chunk in super.model_call_with_stream(params) {
            if self.served_as {
                setattr(chunk, "model", self.served_as);
            }
            if self.unnamed_args {
                _drop_call_names(chunk);
            }
            yield chunk;
        }
        failure = self.breaks.get(call);
        if failure is not None {
            raise failure;
        }
    }
}


"""An MTRuntime with sane defaults. Plain callables in `tools` are wrapped, and a
finish tool is appended whenever tools are given unless `finish` says otherwise."""
def mk_run(
    resp_type: type = str,
    tools: list[any] | None = None,
    stream: bool = False,
    call_params: dict[str, any] | None = None,
    messages: list[any] | None = None,
    finish: bool | None = None
) -> MTRuntime {
    wrapped: list[any] = [
        t if isinstance(t, Tool) else Tool(func=t) for t in (tools or [])
    ];
    if finish if finish is not None else bool(wrapped) {
        wrapped.append(Tool.make_finish_tool(resp_type));
    }
    msgs = messages
        if messages is not None
        else [
            Message(role=MessageRole.SYSTEM, content="You are an agent."),
            Message(role=MessageRole.USER, content="Do the thing.")
        ];
    return MTRuntime(
        messages=msgs,
        resp_type=resp_type,
        stream=stream,
        tools=wrapped,
        call_params=dict(call_params or {}),
        mtir=None
    );
}


"""The path of the fixture file or directory `name`."""
def fixture_path(name: str) -> str {
    return os.path.join(FIXTURE_DIR, name);
}


"""Import fixture module `name`. Imports are cached, so tests that load one share it."""
def load_fixture(name: str) -> any {
    return Jac.jac_import(name, base_path=FIXTURE_DIR + "/")[0];
}


"""A write-only text sink that keeps what it is given, for a log handler."""
obj _Lines {
    has lines: list[str] = [];

    def write(text: str) {
        self.lines.append(text);
    }

    def flush {}
}


"""Collect std `logging` records at or above `level` from logger `name` (root by default)."""
obj LogCapture {
    has level: int = logging.DEBUG,
        name: str = "",
        sink: _Lines | None = None,
        _handler: logging.Handler | None = None,
        _logger: logging.Logger | None = None,
        _prev_level: int = 0;

    def __enter__ -> LogCapture {
        self.sink = _Lines();
        level: any = self.level;
        handler = logging.StreamHandler(self.sink);
        handler.setLevel(level);
        handler.setFormatter(logging.Formatter("%(levelname)s %(message)s"));
        target = logging.getLogger(self.name);
        self._prev_level = target.level;
        target.addHandler(handler);
        target.setLevel(level);
        self._handler = handler;
        self._logger = target;
        return self;
    }

    def __exit__(*_exc: any) -> bool {
        if self._logger is not None and self._handler is not None {
            previous: any = self._prev_level;
            self._logger.removeHandler(self._handler);
            self._logger.setLevel(previous);
        }
        return False;
    }

    def text -> str {
        return "".join(self.sink.lines) if self.sink is not None else "";
    }
}


def capture_logs(level: int = logging.DEBUG, name: str = "") -> LogCapture {
    return LogCapture(level=level, name=name);
}


"""Collect loguru records at or above `level`. Sinks already installed stay installed."""
obj LoguruCapture {
    has level: str = "DEBUG",
        sink: _Lines | None = None,
        _sink_id: any = None;

    def __enter__ -> LoguruCapture {
        import from loguru { logger }
        self.sink = _Lines();
        self._sink_id = logger.add(
            self.sink.write, level=self.level, format="{level} {message}"
        );
        return self;
    }

    def __exit__(*_exc: any) -> bool {
        import from loguru { logger }
        if self._sink_id is not None {
            logger.remove(self._sink_id);
            self._sink_id = None;
        }
        return False;
    }

    def text -> str {
        return "".join(self.sink.lines) if self.sink is not None else "";
    }
}


def capture_loguru(level: str = "DEBUG") -> LoguruCapture {
    return LoguruCapture(level=level);
}


"""The conversation sent on call `n`, as the model saw it."""
def sent_messages(llm: MockLLM, n: int = 0) -> list[dict[str, any]] {
    return llm.sent("messages")[n];
}


"""The role of each message sent on call `n`, in order.

    assert roles(llm) == ["system", "user"];
"""
def roles(llm: MockLLM, n: int = 0) -> list[str] {
    return [m["role"] for m in sent_messages(llm, n)];
}


"""The content blocks of the user turn of call `n`.

A multimodal request lands its argument, image or video frames here. A text-only
request is normalised to one text block, so callers can treat both alike.
"""
def user_blocks(llm: MockLLM, n: int = 0) -> list[dict[str, any]] {
    content = sent_messages(llm, n)[1]["content"];
    return content
        if isinstance(content, list)
        else [{"type": "text", "text": content}];
}


"""Just the inlined media of the user turn of call `n`, in order."""
def media_blocks(llm: MockLLM, n: int = 0) -> list[dict[str, any]] {
    return [
        b
        for b in user_blocks(llm, n)
        if b.get("type") == "image_url"
    ];
}


"""The data url carried by one media block."""
def data_url(block: dict[str, any]) -> str {
    return block["image_url"]["url"];
}


"""Skip the calling test when an optional dependency is absent.

    need("PIL", "Pillow");
"""
def need(module: str, package: str = "") {
    import importlib;
    try {
        importlib.import_module(module);
    } except ImportError {
        testskip(f"This test requires {package or module} to be installed");
    }
}


"""Skip the calling test unless `path` compiles into the runtime's own program.

A file inside the jaclang package compiles into the compiler's program instead, so the
MTIR it registers never reaches `JacRuntime.program`. CI runs such tests from a copy.
"""
def need_outside_jaclang(path: str) {
    import from jaclang.runtime.runtime { JacRuntime }
    program = JacRuntime.get_program();
    if JacRuntime.get_selfhost().resolve(path, program) is not program {
        testskip(
            "this fixture compiles into the compiler's own program here; "
            "run from a copy outside the jaclang tree, as CI does"
        );
    }
}


"""The whole conversation of call `n` as one string, for `in` assertions.

Use it to ask whether something reached the model at all. For questions about
structure use roles(), user_blocks() or media_blocks() instead.
"""
def prompt_text(llm: MockLLM, n: int = 0) -> str {
    return str(sent_messages(llm, n));
}


"""Drain a `logging=True` stream, checking every item is a StreamEvent."""
def stream_events(stream: any) -> list[StreamEvent] {
    out: list[StreamEvent] = [];
    for e in stream {
        assert isinstance(e, StreamEvent) , (
            f"a logging stream yields StreamEvent, got {type(e).__name__}"
        );
        out.append(e);
    }
    return out;
}


"""The events of one type, in order."""
def events_of(events: list[StreamEvent], kind: str) -> list[StreamEvent] {
    return [
        e
        for e in events
        if e.event_type == kind
    ];
}


"""The event types in order, for ordering assertions."""
def event_types(events: list[StreamEvent]) -> list[str] {
    return [e.event_type for e in events];
}


"""The text delivered on the chunk channel, reassembled."""
def chunk_text(events: list[StreamEvent]) -> str {
    return "".join([e.data.get("content", "") for e in events_of(events, "chunk")]);
}

"""The candidate handles offered in a routing prompt, with the line each sits on.

Candidates are rendered as `Handle) <description>` lines under a "Candidates"
heading. Handles are generated from the candidate set: two `Agent` siblings become
`Agent_alpha` and `Agent_beta`, a lone one stays `Agent`. Read them, do not write
them.
"""
def routing_candidates(params: dict[str, any]) -> list[tuple[str, str]] {
    import re;
    out: list[tuple[str, str]] = [];
    seen_heading = False;
    for line in str(params.get("messages")).replace("\\n", "\n").split("\n") {
        if line.lstrip().startswith("Candidates") {
            seen_heading = True;
            continue;
        }
        if seen_heading {
            m = re.match(r"\s*([A-Za-z0-9_]+)\)\s*(.*)", line);
            if m {
                out.append((m.group(1), m.group(2)));
            }
        }
    }
    return out;
}


"""A model that reads a routing prompt and answers with the handles `pick` chooses.

`pick(candidates, prompt)` takes the candidate list from routing_candidates() and
the prompt they came from, and returns the handles to visit.

    RoutingLLM(pick=lambda (c: list[tuple[str, str]], p: str) { [x[0] for x in c if "high" in x[1]]; });

A graph whose nodes also make their own `by llm()` calls sends both kinds through
one model, so a prompt with no candidates falls through to the scripted replies.
"""
obj RoutingLLM(MockLLM) {
    has pick: Callable = lambda (c: list[tuple[str, str]], p: str) { [c[0][0]]
        if c
        else []; };

    override def model_call_no_stream(params: dict[str, any]) -> object {
        self._queue_route(params);
        return super.model_call_no_stream(params);
    }

    override def model_call_with_stream(
        params: dict[str, any]
    ) -> Generator[object, None, None] {
        self._queue_route(params);
        for chunk in super.model_call_with_stream(params) {
            yield chunk;
        }
    }

    """Put this call's routing answer at the head of the queue. A prompt with no
    candidates is one of the graph's own `by llm()` calls and takes the next output."""
    def _queue_route(params: dict[str, any]) {
        candidates = routing_candidates(params);
        if candidates {
            self._current_queue().insert(
                0, self.pick(candidates, str(params.get("messages")))
            );
        }
    }
}
