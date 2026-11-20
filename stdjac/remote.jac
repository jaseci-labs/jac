"""Crossings: what a call over one raises, what a call and its reply
are as they travel, and `Transport`, the interface of what carries them.

The compiler generates no server and no stub. As a module of a space starts,
each of its endpoints is handed over here (`serve_def`, `serve_walker`, which
the compiler calls there); a call over a crossing is lowered to one of
`call_def`, `call_proc` and `spawn_walker`, typed by the callee's own
signature. Both ends are written once, with compile-time reflection and
stdjac's codec: a call's arguments travel by name, and what doesn't decode as
its type is refused.

A call travels as a `Request` (a path that names the endpoint, a JSON body)
and its answer as a `Response`: a status and a JSON body, or a stream's
events as they are made. What carries the two between apps is the project's
`transport` plugin, which knows nothing of endpoints; a crossing to a space
this process runs itself (a cpython or node space a native app runs) is
carried in-process, in the same form, copied both ways."""

import json;
import os;
import from jaclang.comptime { apply, args_type, fields, params }

obj:pub RemoteError(Exception) {
    has space: str = "",
        endpoint: str = "",
        detail: str = "";

    def __str__ -> str {
        return self.detail;
    }
}

obj:pub RemoteUnavailable(RemoteError) {}

obj:pub RemoteTimeout(RemoteError) {}

obj:pub RemoteRejected(RemoteError) {}

obj:pub RemoteDecodeError(RemoteError) {}

"""An uncaught exception in the endpoint: it doesn't cross, and no stack is sent."""
obj:pub RemoteFailed(RemoteError) {}

"""Who may call an endpoint: anyone (`:pub`), a signed-in
caller (`:protect`), or the program's own code and the deployment's other
apps (an untagged declaration another space calls)."""
enum:pub Access {
    PUB,
    PROTECT,
    INTERNAL,
}

"""An endpoint of a space: a function, or a walker spawned on its caller's
root. `run` takes its arguments by name as JSON's values (a walker's fields)
and gives its result as JSON's (a walker's fields and reports); it raises
CodecError for arguments that aren't its parameters' types. A function that
gives an iterator is a stream: `items` takes its arguments as `run` does and
gives its items, each as JSON's values, as the function makes them."""
obj:pub Endpoint {
    has space: str,
        module: str,
        name: str,
        access: Access,
        is_walker: bool,
        run: Callable[[dict[str, any]], any],
        items: Callable[[dict[str, any]], Iterator[any]] | None = None;

    def path -> str {
        return endpoint_path(self.space, self.module, self.name, self.is_walker);
    }
}

"""Where endpoint `module`.`name` of `space` is served."""
def:pub endpoint_path(space: str, module: str, name: str, spawns: bool) -> str {
    return ("/__jac/spawn/" if spawns else "/__jac/call/") + space + "/" + module + "/" + name;
}

"""A request as what answers it sees it. `client` is the address it came from:
"" for one made in this process."""
obj:pub Request {
    has method: str,
        path: str,
        query: str = "",
        headers: dict[str, str] = {},
        body: bytes = b"",
        client: str = "";
}

"""A reply. One with `events` is a stream: its body is them, each sent as it
is made, and `body` is not."""
obj:pub Response {
    has status: int = 200,
        ctype: str = "application/json",
        body: bytes = b"",
        headers: dict[str, str] = {},
        events: Iterator[bytes] | None = None;
}

"""Work the thread that listens does every `every` seconds: its host's own
(a window to watch, a space run in the process)."""
obj:pub Tick {
    has name: str,
        every: float,
        run: Callable[[], None],
        next_at: float = 0.0;
}

"""An address a transport took for its program (`Transport.claim`), held so
that no other program takes it, for the transport to listen at
(`Transport.listen`). Each transport's is a class of its own, holding what it
listens with; the program hands it back and reads nothing of it."""
obj:pub Claim {}

"""Why a transport can't take an address for its program
(`Transport.claim`), in words: the system's own, where the system refused it
(`Address already in use`, `Permission denied`), else what is wrong with the
address as it is written."""
obj:pub CannotListen(Exception) {
    has reason: str;

    def __str__ -> str {
        return self.reason;
    }
}

