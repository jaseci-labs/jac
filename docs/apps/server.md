---
description: A native or cpython space as a server - its endpoints over HTTP, stream endpoints, the calls it answers at once, functions at paths of their own (@restspec), signing in and the accounts plugin, limits (@limit), scheduled functions (@schedule), jobs (@job, flow and wait) and the server's limits.
keywords: JAC_<APP>_LISTEN, JAC_TICKS_OFF, accounts, sign-in, session, stream endpoint, event stream, @restspec, @schedule, @job, @limit
---
# Serving a space

An app whose spaces have no `entry` is a server. It listens on one address and serves:

- each endpoint of the spaces it runs, at a URL made from its space, module and name;
- the functions given paths of their own with `@restspec`;
- signing in and out, as the project's auth plugin has it;
- the pages of the browser spaces it serves ([Pages](pages.md));
- and its scheduled functions, when they are due.

Nothing here is generated per project. What a module says of its functions is read by `stdjac`,
library code compiled into the app, and what carries each thing out is a
[plugin](plugins.md) the project may replace without changing a module:

| What a module says | The abstraction | Its standard plugin |
|---|---|---|
| A call from outside, and a call to another app | `transport` | `http`: HTTP, with JSON |
| `:protect`, the caller's `root` | `auth` | `accounts`: usernames and passwords |
| `@limit`, `consume_limit` | `limits` | `memory_limits`: counts in the program's memory |
| `@schedule` | `schedule` | `loop_schedule`: the thread that listens runs each when it is due |
| `@job`, `flow`, `wait` | `jobs` | `process_jobs`: a copy of the program for each |

This page describes a server with the standard plugins. A `native` space and a `cpython` space
serve identically; a `node` space serves a subset ([Hosts](hosts.md)).

