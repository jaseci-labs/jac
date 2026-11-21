"""The contract of the `transport` abstraction: `Transport`, the interface of
the plugin that carries requests between apps and answers the ones that
come, and what crosses it.

A call travels as a `Request` (a path that names the endpoint, a JSON body)
and its answer as a `Response`: a status and a JSON body, or a stream's
events as they are made. A transport knows requests and replies, and nothing
of what they ask."""

import json;
import from common.contract { Host }

"""A request as what answers it sees it. `client` is the address it came from:
"" for one made in this process."""
obj Request {
    has method: str,
        path: str,
        query: str = "",
        headers: dict[str, str] = {},
        body: bytes = b"",
        client: str = "";
}

"""A reply. One with `events` is a stream: its body is them, each sent as it
is made, and `body` is not."""
obj Response {
    has status: int = 200,
        ctype: str = "application/json",
        body: bytes = b"",
        headers: dict[str, str] = {},
        events: Iterator[bytes] | None = None;
}

"""Work the thread that listens does every `every` seconds: its host's own
(a window to watch, a space run in the process)."""
obj Tick {
    has name: str,
        every: float,
        run: Callable[[], None],
        next_at: float = 0.0;
}

"""An address a transport took for its program (`Transport.claim`), held so
that no other program takes it, for the transport to listen at
(`Transport.listen`). Each transport's is a class of its own, holding what it
listens with; the program hands it back and reads nothing of it."""
obj Claim {}

"""Why a transport can't take an address for its program
(`Transport.claim`), in words: the system's own, where the system refused it
(`Address already in use`, `Permission denied`), else what is wrong with the
address as it is written."""
obj CannotListen(Exception) {
    has reason: str;

    def __str__ -> str {
        return self.reason;
    }
}

"""What carries requests between apps: the interface of the `transport`
abstraction's plugins. It knows requests and replies, and nothing of
what they ask.

- `open` is the first thing asked of it, given the program it runs in. It
  takes no address yet: `claim` does.
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
  its data, so a copy that can't listen changes nothing.
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
  says no, and a program that serves a path does not start with it."""
obj Transport {
    def open(host: dyn Host) abst;
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

"""The reply that says a request failed, in the form every reply to a call
has (`{"ok": false, "kind": ..., "detail": ...}`): what a transport answers
with when it is the one that fails a request, which the program never
saw."""
def json_fail(status: int, kind: str, detail: str) -> Response {
    return Response(
        status=status,
        body=json.dumps({"ok": False, "kind": kind, "detail": detail}).encode("utf-8"),
    );
}