"""What carries requests between apps: the interface of the `transport`
abstraction's plugins. It knows requests and replies, and nothing of
what they ask.

- `send` carries `r` to the app at `address`, which is the transport's own
  to read, and gives its reply: a reply with `events` for a stream, each a
  whole event as the app sent it. It waits `seconds` at most for the app to
  say something, and what listens says that a call is still being answered,
  and a stream still open, more often than a caller waits: so a call takes
  as long as it takes, and only an app that has gone silent is given up on.
  TimeoutError for that app, OSError for one that can't be reached.
- `claim` takes `address` (`host:port`; port 0, one the system picks) for
  the program, so that no other program can, and gives what it holds it
  with. It raises CannotListen where it can't: an address that is no
  address, one another program holds, one this user may not take, one that
  is not this machine's. The program claims its address before it touches
  its data (stdjac.app), so a copy that can't listen changes nothing.
- `listen` answers the requests that come to the address `claim` took with
  `handle`, each as it comes and several at once, until the program ends:
  it returns only then. It runs each of `ticks` when it is due and what
  `on_loop` is given, on the thread that called it, and tells `listening`
  the port it took.
- `on_loop` has that thread run `work`, as soon as it turns; `serving` is
  whether it listens.
- `serves_paths` is whether a request it carries may ask for any path: a
  function's own (`@restspec`), a page and its files, which a browser or
  another program's client asks for. A transport that carries calls alone
  says no, and a program that serves a path does not start with it
  (stdjac.app)."""
obj:pub Transport {
    def send(address: str, r: Request, seconds: float) -> Response abst;
    def claim(address: str) -> Claim abst;
    def listen(
        claim: Claim,
        handle: Callable[[Request], Response],
        ticks: list[Tick],
        listening: Callable[[int], None] | None,
    ) abst;
    def on_loop(work: Callable[[], None]) abst;
    def serving -> bool abst;
    def serves_paths -> bool abst;
}

"""The endpoints this program serves, by their paths."""
glob _endpoints: dict[str, Endpoint] = {};

"""A request this process makes of a space it runs itself, answered as one
from outside is: given the path, the JSON body, the caller and whether the
program's own code made it, the reply's status and body."""
glob _in_process: dict[str, Callable[[str, bytes, str, bool], tuple[int, bytes]]] = {};

"""The transport the project bound, made the first time it is asked for."""
glob _transport: list[dyn Transport] = [];

def:pub transport -> dyn Transport {
    if len(_transport) == 0 {
        t: dyn Transport = bound("transport");
        _transport.append(t);
    }
    return _transport[0];
}

"""Have the thread that listens run `work`, as soon as it turns: for what
must run on the thread the program started on, as a node space's calls must
(Node runs on the one thread that started it)."""
def:pub on_loop(work: Callable[[], None]) {
    transport().on_loop(work);
}

"""Whether this program listens: `on_loop` has a thread to ask."""
def:pub loop_serving -> bool {
    return len(_transport) > 0 and _transport[0].serving();
}

"""Serve `e`, which its module hands over as it starts."""
def serve_endpoint(e: Endpoint) {
    _endpoints[e.path()] = e;
}

"""Call endpoint `module`.`name` of `space` (spawn it, when `spawns`) with
`args`, JSON's values by name, for the caller of the call being served here:
its result, as JSON's values. A failure is one of RemoteError's."""
def call_endpoint(space: str, module: str, name: str, spawns: bool, args: dict[str, any]) -> any {
    path = endpoint_path(space, module, name, spawns);
    body = json.dumps({"fields": args} if spawns else {"args": args}).encode("utf-8");
    endpoint = module + "." + name;
    text = "";
    if space in _in_process {
        # A space this process runs: its port, for this call's caller, as
        # the program's own code.
        (_, raw) = _in_process[space](path, body, current_caller(), True);
        text = raw.decode("utf-8");
    } else {
        text = carried_reply(space, path, endpoint, body);
    }
    return reply_data(space, endpoint, text);
}

"""Call stream endpoint `module`.`name` of `space` with `args`: its items,
as JSON's values, each as the endpoint makes it. A failure, at the call or
at any item, is one of RemoteError's."""
def stream_endpoint(space: str, module: str, name: str, args: dict[str, any]) -> Iterator[any] {
    path = endpoint_path(space, module, name, False);
    body = json.dumps({"args": args}).encode("utf-8");
    if space in _in_process {
        return carried_items(space, module + "." + name, path, body);
    }
    return carried_stream(space, path, module + "." + name, body);
}

