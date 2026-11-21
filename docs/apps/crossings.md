---
description: Calling a function or walker of another space - what a crossing is, reading a stream, who may call, what crosses and how, how it fails, and where a remote space is.
keywords: crossings, cross-space call, endpoint, remote space, JAC_DEPLOY_KEY, JAC_REMOTE_TOKEN, JAC_REMOTE_<SPACE>, apps.remote
---
# Crossings

A crossing is a call from a module of one space to a function or a walker of another. It is written
as any call is. The compiler knows which space each module is in ([the archwire](archwire.md)), so
it knows which calls cross, and makes each one a request to the space that has the callee.

A crossing is never declared. It is a `++>` wire in `graph import` whose two ends are in different
spaces:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer service { notes; }
    layer client { client; }
}

graph spaces {
    space api: native { notes; }
    space cli: native { entry client; }

    app api { run api; }
    app cli { run cli; }
}

graph import {
    edge Calls: service --> client;

    notes ++> client { AddNote, greet }
}
```

`notes.jac`, in the space `api`:

```jac
node Note {
    has text: str;
}

def:pub greet(name: str, punct: str = "!") -> str {
    return "hello " + name + punct;
}

walker:pub AddNote {
    has text: str;

    can add with Root entry {
        here ++> Note(text=self.text);
        report [n.text for n in [here --> [?:Note]]];
    }
}
```

`client.jac`, in the space `cli`:

<!-- example: not checked: its names come from another space through the archwire's wires -->
```jac
import from stdjac { RemoteError }

with entry {
    try {
        print(greet("amy"));
        print(greet(name="amy", punct="?"));
        print((root spawn AddNote(text="from the cli")).reports);
    } except RemoteError as e {
        print("failed:", e.space, e.endpoint, e.detail);
    }
}
```

With the `api` app running and `JAC_REMOTE_API` giving its address, the `cli` app prints:

```text
hello amy!
hello amy?
[['from the cli']]
```

## What can cross

Only functions and walkers are called across spaces. Everything else a wire could carry stays on
one side:

| Wired from another space | Result |
|---|---|
| A `def` | A crossing: a call of it is a request. One that gives an iterator is a [stream](#calling-a-stream) |
| A `walker` | A crossing: `root spawn W(...)` is a request |
| A `glob`, a class, an enum | Refused (E5090): put it in a module no space holds, which each side compiles in |
| A function taken as a value (`f = greet;`) | Refused (E1264): another space's function is called, never held |

The types a crossing's signature names (`Item` in `def lookup(name: str) -> Item | None`) are
declared in an unplaced module that both spaces wire in, so both sides have the same class:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer shared { types; }
    layer service { notes; }
    layer client { client; }
}

graph import {
    edge Types: shared --> service | client;
    edge Calls: service --> client;

    types ++> notes { Summary }
    types ++> client { Summary }
    notes ++> client { count_notes }
}
```

The calling module must name the type it is wired, or the wire is E1146 (`'Summary' is wired into
'client', which never uses it`). Name it where the result is kept: `s: Summary = count_notes();`.
Leaving the type's wire to the caller out altogether is E1182, which names the type and the wire
that is missing: `'Summary', which count_notes()'s signature names, is not wired into 'client':
wire it in with 'types ++> client { Summary }'`. Without the class, the caller cannot make the
result.

