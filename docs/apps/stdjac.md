---
description: stdjac, the library of the language's abstractions that jac compiles into every app - which of its modules a program imports and what each exports, the contracts it shares with the plugins, the transport's contract, and which modules the build adds by itself.
keywords: stdjac, stdjac.remote, stdjac.graph, stdjac.codec, stdjac.plan, stdjac.app, stdjac.window, stdjac.desktop, stdjac.crossing, stdjac.cpython_space, stdjac.node_space, stdjac.jsx, stdjac.archwire, RemoteError, RemoteUnavailable, RemoteTimeout, RemoteRejected, RemoteDecodeError, RemoteFailed, transport.contract, Transport, Request, Response, Tick, Claim, CannotListen, json_fail, CodecError, jobj, grant, AccessLevel, DataError
---
# stdjac

stdjac is the library of the language's abstractions, written in Jac and shipped in jac's
`rt/stdjac/`. It holds what source says of each (`root`, a call to another space, `:protect`,
`by llm()`, `@job`), and what is the same whatever the plugin: it starts an app, hands each
request to what answers it, knows the graph's nodes and what changed, and runs a model's tools.
It holds no mechanism: where a graph is kept, who a caller is, what carries a request and which
model answers are each a [plugin](plugins.md) the project names in `jac.toml`, the standard one
where it names none.

**stdjac and a plugin meet at a contract.** Each abstraction's contract is a module of its own,
`<abstraction>.contract` in jac's `abstractions/` ([Plugins](plugins.md#the-abstractions)): the
interface a plugin implements, and the types that cross it. stdjac imports the contracts, a
plugin imports its own, and neither imports the other. A type a program names too (`Message`,
`ByEvent`, `Request`, `DataError`) is the contract's, and a program imports it from the stdjac
module that uses it, as before.

Nothing of it is generated per project; each app is its spaces' modules, stdjac's and its
plugins', and what differs between apps is the plan the build bakes in
([Building apps](building.md), `jac docs apps/building`).

A program imports a stdjac module as it imports any module, with no wire in the archwire:
`import from stdjac.server { schedule }`. Any program may import them, in an app or not.

## The modules a program imports

| Module | For | Page |
|---|---|---|
| `stdjac.server` | `@restspec`, `@schedule`, `@job` and `@limit`, a job's handle, `consume_limit` | [stdjac.server](stdjac-server.md) |
| `stdjac.remote` | The exceptions a failed crossing raises, and the `Request` a program that answers one itself is given | Below, and [Crossings](crossings.md) |
| `stdjac.graph` | A kept graph by id, and writing it: `jobj`, `remove`, `allroots`, `grant`, `commit`, `sweep`, and `StoreConflict`, what a write another's got ahead of raises | Below, and [An app's data](data.md) |
| `stdjac.codec` | Values to JSON's values and back, by their types, as a crossing sends them | Below |
| `stdjac.plan` | The program's plan and its deployment values | Below |
| `stdjac.by` | What `by` calls: the interfaces of what gives a result (`By`), of what answers as it goes (`ByStreams`) and of what chooses a walker's way (`ByChooser`) | [By and sem](../language/by-and-sem.md) |
| `stdjac.llm` | `by llm()`: a language model (an LLM) that answers a `by` function, runs its tools and streams its answer; it conforms to all three | [By and sem](../language/by-and-sem.md) |

The contracts, which a plugin imports and a program does not:

| Contract | Its interface | What else it holds | Page |
|---|---|---|---|
| `store.contract` | `Store` | `Row`, `Changed`, `Writing`, `StoreConflict` | [Plugins](plugins.md#what-a-store-is-asked) |
| `auth.contract` | `Auth` | `SignIn`, `SignInField`, `SignInAction`, `Session`, `Rejected`, `AuthHost`, `bearer_token` | [stdjac.server](stdjac-server.md#what-a-plugin-conforms-to) |
| `transport.contract` | `Transport` | `Request`, `Response`, `Tick`, `Claim`, `CannotListen`, `json_fail` | [Below](#transport) |
| `llm.contract` | `Model` | `ModelRequest`, `ModelReply`, `ModelTool`, `Message`, `Part`, `PartKind`, `Stop`, `Effort`, and `ByEvent`, `ByEventKind`, `ByUsage`, `ByError` | [By and sem](../language/by-and-sem.md) |
| `jobs.contract` | `Jobs` | `JobState`, `JobsHost` | [stdjac.server](stdjac-server.md#what-a-plugin-conforms-to) |
| `schedule.contract` | `Scheduler` | `Scheduled` | [stdjac.server](stdjac-server.md#what-a-plugin-conforms-to) |
| `limits.contract` | `Limits` | | [stdjac.server](stdjac-server.md#what-a-plugin-conforms-to) |
| `common.contract` | None: every plugin may use it | `Host`, `Secret`, `DataError` | [Plugins](plugins.md#what-a-plugin-imports) |

A browser, hermes or node space compiles a stdjac module it imports with its own modules, all of
it, so it may import only one its host can run. `stdjac.codec` is one. `stdjac.remote`,
`stdjac.graph`, `stdjac.plan` and `stdjac.server` need the native runtime, and an import of one
there is E1540 (`the module 'stdjac.plan' needs the native runtime's own definitions, which a node
space does not provide`). Such a space imports its runtime from `"@jac/runtime"` instead
([Pages](pages.md#jacruntime)).

## The modules the build adds

These are part of an app's program because of what the app is. A program never imports them:

| Module | Is |
|---|---|
| `stdjac.app` | What starts every app's program: asks the project's plugins for what carries it out, runs a job where the process was started for one, takes its address, starts the spaces of other hosts, opens the data and listens |
| `stdjac.desktop`, `stdjac.window` | A desktop app's window ([Hosts](hosts.md#desktop-apps)) |
| `stdjac.cpython_space`, `stdjac.node_space` | Running a cpython or node space in a native app's process |
| `stdjac.crossing` | What a crossing in a browser, hermes or node space is compiled to |
| `stdjac.jsx` | The names JSX gives a JavaScript host's modules: `JsxElement`, `JsxPage`, `JsxLayout`, `Ref`, `new` ([Components](components.md)) |
| `stdjac.archwire` | stdjac's own wiring |

## stdjac.remote

The exceptions of a failed crossing, each with `space`, `endpoint` (`module.name`) and `detail`,
and printing as its `detail`:

| Exception | Raised when |
|---|---|
| `RemoteError` | Never itself: the base of the others |
| `RemoteUnavailable` | The space has no URL, or nothing answers there; a stream that stopped before its end |
| `RemoteTimeout` | No reply within 30 seconds; a stream from which nothing has come for 60 |
| `RemoteRejected` | The request was refused: no key, no session, arguments that do not decode |
| `RemoteDecodeError` | The reply, or a stream's item, is not what the callee's result type says |
| `RemoteFailed` | The endpoint raised, or does not exist; a stream called on a space the process runs itself |

```jac
import from stdjac.remote { RemoteError, RemoteFailed, RemoteRejected }

with entry {
    e = RemoteRejected(
        space="api", endpoint="notes.MyNotes", detail="This needs a signed-in caller."
    );
    print(isinstance(e, RemoteError), isinstance(e, RemoteFailed));
    print(e.space, e.endpoint);
    print(e);
}
```

```output
True False
api notes.MyNotes
This needs a signed-in caller.
```

The rest of the module is what the build's code calls. Each endpoint of a space is handed over
as its module starts, with the decoding of its arguments and the encoding of its result made from
its signature at compile time; a call of another space's function is compiled to a call of this
module's, typed by the callee's signature. A function that gives an iterator is handed over as a
stream, whose items travel one by one ([Crossings](crossings.md#calling-a-stream)).

### Transport

What carries a call between apps is the project's `transport` plugin ([Plugins](plugins.md)),
which conforms to `transport.contract`'s `Transport`. It carries a `Request` and gives a
`Response`, and knows nothing of endpoints:

| Method | Is |
|---|---|
| `open(host: dyn Host)` | The first thing asked of it, given the program it runs in ([Plugins](plugins.md#what-a-plugin-imports)). It takes no address yet |
| `send(address: str, r: Request, seconds: float) -> Response` | `r` carried to the app at `address`, and its reply: one with `events` for a stream. `TimeoutError` for an app that says nothing for `seconds`, `OSError` for one that can't be reached |
| `claim(address: str) -> Claim` | `address` (`host:port`; port `0`, one the system picks) taken for the program, so that no other program can take it. `CannotListen`, with the reason, where it can't be |
| `listen(claim: Claim, handle: Callable[[Request], Response], ticks: list[Tick], listening: Callable[[int], None] \| None)` | The requests that come to the address `claim` took answered with `handle`, several at once, until the program ends. The thread that called it runs each of `ticks` when it is due, and tells `listening` the port it took |
| `on_loop(work: Callable[[], None])` | That thread runs `work`, as soon as it turns |
| `serving() -> bool` | Whether it listens |
| `serves_paths() -> bool` | Whether a request it carries may ask for any path: a function's own ([`@restspec`](server.md#a-path-of-its-own-restspec)), a page and its files |

- **An address is the transport's own to read.** `http` takes `http://host:port`; what an app's
  `[apps.<app>.remote]` and `JAC_REMOTE_<SPACE>` hold is handed to `send` as it is written.
- **An address is claimed before anything else.** A program takes its address with `claim`
  before it sets data aside, opens it or starts the spaces it runs, so a copy that can't listen
  changes nothing. `CannotListen`'s `reason` is the system's own words where the system refused
  the address (`Address already in use`), else what is wrong with it as written; the program
  says it in one line, with its own name, the address and the setting that chooses another
  ([Serving a space](server.md#the-shortest-server)).
- **A `Claim` is the transport's own.** Each transport's is a class of its own that holds what it
  listens with (`http`'s, the socket); the program hands it back to `listen` and reads nothing of
  it.
- **A call takes as long as it takes.** What listens tells the caller of a call it has not
  answered, and the reader of a stream that says nothing, that it is still there, more often
  than a caller waits: `seconds` is how long an app may be silent, never how long a call may
  run.
- **A transport that carries calls alone says so,** with `serves_paths`. A program that serves a
  function at a path of its own, or a page, does not start with it: it ends with status 1,
  saying what it serves.

| Type | Fields |
|---|---|
| `Request` | `method`, `path`, `query`, `headers: dict[str, str]` (their names lowercased), `body: bytes`, `client` (the address it came from) |
| `Response` | `status: int`, `ctype`, `body: bytes`, `headers`, `events: Iterator[bytes] \| None` (a stream's, each sent as it is made) |
| `Tick` | `name`, `every: float` (seconds), `run` |
| `Claim` | No fields of its own: a transport's subclass holds what it listens with |
| `CannotListen` | An exception: `reason: str` |

`json_fail(status: int, kind: str, detail: str) -> Response` is the reply that says a request
failed, in the form every reply to a call has: what a transport answers with when it is the one
that fails a request.

## stdjac.graph

The graph a serving app keeps, by the id each node and edge carries (`jid(x)`):

| Name | Does |
|---|---|
| `jobj(id: str) -> any` | The node or edge with that id, or `None` |
| `remove(n: Node)` | Takes `n` and its edges out of the graph |
| `allroots() -> list[Root]` | Every caller's root, never the shared one |
| `grant(n: Node, level: AccessLevel = AccessLevel.READ)` | Records a level of access to `n` (`NO_ACCESS`, `READ`, `CONNECT`, `WRITE`), kept with it |
| `commit()` | Writes what changed in the graph since it was last written, now. A server writes it when each call returns; a call that runs long, or a stream, calls this where its work so far should be kept ([An app's data](data.md#when-the-graph-is-written)) |
| `DataError` | What kept data an app cannot start with is reported as: `path` and `problem`. It is `common.contract`'s, which a plugin raises |

They work in any program; in one that keeps no graph, they see the program's own, and `commit()`
does nothing:

```jac
import from stdjac.graph { allroots, commit, jobj, remove }

node Note {
    has text: str;
}

with entry {
    n = Note(text="milk");
    root ++> n;
    commit();
    print(jobj(jid(n)) is n, len(allroots()));
    remove(n);
    print(jobj(jid(n)), len([root --> [?:Note]]));
}
```

```output
True 0
None 0
```

`allroots()` is empty there: a program that serves no one has no callers' roots. See
[An app's data](data.md) for roots, ids and when the graph is written, and
[root](../language/root.md) (`jac docs root.shared`).

## stdjac.codec

`encode(v)` turns a value into JSON's values by its declared type, and `decode[T](v)` turns them
back into a `T`, as a crossing sends arguments and results
([Crossings](crossings.md#what-crosses-and-in-what-form)):

```jac
import json;
import from stdjac.codec { CodecError, decode, encode }

enum Size {
    SMALL,
    LARGE,
}

obj Item {
    has name: str,
        size: Size = Size.SMALL,
        tags: set[str] = set(),
        counts: dict[int, int] = {},
        blob: bytes = b"";
}

with entry {
    it = Item(name="cup", size=Size.LARGE, tags={"x"}, counts={1: 2}, blob=b"\x01\xff");
    v = encode(it);
    print(json.dumps(v));
    back = decode[Item](json.loads(json.dumps(v)));
    print(back.name, back.size, back.tags, back.counts, back.blob);
    try {
        decode[Item]({"name": 3});
    } except CodecError as e {
        print("CodecError:", e);
    }
    try {
        decode[int]("12");
    } except CodecError as e {
        print("CodecError:", e);
    }
}
```

```output
{"name": "cup", "size": "LARGE", "tags": ["x"], "counts": [[1, 2]], "blob": "01ff"}
cup Size.LARGE {'x'} {1: 2} b'\x01\xff'
CodecError: .name: expected a str, got 3
CodecError: expected an int, got '12'
```

Decoding is strict: a value of the wrong JSON type raises `CodecError` with the path to it, and is
never coerced:

| Decoding | Gives |
|---|---|
| `decode[float](3)` | `3.0`: an int is taken for a `float` |
| `decode[int](3.9)`, `decode[int](True)`, `decode[int]("12")` | `CodecError: expected an int, got 3.9` |
| `decode[tuple[int, str]]([1, "a", 2])` | `CodecError: expected 2 items, got 3`: a fixed tuple takes exactly its length |
| `decode[tuple[str, ...]](["a", "b", "c"])` | `('a', 'b', 'c')` |
| `decode[dict[int, str]]([[1, "a"]])` | `{1: 'a'}` |
| `decode[complex]([1.0, 2.0])` | `(1+2j)` |
| `decode[Tweet \| None](None)` | `None` |
| `decode[Tweet]({"text": "hi"})`, with `likes: int` and no default | `CodecError: missing field 'likes'` |
| `decode[Spot]({"v": 2})`, `Spot` a node | A new node, with an id of its own |
| `decode[Spot]({"v": 2, "__jid": "nope"})` | `CodecError: .__jid: expected a jid, got 'nope'` |

A node encodes with its id as `__jid`, and decodes as a copy that has that id.

## stdjac.plan

What the build baked into the program ([Building apps](building.md#deployment-values)):

| Name | Gives |
|---|---|
| `plan() -> AppPlan` | The plan: `app`, `spaces`, `pages`, `remotes`, `window`, `data_dir` and the rest. Outside an app's build, an empty one. In an app whose artifact holds several arrangements it is the plan of the one this run is: `arrangement` is its name, `arrangements` all of them, and `chosen` whether it was chosen ([Building apps](building.md#several-arrangements-in-one-artifact)) |
| `keep_arrangement(name: str)` | Chooses the arrangement the app is the next time it starts. `ValueError` for a name that is none of its arrangements |
| `remote_url(space: str) -> str` | Where a space the program reaches is: `JAC_REMOTE_<SPACE>`, else the baked URL, else `""` |
| `env_name(app: str, what: str) -> str` | The environment variable for `what` of `app` |

```jac
import from stdjac.plan { env_name, plan, remote_url }

with entry {
    print(env_name("my-site", "LISTEN"));
    print(repr(plan().app), plan().spaces);
}
```

```output
JAC_MY_SITE_LISTEN
'' []
```