"""What reply `text` to a call of `endpoint` of `space` gives: its data, or
the RemoteError it says the call failed with."""
def reply_data(space: str, endpoint: str, text: str) -> any {
    reply: dict[str, any] = {};
    try {
        reply = json.loads(text);
    } except ValueError as e {
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
    }
    if reply.get("ok", False) {
        return reply.get("data", None);
    }
    raise reply_error(space, endpoint, reply);
}

"""The RemoteError a failed call's reply, or a stream's error event, says."""
def reply_error(space: str, endpoint: str, reply: dict[str, any]) -> RemoteError {
    detail = str(reply.get("detail", ""));
    kind = str(reply.get("kind", ""));
    if kind == "rejected" {
        return RemoteRejected(space=space, endpoint=endpoint, detail=detail);
    }
    if kind == "unavailable" {
        return RemoteUnavailable(space=space, endpoint=endpoint, detail=detail);
    }
    return RemoteFailed(space=space, endpoint=endpoint, detail=detail);
}

"""Carry the crossings to `space` in this process, through `port`."""
def:pub carry_in_process(space: str, port: Callable[[str, bytes, str, bool], tuple[int, bytes]]) {
    _in_process[space] = port;
}

"""A port carries a whole reply, so a stream crosses one as a stream its
caller pulls: the call of a stream endpoint is answered with the id it was
opened as (`{"ok": true, "stream": id}`), `/__jac/stream/<id>` gives its
next item (`{"ok": true, "data": item}`), its end (`{"ok": true, "end":
true}`) or what it failed with, and `/__jac/stream/<id>/close` closes one
its caller leaves early. The streams this process has open for its ports'
callers, each its events (events_of), and how many it has opened."""
glob _open_streams: dict[str, Iterator[bytes]] = {},
     _opened: list[int] = [0];

"""Open `events`, a stream endpoint's, for a port's caller to pull: the
reply that says so."""
def:pub open_stream(events: Iterator[bytes]) -> tuple[int, bytes] {
    _opened[0] += 1;
    id = str(_opened[0]);
    _open_streams[id] = events;
    return (200, json.dumps({"ok": True, "stream": id}).encode("utf-8"));
}

"""The reply to a pull of an open stream, or to its close: `rest` is what
follows `/__jac/stream/` in the request's path."""
def:pub pull_stream(rest: str) -> tuple[int, bytes] {
    closing = rest.endswith("/close");
    id = rest[0:len(rest) - 6] if closing else rest;
    if id not in _open_streams {
        return reply_fail(404, "rejected", "no such stream");
    }
    events = _open_streams[id];
    if closing {
        del _open_streams[id];
        events.close();
        return (200, b'{"ok": true}');
    }
    text = "";
    for frame in events {
        text = frame.decode("utf-8");
        break;
    }
    if text.startswith("data: ") {
        return (200, ('{"ok": true, "data": ' + text[6:len(text)].strip() + "}").encode("utf-8"));
    }
    del _open_streams[id];
    events.close();
    if text.startswith("event: error") {
        return (500, text[text.index("data: ") + 6:len(text)].strip().encode("utf-8"));
    }
    return (200, b'{"ok": true, "end": true}');
}

"""The id a port's reply `raw` says a stream was opened as, or "" for a
reply that is a call's whole answer."""
def stream_opened(raw: bytes) -> str {
    if not raw.startswith(b'{"ok"') or b'"stream"' not in raw[0:40] {
        return "";
    }
    try {
        reply: dict[str, any] = json.loads(raw.decode("utf-8"));
        return str(reply.get("stream", "")) if "data" not in reply else "";
    } except ValueError {
        return "";
    }
}