A module no space holds may be wired to another space's function too. It is compiled into each
program that loads it, so its call crosses from that program's space: with `svc ++> shared {
root_count }` and `shared ++> site_main { roots_now }`, a page that calls `roots_now` reaches
`svc`'s `root_count`, and the app forwards that endpoint for the page as one of its own. Since a
browser space awaits its crossings, `roots_now` is an `async def` that awaits `root_count()`.

## Calling a function

The call is checked against the callee's own signature: argument types, keywords and defaults
behave as for a local call.

What the caller gets depends on its host:

| The caller's host | A call of another space's `def` gives | A call of its `async def` gives |
|---|---|---|
| `native`, `cpython` | The result. The call blocks until the reply arrives. | A coroutine, to `await` |
| `browser`, `hermes`, `node` | A coroutine, to `await` | A coroutine, to `await` |

On a JavaScript host every crossing is awaited, because the request is asynchronous there:

<!-- example: not checked: a page is a module of a browser space, with JSX and a crossing -->
```jac
def:pub page -> JsxPage {
    has text: str = "...";

    async can with entry {
        text = await greet("jac");
    }

    return <h1>{text}</h1>;
}
```

Leaving the `await` out is a type error where the value is used (E1001: `expected str, found
Coroutine[any, any, str]`), and a call whose coroutine is dropped is E1278.

Arguments travel by name. An argument left out takes its default where the function is, evaluated
there.

### Calling a stream

A function whose result type is an iterator is a stream endpoint
([Serving a space](server.md#streams)): its items cross one by one, each as the function makes it.
The call is written as any call, and what it gives is read with a loop:

| The caller's host | A call of another space's `def f(...) -> Iterator[T]` gives | A call of its `async def f(...) -> AsyncIterator[T]` gives |
|---|---|---|
| `native`, `cpython` | An `Iterator[T]`, read with `for` | An `AsyncIterator[T]`, read with `async for` |
| `browser`, `hermes`, `node` | An `AsyncIterator[T]`, read with `async for` | An `AsyncIterator[T]`, read with `async for` |

With `def:pub steps(count: int) -> Iterator[Step]` in the space `api`, a native caller:

<!-- example: not checked: its names come from another space through the archwire's wires -->
```jac
import from stdjac { RemoteError }

with entry {
    try {
        for step in steps(3) {
            s: Step = step;
            print(s.n, s.text);
        }
    } except RemoteError as e {
        print("failed:", type(e).__name__, e.detail);
    }
}
```

```text
1 step 1 of 3
2 step 2 of 3
3 step 3 of 3
```

and a page, which shows each step as it arrives:

<!-- example: not checked: a page is a module of a browser space, with JSX and a crossing -->
```jac
import from "@jac/runtime" { RemoteError }

