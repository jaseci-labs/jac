---
name: building-an-app
description: Use when creating or changing a jac app made of spaces - an archwire.jac with graph spaces, a server whose functions and walkers are HTTP endpoints, a command-line app that calls it, jac run, the app's kept data and --fresh, and deploying with environment variables.
---
# Building an app from spaces

## When to use this

Use it when a project should become a server, or a program that calls one: anything that touches
`graph spaces` in `archwire.jac`, `jac run <app>`, endpoints, access tags (`:pub`,
`:protect`), `.jac/data`, or `dist/`.

Load `writing-jac` first. Pages on top of the server: then `pages-and-components`. A language
model, an agent or a chat that streams: `language-models-and-agents`. A plain program with no
spaces: `starting-a-project`. Nodes, edges, walkers: `modelling-with-graphs`.

## Before you start

```sh
jac docs apps/index        # the terms: space, host, app, crossing
jac docs graph spaces      # the archwire's spaces block
jac docs crossings         # access tags, what crosses, remote spaces
```

`jac.toml` marks the project's root; `archwire.jac` beside it holds the spaces. Read an existing
archwire before adding to it: `jac build` with no app builds every app it declares.

A `jac.toml` with no `[check.lint]` holds the code to the `"clean"` rules, and that is intended:
they report every comment, every docstring and every body written inline (W3050, W3051, W3055),
and `jac fmt --fix` rewrites the code to them. The steps below write bodies inline: run
`jac fmt --fix` before `check`, or select the style rules alone, `select = ["style"]` under
`[check.lint]`, or lay the project out as `starting-a-project` does.

## Steps

1. **Declare a layer, a space and an app** in `archwire.jac` at the root. A layer groups
   modules for the edge rules between layers (step 5); a space holds modules on a host; an app
   whose spaces have no `entry` serves them.

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer service { notes; }
}

graph spaces {
    space api: native { notes; }

    app api { run api; }
}
```

Do not name an app, space or function after a keyword (`report`, `by`, `visit`...): E0013.

2. **Write the space's module** (`notes.jac`). Every `:pub` or `:protect` function or walker
   at its top level is an endpoint. `:pub` is anyone, `:protect` a signed-in caller, no tag only
   the project's own programs.

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

3. **Check, then run it.** `jac check api` prints nothing when the app is right.
   `jac run api` builds what changed and starts it. Pick a free port:

```sh
JAC_API_LISTEN=127.0.0.1:8301 jac run api      # prints: listening on http://127.0.0.1:8301/
```

Ctrl-C stops it. `jac run` becomes the app's program, with the same process id, so in the
background keep that id and stop the server by it:

```sh
JAC_API_LISTEN=127.0.0.1:8301 jac run api > api.log 2>&1 &
API_PID=$!
until grep -q "listening on" api.log; do kill -0 $API_PID || break; sleep 1; done
kill $API_PID           # SIGTERM: the server stops at once; what it kept stays kept
```

The process is the program in `dist/`: `dist/api-<platform>` while the app is native code only,
`dist/api-<platform>/api` once it serves pages or uses Python or npm packages (`jac build`
prints the path). `ps` names it by that file, never `jac`. Stop it by the id you kept, not by a
name: `pkill -f <pattern>` can match the shell that runs it. A job a script starts with `&`
ignores SIGINT, so use `kill`'s default, SIGTERM.

4. **Call the endpoints.** Functions are `POST /__jac/call/<space>/<module>/<name>` with
   `{"args": {...}}`; walkers are `POST /__jac/spawn/<space>/<module>/<name>` with
   `{"fields": {...}}`:

```sh
curl -X POST http://127.0.0.1:8301/__jac/call/api/notes/greet -d '{"args": {"name": "jac"}}'
curl -X POST http://127.0.0.1:8301/__jac/spawn/api/notes/AddNote -d '{"fields": {"text": "milk"}}'
curl -X POST http://127.0.0.1:8301/__jac/auth/register -d '{"username": "amy", "password": "longenough"}'
curl -X POST http://127.0.0.1:8301/__jac/spawn/api/notes/MyNotes -H "Authorization: Bearer <token>"
```

5. **Add a program that calls the server** (a crossing). Give it a space with an `entry`, wire
   the server's names into it in `graph import`, and put the types both sides use in a module
   no space holds (`model.jac`, here `obj Summary { has count: int; has newest: str; }`). Each
   new module gets a layer, and each pair of layers a wire crosses gets one edge rule:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer shared { model; }
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
    edge Shared: shared --> service | client;

    notes ++> client { AddNote, greet, count_notes }
    model ++> notes | client { Summary }
}
```

`notes.jac` gains the untagged function. A caller with only the deployment's key is no account,
so it reads `root.shared`, not `root`:

<!-- example: not checked: Summary comes from model.jac through the archwire's wire -->
```jac
def count_notes -> Summary {
    notes = [root.shared --> [?:Note]];
    return Summary(count=len(notes), newest=notes[-1].text if notes else "");
}
```

`client.jac` calls the server's names as local functions; a failed call raises a `RemoteError`:

<!-- example: not checked: its names come from another space through the archwire's wires -->
```jac
import from stdjac.remote { RemoteError }

with entry {
    try {
        print(greet("amy"));
        print((root spawn AddNote(text="from the cli")).reports);
        s: Summary = count_notes();
        print(s.count, s.newest);
    } except RemoteError as e {
        print("failed:", type(e).__name__, e.detail);
    }
}
```

`count_notes` is untagged, so only a caller with the deployment's key may call it. Give the cli
app the server's URL in `jac.toml`:

```toml
[apps.cli.remote]
api = "http://127.0.0.1:8000"
```

6. **Build and run both** with the same key, overriding the URL where it runs. The server here
   is the built program itself, kept and stopped by its process id as in step 3:

```sh
jac build            # prints each artifact's path: dist/api-<platform>, dist/cli-<platform>
JAC_DEPLOY_KEY=s3cret JAC_API_LISTEN=127.0.0.1:8301 dist/api-macos-aarch64 &   # your platform's name
API_PID=$!
JAC_DEPLOY_KEY=s3cret JAC_REMOTE_API=http://127.0.0.1:8301 jac run cli
kill $API_PID
```

7. **Mind the data.** A serving app keeps every node reachable from a root in
   `.jac/data/<app>/` (`graph.db`, `accounts.db`), committed after each call. A field added
   without a default makes the next start refuse the kept data; give it a default, or start
   empty with `jac run api --fresh` (the old data is moved aside, not deleted).

   The server answers its calls at once, each on a thread of its own, on one graph and the
   module's globals. Guard state that a call reads and then writes with a
   `threading.Lock` (`with lock { ... }`). A call that runs long, or a stream, calls `commit()`
   from `stdjac.graph` where its work so far should be kept.

   For progress, or an answer that comes in pieces, return an iterator in place of having the
   caller poll: `def:pub steps(count: int) -> Iterator[Step]` is a stream, whose items the server
   sends as the function yields them. A native caller reads it with `for`, a page with
   `async for`.

8. **Deploy** the artifact in `dist/`; it needs nothing installed. Set per machine
   `JAC_<APP>_LISTEN`, `JAC_<APP>_DATA`, `JAC_REMOTE_<SPACE>` (names uppercased), `JAC_DEPLOY_KEY`.

## What a correct result looks like

- `jac check api` prints nothing; `jac run api` prints `listening on http://127.0.0.1:8301/`.
- The `greet` call answers `{"ok": true, "data": "hello jac!"}`; the spawn answers
  `{"ok": true, "data": {"fields": {"text": "milk"}, "reports": [["milk"]]}}`.
- `MyNotes` without a token answers `{"ok": false, "kind": "rejected", "detail": "This needs a signed-in caller."}`.
- The cli prints `hello amy!`, the reports, then `<count> from the cli`. Without the key it
  prints `failed: RemoteRejected an internal endpoint`; with no server, the detail is the
  connection's own error: `failed: RemoteUnavailable <urlopen error [Errno 61] Connection refused>`
  on macOS (the number is the system's). Stop every server you start before you
  finish.

## Mistakes to expect

| Code or message | Means | Fix |
|---|---|---|
| E1212 | An app reaches a space it does not run, with no URL | Add `[apps.<app>.remote]` in `jac.toml` |
| E1146 | A wired name the consuming module never uses | Drop it from the wire's payload, or use it |
| E1182 `'Summary', which f()'s signature names, is not wired into 'client'` | The result's type is not known where it is called | Add the wire the message gives and annotate: `s: Summary = f()` |
| E1144 | A module under the archwire writes `import` of a project module | Delete the import; add a `++>` wire |
| E2213 | `archwire.jac` has no `graph layers` block | Add one; `layer all { *; }` holds every module |
| E2201 | A module is in no layer | Name it in the layer it belongs to |
| E2099 | A wire between two layers that no rule admits | Add `edge Name: source_layer --> target_layer;` |
| E1211 | `:pub` or `:protect` in a module no space holds | Move it into a space's module, or drop the tag |
| E1210 | A browser, hermes or node space calls an untagged endpoint | Tag it `:pub` or `:protect` |
| E0013 | An app, space or function named after a keyword | Rename it |
| 500, server prints `` `root` is no one's here `` | A `:pub` endpoint reads `root` for an anonymous caller | Use `root.shared`, or tag it `:protect` |
| `<app> can't start with the data it kept` | A node type changed under kept data | Default the new field, or `--fresh` |
| `<app> can't listen on <address>: Address already in use` | Port taken | Set `JAC_<APP>_LISTEN` |

## Where to look things up

- `jac docs apps/server`: endpoints, replies, streams, calls at once, signing in, `@restspec`,
  `@limit`, `@schedule`, `@job`.
- `jac docs plugins`: what carries the graph, the callers, the requests and the model, and
  binding another in `jac.toml`.
- `jac docs apps/data`: whose `root`, `root.shared`, `allroots()`, `jobj`, `commit()`, `--fresh`.
- `jac docs apps/building`: commands, artifacts, several arrangements of an app in one
  artifact, deployment values, `jac.toml` for apps.
- `jac docs graph import`: wires and edge rules.
- `jac docs host`: native, node, cpython spaces in one app.
- `jac docs E1212` (any code): its message and fix.