"""The items of stream endpoint `endpoint` of `space`, which this process
runs: pulled through its port, each as its caller asks for the next. One
its caller leaves early is closed."""
def carried_items(space: str, endpoint: str, path: str, body: bytes) -> Iterator[any] {
    port = _in_process[space];
    (_, raw) = port(path, body, current_caller(), True);
    id = stream_opened(raw);
    if id == "" {
        reply_data(space, endpoint, raw.decode("utf-8"));
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail="the reply is no stream");
    }
    ended = False;
    try {
        forever {
            (_, got) = port("/__jac/stream/" + id, b"", current_caller(), True);
            reply: dict[str, any] = {};
            try {
                reply = json.loads(got.decode("utf-8"));
            } except ValueError as e {
                raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
            }
            if not reply.get("ok", False) {
                ended = True;
                raise reply_error(space, endpoint, reply);
            }
            if reply.get("end", False) {
                ended = True;
                return;
            }
            yield reply.get("data", None);
        }
    } finally {
        if not ended {
            port("/__jac/stream/" + id + "/close", b"", current_caller(), True);
        }
    }
}

"""A request for `space`, which this process runs, carried to it, for a
server that sends a stream as it is made: the reply's status and body, or
for a stream its events, each pulled through the space's port as it is
sent."""
def:pub carry_stream(
    space: str, path: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, bytes, Iterator[bytes] | None] {
    (status, raw) = _in_process[space](path, body, caller, trusted);
    id = stream_opened(raw);
    if id == "" {
        return (status, raw, None);
    }
    return (200, b"", carried_events(space, id, caller, trusted));
}

"""The events of stream `id`, which `space`'s port has open."""
def carried_events(space: str, id: str, caller: str, trusted: bool) -> Iterator[bytes] {
    port = _in_process[space];
    ended = False;
    try {
        forever {
            (_, got) = port("/__jac/stream/" + id, b"", caller, trusted);
            reply: dict[str, any] = {};
            try {
                reply = json.loads(got.decode("utf-8"));
            } except ValueError {
                reply = {"ok": False, "kind": "failed", "detail": "the stream's reply is not JSON"};
            }
            if not reply.get("ok", False) {
                ended = True;
                yield error_event(str(reply.get("kind", "failed")), str(reply.get("detail", "")));
                return;
            }
            if reply.get("end", False) {
                ended = True;
                yield b"event: end\ndata: {}\n\n";
                return;
            }
            yield b"data: " + json.dumps(reply.get("data", None)).encode("utf-8") + b"\n\n";
        }
    } finally {
        if not ended {
            port("/__jac/stream/" + id + "/close", b"", caller, trusted);
        }
    }
}

"""Whether this process carries `space` itself."""
def:pub carried(space: str) -> bool {
    return space in _in_process;
}

"""A crossing's request of `space`, as one of the deployment's own programs
makes it: with the session it calls as and the deployment's key, where it
has them. RemoteUnavailable for a space with no address."""
def crossing_request(space: str, path: str, endpoint: str, body: bytes) -> tuple[str, Request] {
    url = remote_url(space);
    if url == "" {
        raise RemoteUnavailable(
            space=space,
            endpoint=endpoint,
            detail=f"no URL for space '{space}' (JAC_REMOTE_{space.upper()})",
        );
    }
    headers = {"content-type": "application/json"};
    token = os.environ.get("JAC_REMOTE_TOKEN", "");
    if token != "" {
        headers["authorization"] = "Bearer " + token;
    }
    key = os.environ.get("JAC_DEPLOY_KEY", "");
    if key != "" {
        headers["x-jac-key"] = key;
    }
    return (url, Request(method="POST", path=path, headers=headers, body=body));
}

"""How long a call's reply is waited for, and a stream's next event: longer
than a transport lets a stream stay silent."""
glob CALL_SECONDS: float = 30.0,
     STREAM_SECONDS: float = 60.0;

"""A crossing's request, carried by the transport: the reply's text."""
def carried_reply(space: str, path: str, endpoint: str, body: bytes) -> str {
    (url, req) = crossing_request(space, path, endpoint, body);
    try {
        return transport().send(url, req, CALL_SECONDS).body.decode("utf-8");
    } except TimeoutError as e {
        raise RemoteTimeout(space=space, endpoint=endpoint, detail=str(e));
    } except OSError as e {
        raise RemoteUnavailable(space=space, endpoint=endpoint, detail=str(e));
    }
}