def:pub page -> JsxPage {
    has lines: list[str] = [];
    has error: str = "";

    async def run {
        lines = [];
        try {
            async for step in steps(3) {
                s: Step = step;
                lines = lines + [s.text];
            }
        } except RemoteError as e {
            error = e.detail;
        }
    }

    return <section>
        <button onClick={run}>run</button>
        <ul>{[<li key={t}>{t}</li> for t in lines]}</ul>
        <p>{error}</p>
    </section>;
}
```

- **The request is made when the first item is asked for**, not where the call is written.
- **Each item is decoded as `T`** as it arrives, as a result is.
- **A stream is not awaited.** On a JavaScript host `await steps(3)` is E1041 and a plain `for`
  over it is E1021: it is read with `async for`, inside an `async def`.
- **A failure is raised where the item would have come**, as a `RemoteError`
  ([below](#how-a-crossing-fails)): a call the server refuses, before the first item; an endpoint
  that raises, after the items it made; a stream cut short, where it stopped.
- **A page's stream goes through its app**, as its calls do: the app sends each event on as it
  comes.
- **A stream is carried wherever a call is.** Over HTTP it is an event stream. Between a native
  app and a `cpython` or `node` space it runs in its own process, in either direction, its
  reader pulls each item through the space's port as it takes it. Between native spaces of one
  program the call is an ordinary call, and gives the function's own generator.
- **A reader that leaves a stream early closes it**: a `for` left by `break`, a client that
  disconnects. The endpoint's generator is
  [closed where it paused](../language/generators.md#closing-a-generator), so its `finally`
  blocks run.

## Spawning a walker

`root spawn W(...)`, with `W` in another space, runs the walk in `W`'s space and gives the walker
back as the walk left it: its fields, and its reports in `.reports`.

- The walk starts at the caller's root in `W`'s space: the signed-in caller's own root, or the
  space's shared root for a caller who is not signed in ([An app's data](data.md)).
- The walker that comes back is a copy. Changing it changes nothing in the other space.
- On a JavaScript host the spawn is awaited, and needs its own parentheses, since `await` binds
  tighter than `spawn`: `w = await (root spawn Count());`.
- Only `root` can be spawned on. A walker of another space cannot start at one of this space's
  nodes.

## Who may call: access tags

A function or walker that another space calls is an **endpoint** of its space. Its access tag says
who may call it:

| Tag | Who may call it from outside its module | As an endpoint |
|---|---|---|
| `:priv` | No one | Never |
| none | Code of this project | Served only to the project's own programs: a request must carry the deployment's key |
| `:protect` | A signed-in caller | Served to requests carrying a session's token |
| `:pub` | Anyone | Served to every request |

The endpoints of a space are:

- every `:pub` or `:protect` function or walker at the top level of one of its modules, whether or
  not anything in the project calls it;
- every untagged one that is wired to a module of another space.

An untagged function nothing outside its space is wired to is not an endpoint at all: a request for
it is answered 404.

Three rules follow from who can be trusted:

- **A `browser` or `hermes` space cannot call an untagged function or walker of another space**
  (E1210). Code on a device the project does not control can make any request the page can, so
  what a page calls says who may call it: `:pub` or `:protect`. The same holds for a `node` space's
  calls.
- **An access tag in an unplaced module is an error** (E1211). The module has no space to be
  served from.
- **An untagged endpoint is checked when it is called**, since the compiler cannot tell a server
  from a program on someone's machine: both are `native`.

### The deployment's key

Programs of one deployment share a secret in the environment variable `JAC_DEPLOY_KEY`. It is never
written into an artifact.

- A native or cpython program that has the variable sends it with each request it makes of another
  space (the header `x-jac-key`).
- A server answers a request for an untagged endpoint only when the request's key equals its own.
  With no key set on the server, no key matches.

```sh
JAC_DEPLOY_KEY=s3cret dist/api-linux-x86_64 &
dist/cli-linux-x86_64                         # an untagged call: RemoteRejected, "an internal endpoint"
JAC_DEPLOY_KEY=s3cret dist/cli-linux-x86_64   # the same call succeeds
```

### Calling as a signed-in user

A `:protect` endpoint needs a session's token ([Serving a space](server.md) says how one is made).

- A page keeps the token its sign-in returned and sends it with every crossing
  ([Pages](pages.md)).
- A native or cpython program sends the token in `JAC_REMOTE_TOKEN`, when that variable is set.

## Where the other space is

A space is reached in one of three ways, decided by the app the caller is in:

| The callee's space | The call travels |
|---|---|
| Is native, and the caller's app runs both as native spaces | Not at all: the two are one program, and the call is an ordinary call |
| Is a `cpython` or `node` space the app runs in its own process | In-process, serialized as a request is |
| Is run by another app | Over HTTP, to the URL the caller's app has for that space |

The URL of a space an app reaches and does not run comes from `jac.toml`, baked into the artifact:

```toml
[apps.cli.remote]
api = "https://api.example.com"
```

and is overridden where the program runs by `JAC_REMOTE_<SPACE>`, the space's name uppercased:

```sh
JAC_REMOTE_API=http://127.0.0.1:8000 dist/cli-linux-x86_64
```

An app that reaches a space with no URL in `[apps.<app>.remote]` does not build (E1212). Give a
placeholder there and set the variable at run time if the address is only known then.

### A page's calls go through its app

A browser space is served by an app, and every crossing the page makes goes to that app, at the
page's own origin. So a page needs no URL and no CORS.

- For a space the app runs, the app answers.
- For a space it does not run, the app forwards the request to that space's URL, with the caller's
  token and without the deployment's key. Only the endpoints the page's modules are wired to are
  forwarded; any other path is 404. A stream's events are forwarded each as it comes.

A desktop app serves its page from a loopback port of its own and forwards in the same way. A
phone app's bundle carries the URLs and calls each space directly. Both take them from
`[apps.<app>.remote]`.

## What crosses, and in what form

Arguments, results, a stream's items and a walker's fields are serialized, so each must be
**sendable**: a value whose parts are all its own. An endpoint whose signature holds something that is not is refused
where it is declared, and a call where it is made, both as E1308:

```text
svc.jac:11:1: error[E1308]: 'f: Callable[[int], int]' is not sendable across a concurrency boundary
```

Not sendable: a function value, an `any`, an object holding an `Atomic` or another shared object, a
C record, a Python object. A union of several types besides `None` is refused too, since a JSON
value cannot say which it is.

Each value crosses as JSON, by its declared type:

| Type | JSON |
|---|---|
| `int`, `float`, `str`, `bool`, `None` | The same |
| `obj`, `struct`, walker | An object of its fields |
| `node`, `edge` | An object of its fields and its id (`__jid`); the receiver gets a detached copy |
| `list`, `set`, `tuple`, array, vector | A list |
| `dict` with `str` keys | An object |
| `dict` with other keys | A list of `[key, value]` pairs |
| An enum's member | Its name |
| `i128`, `u128` | A string of its decimal digits |
| `bytes`, `bytearray` | A string of hex digits |
| `complex` | `[real, imag]` |

A node space tags each object it sends with its class's name, `{"__jac": "Reply", "text": "hello
bob", "parts": ["a"]}`, and reads that tag in an object it receives; a native or cpython space
sends the fields alone. Any other key in a request is data: one named `__proto__`, `constructor`
or `prototype` sets no prototype and names no class in a node space.

Decoding is strict. A missing field, an unknown argument or a value of the wrong JSON type is
refused, never coerced: `"12"` is not an `int`. A field left out takes its default when it has one.
An object is restored, not constructed: its `init` and `postinit` do not run. An object whose class
is a subclass of its field's declared type is refused when it is sent.

A walker's reports cross as JSON's own values (numbers, strings, booleans, `None`, lists, and
dicts with `str` keys), unless the walker declares their type with a field
`has reports: list[T] = [];`, in which case they cross as `T`.

stdjac's codec does this; a program can use it directly, with `encode` and `decode` from `stdjac` ([stdjac](stdjac.md#the-codec)).

## How a crossing fails

A failed crossing raises a subclass of `RemoteError` in the caller. Import the classes from
`stdjac` in a native or cpython space, and from `"@jac/runtime"` in a browser, hermes or
node space. stdjac's are native code's and CPython's: a JavaScript space that imports one is
refused at the import, with E1540
(`the module 'stdjac.remote' needs a graph, which a browser space does not provide`).

| Exception | When |
|---|---|
| `RemoteUnavailable` | The space has no URL, or nothing answers there; a stream that stopped before its `end` event |
| `RemoteTimeout` | Nothing from the server for 30 seconds while a native or cpython caller waits for a reply (a call may take longer: the server says every 15 seconds that it is still answering it), or for 60 seconds while it reads a stream |
| `RemoteRejected` | The request was refused: no key for an untagged endpoint, no session for a `:protect` one, or arguments that do not decode |
| `RemoteDecodeError` | The reply, or a stream's item, is not what the callee's result type says |
| `RemoteFailed` | The endpoint raised, or does not exist; a stream called on a space the process runs itself |

Each carries `space`, `endpoint` (`module.name`) and `detail`, and prints as its `detail`.

The server sends a stream's reader a comment after 15 seconds of silence
([Serving a space](server.md#streams)), and the caller of a call it has not answered yet an
interim reply each 15 seconds, so a stream or a call times out only when the server, or the way
to it, has stopped. A call that takes minutes returns when it is done.

An exception an endpoint raises does not cross. The caller gets `RemoteFailed` saying only that the
endpoint failed; the server prints the exception to its own output. A failure the caller is meant
to handle is a return value: `def post(text: str) -> Denied | None`.

```jac
import from stdjac { RemoteError, RemoteUnavailable }

with entry {
    try {
        raise RemoteUnavailable(
            space="api", endpoint="notes.greet", detail="no URL for space 'api'"
        );
    } except RemoteError as e {
        print(type(e).__name__, e.space, e.endpoint);
        print(e);
    }
}
```

```output
RemoteUnavailable api notes.greet
no URL for space 'api'
```

## What is rejected

| Code | Cause |
|---|---|
| E1146 | A type wired into the calling module that the module never names: annotate the result with it |
| E1182 | A crossing whose signature, or whose walker's fields, name a type that is not wired into the calling module |
| E1210 | A browser, hermes or node space calls an untagged function or walker of another space |
| E1211 | `:pub` or `:protect` in a module no space holds |
| E1212 | An app reaches a space it does not run, with no URL in `[apps.<app>.remote]` |
| E1264 | Another space's function used as a value |
| E1276 | A space in an app calls a space that is in no app |
| E1278 | A crossing's coroutine made and dropped on a JavaScript host |
| E1308 | An argument, a result, a stream's item or a walker's field that is not sendable |
| E1021, E1041 | On a JavaScript host: a stream read with a plain `for`, or awaited |
| E5090 | A `glob`, class or enum wired across spaces; a spawn of another space's walker on anything but `root` in a JavaScript space |
