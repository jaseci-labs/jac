---
name: jac-codespaces
description: Inferred client/server/native code placement - how the compiler decides what runs where (JSX/npm imports mark code client, extern C declarations mark code native, references pull helpers along), what never moves (def:pub endpoints, walkers, shared objs), and the explicit cl/sv/na overrides. Load when deciding where code runs, pinning a declaration server-side with `sv`, or debugging why something landed in the wrong bundle.
---

**Codespaces are inferred - you do not have to mark client code.** Jac compiles one language to three codespaces: server (Python - the default), client (JavaScript/JSX), and native (LLVM). The compiler decides placement from the code itself; the `cl`/`sv`/`na` markers still exist but are optional overrides, and markerless code compiles **byte-identical** to its marker-annotated equivalent.

## The inference rules

1. **Client is structural.** JSX and string-path npm imports (`import from "react" { ... }`) are client-only syntax; a declaration carrying either is placed client automatically.
2. **Placement propagates through references.** Helpers, `glob`s, and imports that client code uses join the client bundle, transitively. Propagation is scope-aware: a local that shadows a module-level name does NOT pull the module-level one in.
3. **Server is the default** for unmarked code that no client code references.
4. **Native is seeded by extern C declarations** - an import whose braces declare C-ABI functions infers native placement for itself and its users; see below.

A complete markerless full-stack module - every placement is inferred:

```jac
import from datetime { datetime }               # used only by server code -> server
import from "canvas-confetti" { confetti }      # string-path npm import -> client-only

obj Note {                                      # referenced by BOTH sides -> auto-shared
    has text: str = "";
    has stamp: str = "";
}

def:pub save_note(text: str) -> Note {          # def:pub -> stays a server endpoint
    return Note(text=text, stamp=str(datetime.now()));
}

glob MAX_LEN: int = 280;                        # referenced by client code -> joins client bundle

def remaining(text: str) -> int {               # referenced only by client code -> client
    return MAX_LEN - len(text);
}

def:pub app() -> JsxElement {                   # JSX -> client
    has text: str = "";
    has notes: list[Note] = [];

    async def handle_save -> None {
        n = await save_note(text);              # client -> def:pub call = auto-RPC bridge
        notes = [n] + notes;
        confetti();
    }

    return <main>
        <input value={text} onChange={lambda (e: ChangeEvent) { text = e.target.value; }} />
        <span>{remaining(text)} left</span>
        <button onClick={handle_save}>Save</button>
        {for n in notes { <p key={n.stamp}>{n.text}</p> }}
    </main>;
}
```

## What inference never relocates

Reference propagation pulls helpers - it does NOT turn server API surface into client code:

- **`def:pub` functions and walkers stay server endpoints.** A client reference never inlines them into the bundle; the call compiles to the auto-RPC bridge (`await save_note(...)`, `result = root spawn add_task(title=t);` - see `jac-fullstack-patterns`). (A `def:pub` whose own body carries JSX is client by the structural rule - that is how markerless `def:pub app` and components work.)
- **Top-level `obj` archetypes referenced from both sides are auto-shared** into the bundle - typed instances cross the wire hydrated, no duplicate declaration needed.
- **Anything with an explicit access tag stays put.** A `:pub`/`:priv`/`:protect` tag declares intent about a declaration's surface; inference will not move it.

## Explicit overrides - they always win

| Form | Syntax | Scope |
|---|---|---|
| Block | `cl { ... }` / `sv { ... }` / `na { ... }` | a region of a mixed file |
| Statement prefix | `cl def ...` / `sv glob ...` / `na def ...` | one declaration |
| File extension | `.cl.jac` / `.sv.jac` / `.na.jac` | the whole file |

All existing marker-annotated code remains valid - markers are the explicit style, not a deprecated one. Write them when you want the boundary visible in the source, and always when overriding inference.

## `sv` pinning - the override you will actually need

Inference pulls what client code references. When that is wrong - the helper wraps a server-only dependency, the `glob` holds a secret - pin the declaration with `sv`:

```jac
import os;

sv glob API_KEY: str = os.getenv("API_KEY") or "";    # never ships in the JS bundle

sv def summarize(text: str) -> str {     # stays server even though app() calls it;
    return text[:80];                    #   the client call bridges over RPC instead
}
```

## `sv import` - a boundary fact, not placement

`sv import from services.X { fn, Types }` does not place the *importing* code anywhere - it states that the target module stays on the server and cross-boundary calls become RPC. The import itself lives with its consumers:

- **From client code**: generates the async JS RPC stub (always `await` the calls). See `jac-fullstack-patterns`.
- **From server code**: declares a server-to-server **microservice boundary** - the provider runs as its own service and calls become HTTP RPCs. See `jac-sv-microservices`.

## Native inference - extern C declarations are the seed

An import whose braces contain C-ABI function **declarations** is an FFI surface only the native backend can satisfy, so it seeds native placement - and the declarations that use those extern names (plus the helpers/`glob`s/`obj`s they reference) follow through the same reference propagation:

```jac
import from raylib { def InitWindow(w: i32, h: i32, title: str) -> None; }   # extern decls -> native seed

def open_window() -> None {        # uses InitWindow -> native
    InitWindow(800, 600, "hi");
}
```

- **Consuming a native module is NOT a signal.** `import from mymod { fast_fn }` where `mymod` is native code stays a server-side import - that is the server-to-native ctypes interop crossing, not a reason to relocate the importer.
- **`test` blocks are never pulled native.** `jac test` runs them on the server, where they reach the native code through the generated interop stubs - same as tests inside `na {}` blocks and `.na.jac` files.
- **Referenced by both sides -> stays server.** Client and native inference run independently in one markerless file; a declaration referenced by BOTH sides is placed server, where each side can bridge to it (auto-RPC for the client, py-interop for native).
- **Native-compatible pure code still defaults to server.** Compatibility is not intent: with no FFI seed, going native remains an explicit build choice - an `na { ... }` block, a `.na.jac` file, or `jac nacompile` / `jac run --autonative` auto-promotion. See `jac-native`.
- **Explicit markers never act as propagation sources.** An `na { }` block or `.na.jac` file pins its own contents; it does not pull referenced code native the way an extern seed does.

## Rules

- **Markerless first.** Write plain `.jac` and let JSX/npm imports, extern C declarations, plus references decide. Reach for markers to pin, not to enable.
- **Client code must carry the structural signal.** A component infers client because it contains JSX or an npm import (directly or through what it references); a pure helper with neither stays server until client code references it.
- **`def:pub` + JSX body = client component; `def:pub` without client-only syntax = server endpoint**, RPC-bridged when the client calls it.
- **Pin with `sv`** when client code references something that must stay server-side (secrets, server-only deps).
- **Markers that agree with inference change nothing** - markerless code compiles byte-identical to its marker-annotated equivalent.

## See also

- `jac-fullstack-patterns` - entry wiring, RPC call styles, endpoint registration
- `jac-cl-organization` - file layout for multi-component client apps
- `jac-sv-microservices` - `sv import` between services
- `jac-native` - the native codespace
- `jac-project-kinds` - which codespaces each project kind combines