"""A stream endpoint's call, carried by the transport: its items, as JSON's
values, each as its event comes. A call the app refuses raises as any call's
does, before the first item; a stream that fails raises what its error event
says where the item would have come; one cut short is RemoteUnavailable."""
def carried_stream(space: str, path: str, endpoint: str, body: bytes) -> Iterator[any] {
    (url, req) = crossing_request(space, path, endpoint, body);
    reply = Response();
    try {
        reply = transport().send(url, req, STREAM_SECONDS);
    } except TimeoutError as e {
        raise RemoteTimeout(space=space, endpoint=endpoint, detail=str(e));
    } except OSError as e {
        raise RemoteUnavailable(space=space, endpoint=endpoint, detail=str(e));
    }
    events = reply.events;
    if events is None {
        reply_data(space, endpoint, reply.body.decode("utf-8"));
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail="the reply is no stream");
    }
    try {
        forever {
            frame = b"";
            got = False;
            try {
                for one in events {
                    frame = one;
                    got = True;
                    break;
                }
            } except TimeoutError as e {
                raise RemoteTimeout(space=space, endpoint=endpoint, detail=str(e));
            } except OSError as e {
                raise RemoteUnavailable(space=space, endpoint=endpoint, detail=str(e));
            }
            if not got {
                raise RemoteUnavailable(
                    space=space, endpoint=endpoint, detail="the stream ended before its end"
                );
            }
            event = "";
            said: str | None = None;
            for line in frame.decode("utf-8").split("\n") {
                text = line.rstrip("\r");
                if text.startswith("event: ") {
                    event = text[7:len(text)];
                } elif text.startswith("data: ") {
                    said = text[6:len(text)];
                }
            }
            if said is None {
                # (A comment, which keeps the stream alive.)
                continue;
            }
            data: any = None;
            try {
                data = json.loads(said);
            } except ValueError as e {
                raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
            }
            if event == "end" {
                return;
            }
            if event == "error" {
                failed: dict[str, any] = data if isinstance(data, dict) else {};
                raise reply_error(space, endpoint, failed);
            }
            yield data;
        }
    } finally {
        events.close();
    }
}

"""A request from a served space, sent on with its caller to the app that runs the
space it's for: the reply's status and body, or, for a stream, its events as
they come (and no body). It is the outside caller's, and carries their
credential and nothing of the deployment's: no key, so the app it reaches
serves it only what it serves anyone outside."""
def:pub forward_remote(
    url: str, path: str, body: bytes, authorization: str, method: str
) -> tuple[int, bytes, Iterator[bytes] | None] {
    headers = {"content-type": "application/json"};
    if authorization != "" {
        headers["authorization"] = authorization;
    }
    try {
        reply = transport().send(
            url,
            Request(
                method=method, path=path, headers=headers, body=(body if method == "POST" else b"")
            ),
            STREAM_SECONDS,
        );
        return (reply.status, reply.body, reply.events);
    } except OSError as e {
        failed = {"ok": False, "kind": "unavailable", "detail": str(e)};
        return (503, json.dumps(failed).encode("utf-8"), None);
    }
}

# ---- the serving end: what the compiler hands each endpoint to

"""Refuse a name `given` holds that isn't a field of record type T: an
argument the endpoint has no parameter for is a mistake, never dropped."""
def refuse_unknown[T](given: dict[str, any]) {
    known: list[str] = [];
    comptime for f in fields(T) {
        known.append(f.name);
    }
    for k in given.keys() {
        if k not in known {
            raise CodecError(detail=f"no parameter '{k}'");
        }
    }
}

"""The function `f`, an endpoint of `space` (in its module `module`, named
`name`), served to callers `access` admits: its arguments decoded by name as
its parameters' types, an absent one taking its default at this call, and its
result encoded as its type. Called where
the function's module starts."""
def:pub serve_def(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                return encode(apply(f, a));
            },
        ),
    );
    return True;
}

"""serve_def for a function that gives nothing."""
def:pub serve_proc(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                apply(f, a);
                return None;
            },
        ),
    );
    return True;
}

"""serve_def for an async function, run to its end: a crossing's call is
answered when it has its result."""
def:pub serve_async_def(
    comptime f: any, space: str, module: str, name: str, access: Access
) -> bool {
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                return encode(drive(apply(f, a)));
            },
        ),
    );
    return True;
}

"""serve_proc for an async function."""
def:pub serve_async_proc(
    comptime f: any, space: str, module: str, name: str, access: Access
) -> bool {
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                drive(apply(f, a));
                return None;
            },
        ),
    );
    return True;
}

