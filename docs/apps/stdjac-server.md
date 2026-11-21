---
description: The server's words - the built-in decorators that give a function a path of its own, a schedule, a limit or make it a job, what a job's handle offers, and JobFailed, consume_limit and static_file, which a program imports from stdjac - with each name's signature; and the contracts a plugin for auth, jobs, schedules or limits conforms to, with what each asks of the program that runs it.
keywords: restspec, HTTPMethod, schedule, job, Job, JobNote, JobFailed, limit, consume_limit, stdjac.server, auth.contract, jobs.contract, schedule.contract, limits.contract, Auth, AuthHost, SignIn, SignInField, SignInAction, Session, Rejected, bearer_token, Jobs, JobsHost, JobState, Scheduler, Scheduled, Limits, static_file
---
# The server's words

These are the words for what a served program is made of, beside its endpoints
([Serving a space](server.md), `jac docs apps/server`): the functions it serves at paths of
their own, the ones it runs on a schedule, its jobs and its limits. The decorators that say so
of a function are built in: a program says them without importing them. A [plugin](plugins.md)
imports the contract it carries out, which is a module of its own
([below](#what-a-plugin-conforms-to)).

```jac
glob beats: int = 0;

@schedule(interval=60.0)
def heartbeat {
    beats += 1;
}

@restspec(method=HTTPMethod.GET, path="/status")
def:pub status -> dict[str, int] {
    return {"beats": beats};
}
```

Each decorator records a note on its function as the program compiles
([Decorators](../language/decorators.md)), and what serves the program reads the notes of every
function that carries one. Nothing is registered as a module starts, so no `with entry` is needed.

## What a program imports

`restspec`, `HTTPMethod`, `schedule`, `limit`, `job`, `JobNote` and `Job` are built in, and a
name of the program's own with the same spelling is the one the program means. `consume_limit`,
`JobFailed` and `static_file` ([below](#static_file)) are imported from `stdjac`:
`import from stdjac { JobFailed, consume_limit }`. A built-in word that is imported, or one of
the three imported from a module of stdjac, is E2233.

| Name | Signature | Does |
|---|---|---|
| `restspec` | `@restspec(method: HTTPMethod, path: str, produces: str = "text/plain", envelope: bool = True)` | Serves the function, one of no parameters, at `path` |
| `HTTPMethod` | `GET`, `POST` | A `@restspec` route's method |
| `schedule` | `@schedule(interval: float)` | A server runs the function, one of no parameters, every `interval` seconds, the first time as it starts |
| `limit` | `@limit(uses: int, per: float)` | A caller may call the endpoint `uses` times in each `per` seconds |
| `consume_limit` | `consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int` | Counts a use of `scope` by `actor`: 0 while it is within `limit` uses in `seconds`, else the seconds to wait |
| `job` | `@job` | The function, one of its input and a `JobNote`, runs apart: `flow f(x)` starts it |
| `JobNote` | `Callable[[str, str], None]` | What a job says how it goes with: `note(phase, text)` |
| `Job` | `Job[R]`: `done() -> bool`, `notes() -> list[tuple[str, str]]` | A job started, whose result is an `R`: `wait j` gives it |
| `JobFailed` | an exception, with `detail` | What `wait j` raises for a job that failed |

[Serving a space](server.md) says how routes, limits, scheduled functions and jobs behave in a
running server: who they run for, what they see of the graph, and what goes wrong.

A decorator's arguments are compile-time values, by position or by keyword, and are checked as
the program compiles ([Serving a space](server.md#a-path-of-its-own-restspec)).

State the calls of a server share is guarded with `threading.Lock`
([threading](../library/threading.md)): a server answers its calls at once, each on a thread of
its own ([Serving a space](server.md#calls-at-once)).

## What a plugin conforms to

Each of these is the interface of an abstraction ([Plugins](plugins.md)), in that abstraction's
contract: a plugin imports it from there (`import from auth.contract { Auth, Session }`), its
class conforms to it, and a program never names it.

| Interface | Contract | Methods |
|---|---|---|
| `Auth` | `auth.contract` | `open(host: dyn AuthHost)`; `caller(headers: dict[str, str]) -> str \| None`, who a request's caller is; `asks(headers) -> SignIn`, what signing in takes; `answer(action: str, given: dict[str, str], client: str) -> Session`, a caller signed in, or `Rejected`; `leave(headers)`, a session ended |
| `Limits` | `limits.contract` | `open(host: dyn Host)`; `consume(scope: str, actor: str, limit: int, seconds: int) -> int` |
| `Scheduler` | `schedule.contract` | `open(host: dyn Host)`; `start(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None])`: run each of `work` when it is due, from now on |
| `Jobs` | `jobs.contract` | `open(host: dyn JobsHost)`; `start(name: str, input: any) -> str`, a job started, by what names its run; `read(id: str) -> JobState`, what it has said since it was last read and whether it has ended; `work() -> bool`, asked as a program starts: run the job this process was started for, if any |

`open` is the first thing asked of a plugin, and it is given the program it runs in: a `Host`
(`common.contract`), or the host of its own abstraction, which is one
([Plugins](plugins.md#what-a-plugin-imports)).

What they are given and give:

| Type | Fields |
|---|---|
| `SignIn` | `fields: list[SignInField]`, `actions: list[SignInAction]`, `redirect: str`, `session: Session \| None`: a form, or a place to go, or the session of a caller known already |
| `SignInField` | `name`, `label`, `secret: bool`, `choices: list[str]` |
| `SignInAction` | `name`, `label`, `needs: list[str]` (the fields it takes), `redirect: str` (for one done elsewhere), `keeps: dict[str, str]` (what the page that leaves for it keeps, given to `answer` beside what the caller comes back with) |
| `Session` | `user: str`, `token: str`, `name: str` (what they are called, where that is not who they are) |
| `Rejected` | An exception: `detail: str`, `retry_after: int` |
| `Scheduled` | `name: str`, `every: float`, `run: Callable[[], None]` |
| `JobState` | `notes: list[tuple[str, str]]`, `done: bool`, `result: any`, `failed: str` |

What a plugin asks of the program, through the host its `open` was given:

| Host | Method | Gives or does |
|---|---|---|
| `Host` | `data_dir() -> str` | Where the program keeps files beside itself: its app's data directory |
| `Host` | `secret(s: Secret) -> str` | What the place the program runs gives the secret `s`: what its variable holds, or `""` |
| `Host` | `upgraded(what: str)` | Has the program say, as it starts, what the plugin did to data it keeps |
| `AuthHost` | `windowed() -> bool` | Whether the app shows itself in a window of its own |
| `AuthHost` | `consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int` | Counts a use with the project's `limits`: 0 within the limit, else the seconds to wait |
| `JobsHost` | `command() -> list[str]` | The command that runs the program again, before its arguments |
| `JobsHost` | `owner() -> str` | The space whose jobs the program's are, to a copy started for one: `""` for its own |
| `JobsHost` | `run(name: str, input: any, note: Callable[[str, str], None]) -> any` | Runs the program's job `name` and gives its result as JSON's values |
| `JobsHost` | `run_space(owner: str, name: str, input: any, note: Callable[[str, str], None]) -> any` | The same for a job of a space the program runs in its own process |

An `AuthHost` and a `JobsHost` are each a `Host`. `auth.contract`'s
`bearer_token(headers: dict[str, str]) -> str` is the credential a request carries as a bearer
token, or `""`.

`Transport`, the interface of what carries requests between apps, is `transport.contract`'s
([stdjac](stdjac.md#transport)).

## static_file

`static_file(top: str, path: str) -> Response` answers a request for `path` from the directory
`top`, as an app serves a bundle ([Pages](pages.md)). The `Response` has `status`, `ctype`,
`body` (bytes) and `headers`:

```jac
import os;
import tempfile;
import from stdjac { static_file }

with entry {
    site = tempfile.mkdtemp();
    os.makedirs(os.path.join(site, "assets"));
    with open(os.path.join(site, "index.html"), "w") as f {
        f.write("the page");
    }
    with open(os.path.join(site, "assets", "app.js"), "w") as f {
        f.write("code");
    }
    for path in ["/", "/docs/v0.39", "/x.js", "/assets/app.js", "/../secret.txt"] {
        r = static_file(site, path);
        print(path, r.status, r.body.decode("utf-8"), r.headers.get("Cache-Control", "-"));
    }
}
```

```output
/ 200 the page -
/docs/v0.39 200 the page -
/x.js 404 not found -
/assets/app.js 200 code public, max-age=31536000, immutable
/../secret.txt 403 forbidden -
```

- A path that is no file under `top` is a page's route and gets `index.html`, a dot in it or not
  (`/docs/v0.39`). A missing file of a kind the server serves (`.js`, `.css`, `.png`, ...) is 404.
- A path that leads out of `top`, by `..` or by a symbolic link, is 403 `forbidden`.
- A file under `top`'s own `assets/` is marked to be cached for a year
  (`Cache-Control: public, max-age=31536000, immutable`); nothing else is.
- `static_file("", path)` raises `ValueError: static_file needs the directory it serves`.

## What else is in the module

The rest of what stdjac holds of the server (`auth_route`, `route_of`, `scheduled`, and the
functions an app's start calls) is what `stdjac.app` serves a program with. A program does not
import it.
