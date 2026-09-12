"""Shared helpers for the byLLM suite.

Tests fake the model with `MockLLM`, which replaces only the network call, so byLLM
builds the real request and parses the reply. The builders below script its turns:

    llm = MockLLM(outputs=[call("lookup", {"q": "x"}), say("done")]);
    def task(q: str) -> str by llm(tools=[lookup]);
    assert task("x") == "done";
    assert llm.sent("tools")[0] is not None;

A typed answer is queued as the value itself, and `MockLLM` sends it in the envelope
the parser expects. For a real `Model` (provider quirks, api-key resolution):

    with scripted(model, [say("hi")]) as llm { ... llm.seen ... }

The file is not collected as a suite: it has no `test_` prefix by design.
"""

import contextlib;
import io;
import logging;
import os;
import types;
import from typing { Generator }
import from unittest { mock }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.byllm.llm { BaseLLM }
import from jaclang.byllm.lib { MockLLM, MockToolCall, MockRawResponse, MockError }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole, StreamEvent, Tool }

glob FIXTURE_DIR: str = os.path.join(os.path.dirname(__file__), "fixtures"),
     TOKENS: dict = {
         "prompt_tokens": 100,
         "completion_tokens": 20,
         "total_tokens": 120
     };


"""Model text; `finish_reason="length"` makes it a truncated turn."""
def say(
    content: str, usage: dict | None = None, finish_reason: str = ""
) -> MockRawResponse {
    return MockRawResponse(content=content, usage=usage, finish_reason=finish_reason);
}