"""serve_def for a function that gives an iterator: a stream, whose items the
server sends each as the function makes it (`answer_stream`). Its arguments
decode as any endpoint's, before its first item is asked for."""
def:pub serve_stream(comptime f: any, space: str, module: str, name: str, access: Access) -> bool {
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any { return not_one_reply(name); },
            items=lambda (given: dict[str, any]) -> Iterator[any] {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                return sent_items(apply(f, a));
            },
        ),
    );
    return True;
}

"""serve_stream for an async generator, each item run to its end as an async
endpoint's result is."""
def:pub serve_async_stream(
    comptime f: any, space: str, module: str, name: str, access: Access
) -> bool {
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=False,
            run=lambda (given: dict[str, any]) -> any { return not_one_reply(name); },
            items=lambda (given: dict[str, any]) -> Iterator[any] {
                refuse_unknown[args_type(f)](given);
                a = decode[args_type(f)](given);
                return sent_async_items(apply(f, a));
            },
        ),
    );
    return True;
}

"""A stream endpoint asked for one reply: it has none."""
def not_one_reply(name: str) -> any {
    raise CodecError(detail=f"{name} is a stream: its items are read as they come");
}

"""A stream's items, each as JSON's values."""
def sent_items[T](items: Iterator[T]) -> Iterator[any] {
    for v in items {
        yield encode(v);
    }
}

"""sent_items of an async generator's."""
def sent_async_items[T](items: AsyncIterator[T]) -> Iterator[any] {
    forever {
        try {
            v = drive(items.__anext__());
        } except StopAsyncIteration {
            return;
        }
        yield encode(v);
    }
}

"""The walker W, an endpoint: its fields decoded by name, a field left out
taking its default, spawned on its caller's root (the shared one for no
caller), and given back as a remote spawn returns it: its
fields as the walk left them, and its reports."""
def:pub serve_walker[W](space: str, module: str, name: str, access: Access) -> bool {
    serve_endpoint(
        Endpoint(
            space=space,
            module=module,
            name=name,
            access=access,
            is_walker=True,
            run=lambda (given: dict[str, any]) -> any {
                refuse_unknown[W](given);
                w = decode[W](given);
                done = root spawn w;
                if declares_reports[W]() {
                    # (Its reports are one of its fields, of the type it says.)
                    return {"fields": encode[W](done)};
                }
                return {"fields": encode[W](done), "reports": json_values(done.reports)};
            },
        ),
    );
    return True;
}

"""An async endpoint's result, run to its end: a server's calls don't suspend."""
def:pub drive[R](c: Coroutine[any, any, R]) -> R {
    try {
        c.send(None);
    } except StopIteration as e {
        return e.value;
    }
    raise RuntimeError("an endpoint suspended, which this server can't resume");
}

"""What a function the server calls for its effect gave, settled: nothing, or
the coroutine of an `async def`, run to its end as an async endpoint's is.
Anything else is a TypeError."""
def:pub settle(v: any) {
    if v is None {
        return;
    }
    c: Coroutine[any, any, any] = v;
    drive(c);
}

"""A walker's reports as JSON's values. Their types are the walk's, which no
type states (`reports` is a `list[any]`): what isn't JSON's own (None, a
bool, an int, a float, a str, and lists and str-keyed dicts of them) has no
form to cross in, and is refused, never sent as its text."""
def:pub json_values(v: any) -> any {
    if v is None
        or isinstance(v, bool)
        or isinstance(v, int)
        or isinstance(v, float)
        or isinstance(v, str)
    {
        return v;
    }
    if isinstance(v, list) {
        items: list[any] = v;
        return [json_values(x) for x in items];
    }
    if isinstance(v, dict) {
        d: dict[any, any] = v;
        out: dict[str, any] = {};
        for (k, x) in d.items() {
            if not isinstance(k, str) {
                raise CodecError(detail=f"a report's dict key {k!r} isn't a str");
            }
            out[k] = json_values(x);
        }
        return out;
    }
    raise CodecError(
        detail=f"a report of a {type(v).__name__} has no JSON form: what a walker reports over a crossing is JSON's values",
    );
}