The server answers each call on a thread of its own, so a call that waits holds no other up
([Calls at once](#calls-at-once)).

## The shortest server

`archwire.jac`:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space api: native { notes; }

    app api { run api; }
}
```

`notes.jac`:

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

walker:protect MyNotes {
    can show with Root entry {
        report [n.text for n in [here --> [?:Note]]];
    }
}
```

```sh
jac run api
```

```text
listening on http://127.0.0.1:8000/
```

The address is `127.0.0.1:8000` unless `JAC_<APP>_LISTEN` says otherwise
(`JAC_API_LISTEN=0.0.0.0:8080`; port `0` lets the system choose, and the line printed says which).
An address it can't listen on is said in one line, with the system's reason, and the app stops
with status 1 before it opens its data: one another program listens on, a port this user may not
take, an address that is not this machine's, a host name that doesn't resolve, a value that is not
a host and a port.

```text
api can't listen on 127.0.0.1:8000: Address already in use. To listen elsewhere, start it with JAC_API_LISTEN=<host>:<port>.
```

## Endpoints

Which functions and walkers are endpoints, and who may call each, is decided by access tags:
[Crossings](crossings.md) has the rules. Each endpoint is a `POST`:

| Endpoint | URL | Body |
|---|---|---|
| A function | `/__jac/call/<space>/<module>/<name>` | `{"args": {<parameter>: <value>, ...}}` |
| A walker | `/__jac/spawn/<space>/<module>/<name>` | `{"fields": {<field>: <value>, ...}}` |

`<module>` is the module's dotted name (`core.orders`). An empty body means no arguments.

```sh
curl -X POST http://127.0.0.1:8000/__jac/call/api/notes/greet -d '{"args": {"name": "jac"}}'
```

```text
{"ok": true, "data": "hello jac!"}
```

```sh
curl -X POST http://127.0.0.1:8000/__jac/spawn/api/notes/AddNote -d '{"fields": {"text": "milk"}}'
```

```text
{"ok": true, "data": {"fields": {"text": "milk"}, "reports": [["milk"]]}}
```

A spawn runs the walker on the caller's root and answers with the walker as the walk left it: its
fields and its reports.

### Arguments

Arguments are given by name and decoded as their parameters' types
([what crosses](crossings.md)):

- one left out takes its default;
- `null` is `None` for a parameter whose type admits `None` (`n: int | None`), and refused for
  any other (`plain: .n: expected an int, got None`);
- a missing one, an unknown one or one of the wrong type is refused, never coerced or dropped;
- `args` that is not a JSON object is refused (`the arguments are not a JSON object of them by
  name`).

### Replies

Every reply but a [stream](#streams)'s is JSON: `{"ok": true, "data": ...}` or
`{"ok": false, "kind": ..., "detail": ...}`.
A function that returns nothing (`-> None`) answers `{"ok": true, "data": null}`. Scheduling a
function ([below](#scheduled-functions-schedule)) does not stop it being an endpoint: it is called as
any other.

| Status | `kind` | When |
|---|---|---|
| 200 | | The call returned |
| 400 | `rejected` | The body is not JSON, or the arguments do not fit: `greet: no parameter 'nam'`, `greet: .name: expected a str, got 3`, `greet: missing field 'name'` |
| 401 | `rejected` | A `:protect` endpoint, and no signed-in caller |
| 403 | `rejected` | An untagged endpoint, and no deployment key: `an internal endpoint` |
| 404 | `failed` | No such endpoint |
| 409 | `conflict` | What the call changed in the graph, other instances of the app changed first, each of the 4 times it ran ([An app's data](data.md#several-instances-on-one-store)) |
| 500 | `failed` | The endpoint raised. The reply says only `<name> failed`; the exception is printed on the server's output. |

A request that is not a `POST` to an endpoint, a `restspec` route or a served page's file is
`404 not found`. The server never serves files from the directory it runs in.

### Streams

A function endpoint whose result type is `Iterator[T]` or `Generator[...]`, or an `async def`
endpoint whose result type is `AsyncIterator[T]` or `AsyncGenerator[...]`, is a **stream**: the
server sends each item as the function makes it, in the reply to the one request.

```jac
import time;

obj Step {
    has n: int,
        text: str;
}

def:pub steps(count: int) -> Iterator[Step] {
    for n in range(1, count + 1) {
        time.sleep(0.5);
        yield Step(n=n, text=f"step {n} of {count}");
    }
}
```

```sh
curl -N -X POST http://127.0.0.1:8000/__jac/call/api/work/steps -d '{"args": {"count": 3}}'
```

```text
data: {"n": 1, "text": "step 1 of 3"}

data: {"n": 2, "text": "step 2 of 3"}

data: {"n": 3, "text": "step 3 of 3"}

event: end
data: {}

```

The request is the one every function endpoint takes. The reply is 200 with
`Content-Type: text/event-stream` and no `Content-Length`: events, each ended by a blank line,
until the server closes the connection.

| Event | Sent |
|---|---|
| `data: <JSON>` | For each item, as the function yields it: the item as JSON, by its type ([what crosses](crossings.md#what-crosses-and-in-what-form)) |
| `event: end` and `data: {}` | After the last item |
| `event: error` and `data: {"ok": false, "kind": ..., "detail": ...}` | Where the function raised, in place of the items it did not make. `kind` and `detail` are a failed call's: `failed` and `steps failed`, the exception printed on the server's output |
| `: still here` | After 15 seconds in which the stream sent nothing. It is a comment, which a reader passes over |

- **A call refused before the stream starts** is answered as any call is, with the JSON reply and
  its status: 401 or 403 by the endpoint's access tag, 400 for arguments that do not decode
  (`steps: .count: expected an int, got 'x'`).
- **Each item's type is sendable**, as a result's is: E1308 names the item's type.
- **What a stream changed in the graph is written when it ends**, and where it calls `commit()`
  ([An app's data](data.md#when-the-graph-is-written)). A stream that raises writes nothing of its
  own.
- **A stream whose client has gone is closed where it paused.** The server finds out when it next
  sends the client an event, and closes the endpoint's generator: `GeneratorExit` is raised at
  its `yield`, so its `finally` blocks and its `with` statements run
  ([Generators](../language/generators.md#closing-a-generator)), and what it changed in the
  graph is written, as a call's that returned is. The code after that `yield` does not run.
- **A stream has no reply to give a `restspec` route**: a request for a route whose function is a
  stream is answered 400 (`ticks: ticks is a stream: its items are read as they come`).
- **How another space reads a stream** is on [Crossings](crossings.md#calling-a-stream): a native
  or cpython caller with `for`, a page with `async for`.

A `node` space, and a `cpython` space that a native app runs in its own process, have stream
endpoints too ([Hosts](hosts.md)).

### Who is calling

A request carries its caller in two headers:

| Header | Carries |
|---|---|
| `Authorization: Bearer <token>` | A session's token: the caller is that account |
| `x-jac-key: <key>` | The deployment's key (`JAC_DEPLOY_KEY`): the caller is one of the project's own programs |

Inside an endpoint, `root` is the caller's own root. With no signed-in caller, reading `root` raises
and the call fails; `root.shared` is the root for data that belongs to no one caller
([An app's data](data.md)).

## Calls at once

Each call runs on a thread of its own, from its first line to its reply, a stream's until its last
event. So a call that waits, for a model's answer, for a lock another call holds or in
`time.sleep`, holds no other call up.

- **At most 256 calls run at once.** A call past that waits for a thread.
- **One thread runs Jac at a time.** The calls' threads take turns as a program's own threads do:
  a thread gives way where it waits, and at its loops when another is waiting
  ([How threads take turns](../library/threading.md#how-threads-take-turns)). Calls that wait
  overlap; calls that compute take turns, and are no faster for being several. Work that computes
  at length belongs in a [job](#jobs-job).
- **`root` and the caller are the call's thread's.** Calls answered at once each have their own
  caller, and a thread a call starts (`threading.Thread`, and in a native space its
  [tasks](../language/async.md#tasks-flow-and-wait) and the threads of its
  [`flow for`](../language/flow-for.md) loops) works for the caller of the call that started
  it: `root` there is the same root.
- **The calls share the program's globals and its one graph.** A step on a builtin value
  (`xs.append(x)`, `n += 1`) is never seen half done. Several steps that must not interleave
  (read a value, wait, write it back) are guarded by a `threading.Lock`, which one call holds at a
  time while the others wait their turn:

```jac
import threading;
import time;

glob stock: int = 3,
     selling: threading.Lock = threading.Lock();

def:pub sell -> bool {
    with selling {
        if stock == 0 {
            return False;
        }
        time.sleep(0.1);
        stock -= 1;
        return True;
    }
}
```

- **The graph's store and the accounts file are used by one thread at a time.** A program needs no
  lock of its own for them.
- **The loop** is the thread the program started on. It takes connections, reads each request and
  hands it to its call's thread, and runs [scheduled functions](#scheduled-functions-schedule) between
  requests. While a scheduled function runs, the calls already being answered go on, and no new
  request is read.

## Signing in

Who a caller is, and how one signs in, is the project's `auth` plugin's to say
([Plugins](plugins.md)). A module says only `:protect` and `root`, and a page only `sign_in()`
([Pages](pages.md#signing-in)). Whatever the plugin, the app serves:

| Request | Reply's `data` |
|---|---|
| `GET /__jac/auth/` | What signing in takes: the `fields` to give and the `actions` they are given to, or a place to go (`redirect`), or the `session` of a caller the plugin knows already |
| `POST /__jac/auth/<action>`, a JSON object of what the action needs | `{"user": ..., "token": ..., "name": ...}`: the caller is signed in. `name` is what they are called where that is not who they are, as the name another service knows them by, and `""` otherwise |
| `GET /__jac/auth/me` | `{"user": ...}`, or 401 for a caller no one knows |
| `POST /__jac/auth/logout` | `null`; the caller's session is ended |
| `GET /__jac/auth/<action>?...` | Not JSON: the page a caller comes back to from the place an action sent them, below |

A sign-in the plugin refuses is 400 `rejected` with its reason, and 429 with a `Retry-After`
header for one made too often.

An action done elsewhere has a `redirect`, the place to go, and may have `keeps`: values the page
that leaves keeps in its tab. The other service sends the caller back to
`GET /__jac/auth/<action>` with what it gave them. The page served there posts that, with what
was kept, to `POST /__jac/auth/<action>`, keeps the session, and goes back to the page the caller
left from. So a plugin can tell the caller who left from one who was only handed the way back:
the second kept nothing.

### The accounts plugin

`accounts`, the standard plugin, keeps accounts of a username and a password. Its actions are
`register` and `login`:

```sh
curl -X POST http://127.0.0.1:8000/__jac/auth/register \
    -d '{"username": "amy", "email": "amy@example.com", "password": "longenough"}'
```

```text
{"ok": true, "data": {"user": "amy", "token": "<64 hex digits>"}}
```

```sh
curl -X POST http://127.0.0.1:8000/__jac/spawn/api/notes/MyNotes -H "Authorization: Bearer <token>"
```

- **A username** is 3 to 32 of `a-z`, `0-9`, `.`, `_` and `-`, starting with a letter or a digit,
  compared lowercased. So it is never an email address, which `login` also takes.
- **A password** has at least 8 characters. It is kept as a salted PBKDF2-HMAC-SHA256 hash.
- **A token** is 32 random bytes in hex. The plugin keeps only its SHA-256.
- **An email**, when given, must be an email address (`that isn't an email address`).
- **A refusal** says what is wrong: `that username or email is taken`,
  `incorrect username or password` (the same for a wrong password and an unknown account).
- **Attempts are limited** in each 15 minutes, by the project's limits: 5 sign-ins for one
  username from one client address, 30 sign-ins from one client address, 10 registrations from
  one client address.

Its settings, in `[auth.accounts]`:

| Setting | Type | Default | Meaning |
|---|---|---|---|
| `path` | `str` | `accounts.db` in the app's data directory | The SQLite file |
| `rounds` | `int` | `600000` | The rounds of a password's hash, for a password set from now on |
| `session_seconds` | `float` | `604800.0`, a week | How long a session lasts |
| `local_users` | `bool` | `false` | An app in a window of its own takes the people at its machine as its users, by a name each gives and no password ([Hosts](hosts.md#local-users)) |
| `email_required` | `bool` | `false` | An account is made only with an email address (`an account needs an email address`) |
| `github_id`, `github_secret` | `Secret` | The variables `SSO_GITHUB_CLIENT_ID` and `SSO_GITHUB_CLIENT_SECRET` | A GitHub OAuth app's client ID and secret, below |
| `github`, `github_api` | `str` | `https://github.com`, `https://api.github.com` | Where GitHub is, and its API: others for GitHub Enterprise |
| `origin` | `str` | `""` | Where callers reach the app (`https://example.org`), for the place another service sends them back to |

Accounts are one server's.

#### Signing in through GitHub

Where the program runs with a GitHub OAuth app's client ID and secret, the plugin offers a third
action, `github`, and a page's `sign_in()` shows it as `Continue with GitHub`. There is no code of
the project's:

```sh
SSO_GITHUB_CLIENT_ID=<id> SSO_GITHUB_CLIENT_SECRET=<secret> dist/api-linux-x86_64
```

- **The OAuth app's callback** is `<the app's address>/__jac/auth/github`. With `origin` set, the
  plugin names that address to GitHub itself, which an OAuth app registered at the site's root
  allows. Without it, GitHub sends callers to the callback the OAuth app registers.
- **The account** is GitHub's user: its user ID is `github:<GitHub's ID for the user>`, which
  does not change when they rename themselves, and the session's `name` is their login there.
  It is not the account of a username that happens to be the same.
- **The caller who left is the one signed in.** The page keeps a verifier, GitHub is given its
  hash as the caller leaves and the verifier when they are back (PKCE), and the `state` they
  carry is signed over it and lasts 10 minutes. A link to the way back, opened in another
  browser, signs no one in (`this sign-in was not begun here: try again`).
- **Attempts are limited** to 30 in each 15 minutes from one client address.
- Neither value is written in `jac.toml` or kept in the program
  ([Plugins](plugins.md#secrets)). `JAC_AUTH_GITHUB_ID` and `JAC_AUTH_GITHUB_SECRET`, when set,
  are read in their place.

A sign-in through a service this plugin does not offer is another auth plugin, again with no code
in the project.

## Limits: @limit

`@limit(uses, per=seconds)` before an endpoint lets each caller call it `uses` times in each `per`
seconds. A call past that is refused: 429 `rejected`, saying how long to wait, with a
`Retry-After` header.

```jac
import from stdjac.server { limit }

@limit(5, per=900.0)
def:pub post(text: str) -> str {
    return "posted " + text;
}
```

- A signed-in caller's calls are counted for them, and a caller no one knows by the address they
  call from.
- The program's own calls, and those of the deployment's other apps, are not counted.
- A function's route (`@restspec`) is counted with its endpoint.

`consume_limit(scope, actor, limit, seconds)` counts something that is no endpoint's caller: it
returns 0 while `actor` is within `limit` uses of `scope` in `seconds`, else the seconds to wait.

```jac
import from stdjac.server { consume_limit }

with entry {
    print([consume_limit("mail", "amy", 2, 60) for i in range(3)]);
}
```

```output
[0, 0, 60]
```

What counts is the project's `limits` plugin. The standard one, `memory_limits`, counts in the
program's memory: two instances of an app count apart.

## A path of its own: @restspec

`@restspec` serves a function at a path the project chooses, beside its `/__jac/call/` URL.

```jac
import from stdjac.server { HTTPMethod, restspec }

@restspec(method=HTTPMethod.GET, path="/robots.txt", envelope=False)
def:pub robots -> str {
    return "User-agent: *";
}

@restspec(method=HTTPMethod.GET, path="/status")
def:pub status -> dict[str, int] {
    return {"up": 1};
}
```

```sh
curl http://127.0.0.1:8000/robots.txt    # User-agent: *
curl http://127.0.0.1:8000/status        # {"ok": true, "data": {"up": 1}}
```

`@restspec(method, path, produces="text/plain", envelope=True)` is a
[decorator](../language/decorators.md): it records the route on the function as the program
compiles, and nothing is registered as the module starts.

| Argument | Meaning |
|---|---|
| `method` | `HTTPMethod.GET` or `HTTPMethod.POST`. A request with another method is 404. |
| `path` | Absolute: one that does not start with `/` does not compile |
| `envelope` | `True`: the reply is the JSON envelope. `False`: the body is the function's result, which must be a `str`. |
| `produces` | The `Content-Type` of an unenveloped body |

The function takes no parameters. Its access tag guards the route as it guards its endpoint:
`:pub` for anyone, `:protect` for a signed-in caller (401 otherwise), untagged for requests with
the deployment's key (403 otherwise).

Its arguments are checked as the program compiles: a missing `method` is E1050, an `envelope`
that is not a `bool` is E1053, an unknown keyword is E1052, and a function with parameters or a
path that does not start with `/` is E0109.

A path is served by a transport that serves paths, as the standard one, `http`, does. Under one
that carries calls between apps and nothing else, a program with a `@restspec` function (or a
page) does not start:

```text
api can't start with the transport it was given: it serves `svc.robots` at /robots.txt, and that transport carries calls and serves no paths. Bind one that serves them in jac.toml's [transport], or pick it where the program runs with JAC_TRANSPORT.
```

## Scheduled functions: @schedule

`@schedule` has a server run a function every so many seconds.

```jac
import from stdjac.server { schedule }

glob beats: int = 0;

@schedule(interval=60.0)
def heartbeat {
    beats += 1;
}

def:pub beat_count -> int {
    return beats;
}
```

- The function takes no parameters and returns nothing. An `async def` is run to its end.
- It runs every `interval` seconds, the first time as the server starts. `interval` is a
  compile-time value.
- A scheduled function runs for no caller: `root` raises there, and `root.shared` and `allroots()`
  are what it has. What it changes in the graph is kept.
- One that raises is reported on the server's output, and runs again at its next turn.
- `JAC_TICKS_OFF` turns scheduled functions off where the server runs: `all`, or names separated
  by commas. A scheduled function's name is its module's and its own (`svc.heartbeat`), or its own
  alone.
- A program with an `entry` listens for nothing, so its scheduled functions never run.

What runs them is the project's `schedule` plugin. The standard one, `loop_schedule`, has the
thread that listens run each when it is due.

## Jobs: @job

One thread of a server runs Jac at a time ([Calls at once](#calls-at-once)), so a call that
computes at length makes every other call wait its turns. A **job** runs such work apart from the
server and its graph. `@job` marks the function, `flow` starts it, and `wait` takes its result
([Tasks](../language/async.md#tasks-flow-and-wait)).

<!-- example: not checked: a job is declared in a module other than the one a program starts at -->
```jac
import from stdjac.server { Job, JobNote, job }

@job
def double(n: int, note: JobNote) -> int {
    note("working", "on " + str(n));
    return n * 2;
}

glob running: list[Job[int]] = [];

def:pub doubled(n: int) -> str {
    if not running {
        running.append(flow double(n));
    }
    j = running[0];
    if not j.done() {
        return "running";
    }
    running.clear();
    return str(wait j) + " " + str(j.notes());
}
```

Calling `doubled` with `{"args": {"n": 21}}` answers `"running"` until the job has finished, then
`"42 [('working', 'on 21')]"`.

- **A job's function** takes two parameters: its input, and a `JobNote`, `note(phase, text)`, which
  it calls to say how it is getting on. Any other shape does not compile (E0109).
- **`flow f(x)`** of a job starts it on its input and gives a `Job[R]` at once, `R` the function's
  result type. The input and the result cross to where the job runs and back as
  [a crossing's values do](crossings.md).
- **`j.done()`** is whether it has ended, without waiting. **`j.notes()`** gives the notes made
  since it was last called.
- **`wait j`** waits for the job and gives its result. A job that failed raises `JobFailed`, from
  `stdjac.server`, with what it failed with.
- A job does not see the server's graph and does not change it. It returns what the server should
  keep.
- A job of the module a program starts at cannot be started (E5090): put it in a module of its
  own.
- **A job is its own space's to start.** It is no endpoint: one tagged `:pub` or `:protect`, or
  wired to a module of another space, is E2223. What another space or a caller wants of a job, a
  function of the job's space gives them, as `doubled` does above.

What runs a job is the project's `jobs` plugin. The standard one, `process_jobs`, runs each in a
copy of the program.

## What the server will and will not read

| Limit | Value |
|---|---|
| Calls at once | 256, each on a thread of its own; a call past that waits for one ([Calls at once](#calls-at-once)) |
| A request's head | 1 MiB (431 past it) |
| A request's body | 16 MiB (413 past it), read by its `Content-Length`; a chunked body is 411 |
| `Content-Length` that is not a number, or is negative | 400 |
| `Transfer-Encoding` other than `chunked` | 501 |
| A first line that is not HTTP | 400 |
| Open connections with a request still to come | 512; past that the one open longest is closed |
| Time to send a request | 60 seconds |
| A stream's silence | 15 seconds, then the comment `: still here` |
| A call not yet answered | Each 15 seconds, an interim reply (`HTTP/1.1 100 Continue`), which a client passes over: its caller waits as long as the call takes, and gives up only on a server that says nothing. A client that asked with HTTP/1.0 is sent none |

Each reply closes its connection. Nothing a client sends ends the server: a request it will not
read is answered with the status that says why, idle connections past the 512 it keeps are closed
while it goes on answering, and its memory does not grow with the calls it serves.

For TLS, compression and many connections at once, put the server behind a reverse proxy.

## Environment variables

| Variable | Read by | Meaning |
|---|---|---|
| `JAC_<APP>_LISTEN` | A serving app | The address to listen on, `host:port`. Default `127.0.0.1:8000`. |
| `JAC_<APP>_DATA` | A serving app | Where its standard plugins keep its graph, accounts and jobs ([An app's data](data.md)) |
| `JAC_FRESH` | A serving app | `1`: start with no data ([An app's data](data.md)) |
| `JAC_<APP>_ARRANGEMENT` | An app whose artifact holds several arrangements | The arrangement it runs as ([Building apps](building.md#several-arrangements-in-one-artifact)) |
| `JAC_TICKS_OFF` | A serving app | Scheduled functions to skip: `all`, or their names |
| `JAC_<ABSTRACTION>`, `JAC_<ABSTRACTION>_<FIELD>` | A program | Which of its plugins it runs with, and a setting of that plugin ([Plugins](plugins.md)) |
| `JAC_DEPLOY_KEY` | Servers and callers | The deployment's key ([Crossings](crossings.md)) |
| `JAC_REMOTE_<SPACE>` | A caller | Where a space it does not run is |
| `JAC_REMOTE_TOKEN` | A native or cpython caller | The session it calls as |

`<APP>` and `<SPACE>` are the names uppercased, with every character that is not a letter or a
digit made `_`: the app `my-site` reads `JAC_MY_SITE_LISTEN`.
