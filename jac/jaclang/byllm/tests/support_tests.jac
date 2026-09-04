"""The one fake model for the byLLM suite.

A test scripts what the model says, turn by turn, and every real dispatch path
in BaseLLM runs unchanged: only `model_call_no_stream` and
`model_call_with_stream` (and their async twins on `Model`) are replaced.
Streams are real litellm chunk objects, so `stream_chunk_builder`, usage, and
cost attach exactly as they do in production.

    llm = FakeLLM(replies=[call("lookup", {"q": "x"}), say("done")]);
    def task(q: str) -> str by llm(tools=[lookup]);
    assert task("x") == "done";
    assert llm.sent("tools")[0] is not None;

For a real `Model` (provider quirks, api-key resolution) wrap it instead:

    with scripted(model, [say("hi")]) as script { ... script.seen ... }

The file is not collected as a suite: it has no `test_` prefix by design.
"""

import contextlib;
import io;
import logging;
import os;
import types;
import litellm;
import from typing { Generator }
import from unittest { mock }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.byllm.llm { BaseLLM }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole, Tool }

glob FIXTURE_DIR: str = os.path.join(os.path.dirname(__file__), "fixtures"),
     TOKENS: dict = {
         "prompt_tokens": 100,
         "completion_tokens": 20,
         "total_tokens": 120
     };


"""One scripted model turn. `tool_calls` holds (call_id, name, arguments_json)."""
obj Reply {
    has content: str = "",
        tool_calls: list = [],
        finish_reason: str = "",
        usage: dict | None = None,
        error: Exception | None = None,
        error_after: int = 0;

    def reason -> str {
        if self.finish_reason {
            return self.finish_reason;
        }
        return "tool_calls" if self.tool_calls else "stop";
    }
}


def say(content: str, usage: dict | None = None, finish_reason: str = "") -> Reply {
    return Reply(content=content, usage=usage, finish_reason=finish_reason);
}


"""A single tool call; `args` may be a dict or an already-encoded JSON string."""
def call(
    name: str,
    args: dict | str | None = None,
    call_id: str = "",
    usage: dict | None = None,
    finish_reason: str = ""
) -> Reply {
    return calls(
        [(name, args if args is not None else {}, call_id)],
        usage=usage,
        finish_reason=finish_reason
    );
}


"""Several tool calls in one turn; each entry is (name, args) or (name, args, id)."""
def calls(entries: list, usage: dict | None = None, finish_reason: str = "") -> Reply {
    import json;
    out: list = [];
    for (i, spec) in enumerate(entries) {
        name = spec[0];
        args = spec[1];
        call_id = spec[2] if len(spec) > 2 and spec[2] else f"call_{i + 1}";
        encoded = args if isinstance(args, str) else json.dumps(args);
        out.append((call_id, name, encoded));
    }
    return Reply(tool_calls=out, usage=usage, finish_reason=finish_reason);
}


def finish(output: object, call_id: str = "call_finish") -> Reply {
    return call("finish_tool", {"final_output": output}, call_id=call_id);
}


"""Raise `error` instead of answering. On a stream, `content` is delivered
first and the error fires after `after` of its chunks, so a mid-stream drop is
`fail(err, content="partial text", after=1)`."""
def fail(error: Exception, content: str = "", after: int = 0) -> Reply {
    return Reply(content=content, error=error, error_after=after);
}


def _tool_call_dicts(reply: Reply) -> list {
    return [
        {
            "id": call_id,
            "type": "function",
            "function": {"name": name, "arguments": arguments}
        } for (call_id, name, arguments) in reply.tool_calls
    ];
}


"""The completion `model_call_no_stream` returns, as a real litellm ModelResponse.
Usage is omitted, not empty, when the reply carries none: litellm turns an empty
dict into a zero-token Usage, which production never sends."""
def response(reply: Reply, model: str = "gpt-4o-mini") -> object {
    payload: dict = {
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": reply.content,
                    "tool_calls": _tool_call_dicts(reply)
                },
                "finish_reason": reply.reason()
            }
        ]
    };
    if reply.usage {
        payload["usage"] = dict(reply.usage);
    }
    return litellm.ModelResponse(**payload);
}


def _chunk(
    model: str, delta: dict, finish_reason: str | None = None, usage: dict | None = None
) -> object {
    payload: dict = {
        "id": "chunk",
        "object": "chat.completion.chunk",
        "created": 1,
        "model": model,
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}]
    };
    if usage {
        payload["usage"] = usage;
    }
    return litellm.ModelResponseStream(**payload);
}