"""The endpoint crossing request `path` names and the arguments its JSON
`body` gives it, for `caller` ("" for no one), `trusted` when the program's
own code or another app of the deployment made it; or no endpoint, and the
reply that refuses the request. The endpoint's access decides first."""
def admit(path: str, body: bytes, caller: str, trusted: bool) -> tuple[Endpoint
    | None, dict[str, any], tuple[int, bytes]] {
    none: dict[str, any] = {};
    e = _endpoints.get(path, None);
    if e is None {
        return (None, none, reply_fail(404, "failed", "no such endpoint"));
    }
    if e.access == Access.INTERNAL and not trusted {
        return (None, none, reply_fail(403, "rejected", "an internal endpoint"));
    }
    if e.access == Access.PROTECT and caller == "" {
        return (None, none, reply_fail(401, "rejected", "This needs a signed-in caller."));
    }
    try {
        got: any = json.loads(body.decode("utf-8")) if len(body) > 0 else {};
        if not isinstance(got, dict) {
            return (None, none, reply_fail(400, "rejected", "the request is not a JSON object"));
        }
        held: dict[str, any] = got;
        args: any = held.get("fields" if e.is_walker else "args", {});
        if not isinstance(args, dict) {
            return (
                None,
                none,
                reply_fail(400, "rejected", "the arguments are not a JSON object of them by name"),
            );
        }
        given: dict[str, any] = args;
        return (e, given, (200, b""));
    } except ValueError {
        return (None, none, reply_fail(400, "rejected", "the request is not JSON"));
    }
}

"""What crossing request `path` asks of this program's endpoints, with
JSON `body`, answered for `caller`
("" for no one), `trusted` when the program's own code or another app of
the deployment made it: the reply's status and its JSON. The endpoint's
access decides first; then its arguments decode, or the call is rejected;
what the call changed in the graph is written when it ends. An
exception the endpoint raises doesn't cross: the caller gets RemoteFailed,
saying only that it failed."""
def:pub answer(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
    (e, given, refusal) = admit(path, body, caller, trusted);
    if e is None {
        return refusal;
    }
    return run_endpoint(e, given, caller);
}

"""`answer` for a server that sends a stream as it is made: the reply's
status and its JSON, or, for a stream endpoint whose call was admitted and
whose arguments decoded, its events (and no JSON). Each item is one `data:`
event of an event stream, its JSON; `event: end` follows the last, and
`event: error` stands where the endpoint raised, saying what a failed call's
reply says. What the stream changed in the graph is written when it ends, as
a call's is, and where it calls stdjac.graph's `commit`. The events are made
on the thread that asks for them, which is the call's from here."""
def:pub answer_stream(
    path: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, bytes, Iterator[bytes] | None] {
    (e, given, refusal) = admit(path, body, caller, trusted);
    if e is None {
        return (refusal[0], refusal[1], None);
    }
    make = e.items;
    if make is None {
        (status, reply) = run_endpoint(e, given, caller);
        return (status, reply, None);
    }
    enter_caller(caller);
    try {
        return (200, b"", events_of(e, make(given)));
    } except CodecError as c {
        (status, reply) = reply_fail(400, "rejected", f"{e.name}: {c}");
        return (status, reply, None);
    }
}

"""The events of stream endpoint `e`, whose items are `items`."""
def events_of(e: Endpoint, items: Iterator[any]) -> Iterator[bytes] {
    try {
        for v in items {
            yield b"data: " + json.dumps(v).encode("utf-8") + b"\n\n";
        }
        commit();
        yield b"event: end\ndata: {}\n\n";
    } except GeneratorExit {
        # Its reader has gone: the endpoint is closed where it paused, and
        # what it made is kept, as a call's that returned is.
        items.close();
        try {
            commit();
        } except StoreConflict as lost {
            print(f"endpoint {e.path()} kept nothing of what it made: {lost}");
        }
        raise;
    } except StoreConflict as lost {
        # (A stream's items have gone to its reader: it is not run again.)
        print(f"endpoint {e.path()} kept nothing of what it made: {lost}");
        yield error_event("conflict", f"{e.name}: what it changed, others changed first");
    } except CodecError as c {
        yield error_event("rejected", f"{e.name}: {c}");
    } except RemoteRejected as r {
        yield error_event("rejected", r.detail);
    } except Exception as x {
        print(f"endpoint {e.path()} failed: {type(x).__name__}: {x}");
        yield error_event("failed", f"{e.name} failed");
    }
}

def error_event(kind: str, detail: str) -> bytes {
    said = json.dumps({"ok": False, "kind": kind, "detail": detail});
    return b"event: error\ndata: " + said.encode("utf-8") + b"\n\n";
}