"""A single tool call; `args` may be a dict or an already-encoded JSON string."""
def call(
    name: str,
    args: dict | str | None = None,
    call_id: str = "",
    usage: dict | None = None,
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
    entries: list, usage: dict | None = None, finish_reason: str = ""
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


def finish(output: object, call_id: str = "call_finish") -> MockRawResponse {
    return call("finish_tool", {"final_output": output}, call_id=call_id);
}


"""Raise `error` instead of answering. On a stream, `content` is delivered first and
the error fires after `after` of its chunks: `fail(err, content="partial", after=1)`."""
def fail(error: Exception, content: str = "", after: int = 0) -> MockError {
    return MockError(error=error, content=content, after=after);
}


"""Tool names as the model would see them in one recorded params dict."""
def tool_names(params: dict) -> list {
    return [t["function"]["name"] for t in (params.get("tools") or [])];
}


"""Serve `replies` from a real `Model` (or any BaseLLM) by swapping its network calls
for a MockLLM's, so the model's own request shaping stays real."""
obj Scripted {
    has model: BaseLLM,
        replies: list,
        chunk_size: int = 12,
        _patches: list = [];

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


def scripted(model: BaseLLM, replies: list, chunk_size: int = 12) -> Scripted {
    return Scripted(model=model, replies=replies, chunk_size=chunk_size);
}


"""An MTRuntime with sane defaults. Plain callables in `tools` are wrapped, and a
finish tool is appended whenever tools are given unless `finish` says otherwise."""
def mk_run(
    resp_type: type = str,
    tools: list | None = None,
    stream: bool = False,
    call_params: dict | None = None,
    messages: list | None = None,
    finish: bool | None = None
) -> MTRuntime {
    wrapped: list = [t if isinstance(t, Tool) else Tool(func=t) for t in (tools or [])];
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


def load_fixture(name: str) -> any {
    return Jac.jac_import(name, base_path=FIXTURE_DIR + "/")[0];
}


"""Import a fixture program and return what it printed."""
def run_fixture(name: str) -> str {
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        Jac.jac_import(name, base_path=FIXTURE_DIR + "/");
    }
    return buf.getvalue();
}


"""Collect every log record at or above `level` from logger `name` (root by default)."""
obj LogCapture {
    has level: int = logging.DEBUG,
        name: str = "",
        buf: io.StringIO | None = None,
        _handler: logging.Handler | None = None,
        _logger: logging.Logger | None = None,
        _prev_level: int = 0;

    def __enter__ -> LogCapture {
        self.buf = io.StringIO();
        handler = logging.StreamHandler(self.buf);
        handler.setLevel(self.level);
        handler.setFormatter(logging.Formatter("%(levelname)s %(message)s"));
        target = logging.getLogger(self.name);
        self._prev_level = target.level;
        target.addHandler(handler);
        target.setLevel(self.level);
        self._handler = handler;
        self._logger = target;
        return self;
    }

    def __exit__(*_exc: any) -> bool {
        if self._logger is not None and self._handler is not None {
            self._logger.removeHandler(self._handler);
            self._logger.setLevel(self._prev_level);
        }
        return False;
    }

    def text -> str {
        return self.buf.getvalue() if self.buf is not None else "";
    }
}


def capture_logs(level: int = logging.DEBUG, name: str = "") -> LogCapture {
    return LogCapture(level=level, name=name);
}


"""The conversation sent on call `n`, as the model saw it."""
def sent_messages(llm: MockLLM, n: int = 0) -> list {
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
def user_blocks(llm: MockLLM, n: int = 0) -> list {
    content = sent_messages(llm, n)[1]["content"];
    return content
        if isinstance(content, list)
        else [{"type": "text", "text": content}];
}


"""Just the inlined media of the user turn of call `n`, in order."""
def media_blocks(llm: MockLLM, n: int = 0) -> list {
    return [
        b
        for b in user_blocks(llm, n)
        if b.get("type") == "image_url"
    ];
}


"""The data url carried by one media block."""
def data_url(block: dict) -> str {
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

"""The whole conversation of call `n` as one string, for `in` assertions.

Use it to ask whether something reached the model at all. For questions about
structure use roles(), user_blocks() or media_blocks() instead.
"""
def prompt_text(llm: MockLLM, n: int = 0) -> str {
    return str(sent_messages(llm, n));
}


"""Drain a `logging=True` stream, checking every item is a StreamEvent."""
def stream_events(stream: any) -> list {
    out: list = [];
    for e in stream {
        assert isinstance(e, StreamEvent) , (
            f"a logging stream yields StreamEvent, got {type(e).__name__}"
        );
        out.append(e);
    }
    return out;
}


"""The events of one type, in order."""
def events_of(events: list, kind: str) -> list {
    return [
        e
        for e in events
        if e.event_type == kind
    ];
}


"""The event types in order, for ordering assertions."""
def event_types(events: list) -> list[str] {
    return [e.event_type for e in events];
}


"""The text delivered on the chunk channel, reassembled."""
def chunk_text(events: list) -> str {
    return "".join([e.data.get("content", "") for e in events_of(events, "chunk")]);
}

"""The candidate handles offered in a routing prompt, with the line each sits on.

Candidates are rendered as `Handle) <description>` lines under a "Candidates"
heading. Handles are generated from the candidate set: two `Agent` siblings become
`Agent_alpha` and `Agent_beta`, a lone one stays `Agent`. Read them, do not write
them.
"""
def routing_candidates(params: dict) -> list[tuple[str, str]] {
    import re;
    out: list = [];
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

    RoutingLLM(pick=lambda (c: list, p: str) { [x[0] for x in c if "high" in x[1]]; });

A graph whose nodes also make their own `by llm()` calls sends both kinds through
one model, so a prompt with no candidates falls through to the scripted replies.
"""
obj RoutingLLM(MockLLM) {
    has pick: Callable = lambda (c: list, p: str) { [c[0][0]] if c else []; };

    override def model_call_no_stream(params: dict) -> object {
        self._queue_route(params);
        return super.model_call_no_stream(params);
    }

    override def model_call_with_stream(params: dict) -> Generator[object, None, None] {
        self._queue_route(params);
        for chunk in super.model_call_with_stream(params) {
            yield chunk;
        }
    }

    """Put this call's routing answer at the head of the queue. A prompt with no
    candidates is one of the graph's own `by llm()` calls and takes the next output."""
    def _queue_route(params: dict) {
        candidates = routing_candidates(params);
        if candidates {
            self._current_queue().insert(
                0, self.pick(candidates, str(params.get("messages")))
            );
        }
    }
}