"""A usage-only chunk with no choices, which is how OpenAI ends a stream when
`include_usage` is set (and the product sets it on every stream)."""
def _usage_chunk(model: str, usage: dict) -> object {
    return litellm.ModelResponseStream(
        **{
            "id": "chunk",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": model,
            "choices": [],
            "usage": usage
        }
    );
}


"""The stream `model_call_with_stream` yields for `reply`, as real litellm chunks.
Usage arrives on a trailing empty-choices chunk, as it does from OpenAI."""
def chunks(reply: Reply, model: str = "gpt-4o-mini", size: int = 12) -> list {
    out: list = [];
    first = True;
    text = reply.content;
    for i in range(0, len(text), size) {
        delta: dict = {"content": text[i:i + size]};
        if first {
            delta["role"] = "assistant";
        }
        out.append(_chunk(model, delta));
        first = False;
    }
    for (index, (call_id, name, arguments)) in enumerate(reply.tool_calls) {
        pieces = [arguments[i:i + size] for i in range(0, len(arguments), size)]
            or [""];
        for (n, piece) in enumerate(pieces) {
            frag: dict = {"index": index, "function": {"arguments": piece}};
            if n == 0 {
                frag["id"] = call_id;
                frag["type"] = "function";
                frag["function"]["name"] = name;
            }
            delta = {"tool_calls": [frag]};
            if first {
                delta["role"] = "assistant";
            }
            out.append(_chunk(model, delta));
            first = False;
        }
    }
    out.append(_chunk(model, {}, reply.reason()));
    if reply.usage {
        out.append(_usage_chunk(model, reply.usage));
    }
    return out;
}


"""Serves scripted replies in order and records every outgoing params dict."""
obj Script {
    has replies: list = [],
        seen: list = [],
        model: str = "gpt-4o-mini",
        chunk_size: int = 12;

    def next_reply(params: dict) -> Reply {
        self.seen.append(params);
        if not self.replies {
            raise AssertionError(
                f"FakeLLM has no scripted reply for call {len(self.seen)}"
            );
        }
        return self.replies.pop(0);
    }

    def no_stream(params: dict) -> object {
        reply = self.next_reply(params);
        if reply.error is not None {
            raise reply.error;
        }
        return response(reply, params.get("model") or self.model);
    }

    def with_stream(params: dict) -> Generator[object, None, None] {
        reply = self.next_reply(params);
        stream = chunks(reply, params.get("model") or self.model, self.chunk_size);
        for (i, chunk) in enumerate(stream) {
            if reply.error is not None and i >= reply.error_after {
                raise reply.error;
            }
            yield chunk;
        }
        if reply.error is not None {
            raise reply.error;
        }
    }

    async def no_stream_async(params: dict) -> object {
        return self.no_stream(params);
    }

    async def _astream(params: dict) -> any {
        for chunk in self.with_stream(params) {
            yield chunk;
        }
    }

    async def with_stream_async(params: dict) -> any {
        return self._astream(params);
    }

    def sent(key: str) -> list {
        return [p.get(key) for p in self.seen];
    }

    def exhausted -> bool {
        return not self.replies;
    }
}


"""Tool names as the model would see them in one recorded params dict."""
def tool_names(params: dict) -> list {
    return [t["function"]["name"] for t in (params.get("tools") or [])];
}


obj FakeLLM(BaseLLM) {
    has model_name: str = "gpt-4o-mini",
        replies: list = [],
        seen: list = [],
        chunk_size: int = 12,
        script: Script = Script();

    def postinit {
        self.script = Script(
            replies=list(self.replies),
            seen=self.seen,
            model=self.model_name,
            chunk_size=self.chunk_size
        );
    }

    override def model_call_no_stream(params: dict) -> object {
        return self.script.no_stream(params);
    }

    override def model_call_with_stream(params: dict) -> Generator[object, None, None] {
        return self.script.with_stream(params);
    }

    def sent(key: str) -> list {
        return self.script.sent(key);
    }

    def exhausted -> bool {
        return self.script.exhausted();
    }
}


"""Patch a real `Model` (or any BaseLLM) to serve `replies` on all dispatch paths."""
obj Scripted {
    has model: BaseLLM,
        replies: list,
        chunk_size: int = 12,
        script: Script | None = None,
        _patches: list = [];

    def __enter__ -> Script {
        script = Script(
            replies=list(self.replies),
            model=self.model.model_name,
            chunk_size=self.chunk_size
        );
        self.script = script;
        targets = [
            ("model_call_no_stream", script.no_stream),
            ("model_call_with_stream", script.with_stream),
            ("model_call_no_stream_async", script.no_stream_async),
            ("model_call_with_stream_async", script.with_stream_async)
        ];
        for (name, fn) in targets {
            patch = mock.patch.object(self.model, name, fn);
            patch.start();
            self._patches.append(patch);
        }
        return script;
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