"""Run endpoint `e` for `caller` with its arguments `given`: answer's reply."""
def:pub run_endpoint(e: Endpoint, given: dict[str, any], caller: str) -> tuple[int, bytes] {
    try {
        out = kept_call(caller, lambda -> any { return e.run(given); });
        return (200, json.dumps({"ok": True, "data": out}).encode("utf-8"));
    } except StoreConflict as lost {
        print(f"endpoint {e.path()} gave way to other calls each time it ran: {lost}");
        return reply_fail(409, "conflict", f"{e.name}: what it changed, others changed first");
    } except CodecError as c {
        return reply_fail(400, "rejected", f"{e.name}: {c}");
    } except RemoteRejected as r {
        return reply_fail(401, "rejected", r.detail);
    } except Exception as x {
        print(f"endpoint {e.path()} failed: {type(x).__name__}: {x}");
        return reply_fail(500, "failed", f"{e.name} failed");
    }
}

"""The endpoint this program serves that function `module`.`name` is, if
any."""
def:pub endpoint_named(module: str, name: str) -> Endpoint | None {
    for e in _endpoints.values() {
        if e.module == module and e.name == name and not e.is_walker {
            return e;
        }
    }
    return None;
}

def reply_fail(status: int, kind: str, detail: str) -> tuple[int, bytes] {
    return (status, json.dumps({"ok": False, "kind": kind, "detail": detail}).encode("utf-8"));
}

# ---- the calling end: what the compiler lowers a call over a crossing to

"""The result of a call over a crossing, as R: what doesn't decode as the
callee's result type is the call failing (RemoteDecodeError), not a value."""
def take[R](space: str, endpoint: str, data: any) -> R {
    try {
        return decode[R](data);
    } except CodecError as e {
        raise RemoteDecodeError(space=space, endpoint=endpoint, detail=str(e));
    }
}

"""Call function `module`.`name` of `space` with `args`, its arguments given,
by name, as JSON's values: its result, an R."""
def:pub call_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R {
    return take[R](space, module + "." + name, call_endpoint(space, module, name, False, args));
}

"""call_def for a function that gives nothing."""
def:pub call_proc(space: str, module: str, name: str, args: dict[str, any]) {
    call_endpoint(space, module, name, False, args);
}

"""call_def for an async function, which a caller awaits."""
async def:pub call_async_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R {
    return take[R](space, module + "." + name, call_endpoint(space, module, name, False, args));
}

"""call_proc for an async function."""
async def:pub call_async_proc(space: str, module: str, name: str, args: dict[str, any]) {
    call_endpoint(space, module, name, False, args);
}

"""Call stream function `module`.`name` of `space` with `args`: its items,
each a T, as the function makes them. The call is made when the first item
is asked for."""
def:pub call_stream[T](space: str, module: str, name: str, args: dict[str, any]) -> Iterator[T] {
    for v in stream_endpoint(space, module, name, args) {
        yield take[T](space, module + "." + name, v);
    }
}

"""call_stream for an async generator, which a caller reads with `async for`."""
async def:pub call_async_stream[T](
    space: str, module: str, name: str, args: dict[str, any]
) -> AsyncIterator[T] {
    for v in stream_endpoint(space, module, name, args) {
        yield take[T](space, module + "." + name, v);
    }
}

"""Spawn walker `module`.`name` of `space` at its own root, with `args`, the
fields given, by name, as JSON's values: the walker as the walk left it,
copied back, its reports with it."""
def:pub spawn_walker[W](space: str, module: str, name: str, args: dict[str, any]) -> W {
    endpoint = module + "." + name;
    data: any = call_endpoint(space, module, name, True, args);
    if not isinstance(data, dict) {
        raise RemoteDecodeError(
            space=space, endpoint=endpoint, detail="a spawn's reply is no walker"
        );
    }
    got: dict[str, any] = data;
    w = take[W](space, endpoint, got.get("fields", None));
    if declares_reports[W]() {
        return w;
    }
    reports: any = got.get("reports", []);
    if not isinstance(reports, list) {
        raise RemoteDecodeError(
            space=space, endpoint=endpoint, detail="a spawn's reports are no list"
        );
    }
    items: list[any] = reports;
    for r in items {
        w.reports.append(r);
    }
    return w;
}
