---
name: jac-fullstack-patterns
description: Wiring `main.jac` as the entry for a fullstack Jac app - endpoint registration, client mount, calling walkers from the client (`root spawn`), the `sv import` rules that tie `.cl.jac` to server modules, endpoint caching, `[serve]` config. Load when starting a new app, adding the first server endpoint, creating a server module, or debugging how the top-level pieces connect. Pair with `jac-sv-endpoints`, `jac-cl-components`, `jac-scaffold`.
---

A fullstack Jac app has three layers: `main.jac` (entry), server modules (plain `.jac` files are equally idiomatic - server is the default context; `.sv.jac` is the explicit-marker option, e.g. `services/*.sv.jac`), and `components/**/*.cl.jac` (UI). `main.jac` mixes contexts - server imports first (plain, no block; server is the default), then a `cl { ... }` block holds the client section (`to cl:` section headers are a flatter alternative for a mostly-client file).

```jac
import from services.recipe {
    ApiResponse, RecipePayload,
    save_profile, list_recipes,
}

cl {
    import ".styles.global.css";
    import from .components.AppShell { AppShell }

    def:pub app() -> JsxElement {
        return <AppShell />;
    }
}
```

That no-argument `app()` is the single-page / manual-routing shape. With file-based routing (a `pages/` directory) `app` must instead take `children` and render it - `def:pub app(children: any) -> JsxElement { return children as JsxElement; }` - or every route is silently dropped. See `jac-cl-routing`.

## Two call styles: function RPC vs walker spawn

The client reaches the server two ways, with OPPOSITE argument rules:

| | `def:pub` function RPC | walker spawn |
|---|---|---|
| call form | `await save_profile(name, email)` | `result = root spawn add_task(title=t);` |
| argument rule | **POSITIONAL only** - kwargs send an empty body → 422 | **KWARGS only** - they map to the walker's `has` fields |
| return value | the function's return value (typed, hydrated) | a result object: read `result.reports` |

**Function RPC:** `save_profile(a, b)` works; `save_profile(name=a, email=b)` → `422 Field required`. The caller's *variable names* become the JSON keys, so they must exactly match the server parameter names: if the server is `def:pub get_moves(game_id: str, row: int, col: int)`, calling `get_moves(game_id, r, c)` 422s - rename the caller's locals to `row`/`col`.

**Walker spawn** (the docs' primary backend pattern): kwargs fill the walker's `has` fields; everything the walker `report`s lands in `result.reports` (a list - first report is `result.reports[0]`). Both styles are async on the client - inside an async context the spawn awaits implicitly:

```
async def handle_add() {
    result = root spawn add_task(title=title);      # kwargs -> `has title: str;`
    if result.reports and len(result.reports) > 0 {  # len(), NOT .reports.length (E1030)
        tasks = tasks + [result.reports[0]];
    }
}
```

## Typed objects cross the boundary

Return `node`/`obj` instances (or `report` them from walkers) directly - no manual dicts. The compiler generates wire stubs so the client receives **hydrated typed instances**: `def:pub get_tasks -> list[Task] { return [root-->][?:Task]; }` gives the client real `Task` objects with typed attribute access. Works for `obj`, `node`, `enum`, `list[T]`, nested objects, and in both directions (typed args serialize back). Use `jid(task)` for stable list keys and identity checks - graph identity survives the wire.

## Rules

- **Endpoints register two ways.** Any endpoint a `.cl.jac` module references through `sv import` **self-registers at server start**: the compile-time interop manifest records the client-to-server binding and the runtime imports the providing module itself (verified live; the flagship app imports ONE endpoint in `main.jac` while ~25 others serve through stub references alone). A top-level entry-module import (`import from services.X { fn, Types }`) is needed only for endpoints NO client stub references - streams consumed via raw fetch (`jac-sv-streaming`), REST-only/webhook walkers. **404 on RPC = nothing references it: no cl-side `sv import` AND no entry-module import.** Caveat (verified): an `sv import` inside the entry module's own `cl { }` block does NOT register the endpoint - keep server-calling client code in `.cl.jac` modules, or add the entry-module import.
- **In `main.jac`: plain `import from services.X { ... }`** (NEVER `sv import`). Plain = in-process import; the endpoint registers at `/function/<name>` (walkers at `/walker/<name>`).
- **In `.cl.jac`: `sv import from ..services.X { ... }`** (prefix required). Generates the JS RPC stub. Plain `import from` to a `.sv.jac` fails the Vite build with `Could not resolve "services/X.js"`.
- **Always `await` `sv import` function calls.** Stubs are `async` - `items = fetch_items()` assigns a `Promise` → silent runtime crash. `items = await fetch_items()`.
- **`sv import` in `main.jac` = microservice RPC.** Spawns a separate provider server process; session cookies don't cross → `def:priv` fails with `401 Unauthorized`. Only use for actual microservices.
- **Import obj/node TYPES alongside functions** in both places - missing types mean a server `NameError` at runtime or lost typed attribute access on the client (`has posts: list[Post] = [];` needs `Post` imported).
- **Reader responses are cached for 60s.** The client runtime auto-classifies endpoints: **readers** (no side effects) get an LRU response cache (60s TTL, deduped concurrent calls); calling any **writer** invalidates all cached reads; login/logout clears the cache. This is why a read can look "stale" after out-of-band changes (another tab, server-side mutation) - it's the cache, not your code.
- **Write-then-refetch is the canonical mutation handler:** call the writer, then re-spawn/re-call every reader whose data it changed and assign the fresh reports into state (post a tweet, then reload feed + profile + trending). The writer call already invalidated the read cache, so the refetches hit the server.
- **Contract drift is a `jac check` away.** After editing a server endpoint's signature or types, run `jac check` across the project: a W1101 `Cannot import name` / W1051 at the stale client `sv import` or spawn line is the cross-boundary drift signal, at the exact stale line (a conventional tsc+mypy stack sees nothing across that seam). Debugging workflow: `jac-debugging`.
- **`[serve] base_route_app = "app"` serves the client at `/`.** Without it the app lives at `/cl/app` and `/` stays the JSON API index. Scaffolded client projects set it by default. The server's SPA catch-all then serves the app HTML for clean URLs (BrowserRouter), excluding API prefixes (`cl/`, `walker/`, `function/`, `user/`, `static/`).
- **Client entry is `def:pub app`** - lowercase `app`. Not `App()`, `ClientApp()`. Runtime mounts the literal name. Don't wrap it in `with entry { }`. The export is always required; its signature depends on the routing system - `app()` for manual/single-page, `app(children)` rendering `children` for file-based (`jac-cl-routing`).
- **Wrap the client section in a `cl { ... }` block.** The braces bracket exactly the client region; server is the default context so server imports above the block need no wrapper. (`to cl:` section headers also work and are a flatter alternative for a mostly-client file.)
- **Global vs scoped CSS:** import app-wide CSS once in `main.jac`'s `cl { }` block (`import ".styles.global.css";` for the Tailwind import and custom CSS variables). For component-specific classes, add a same-basename `Comp.style.css` beside the `.cl.jac` - it auto-scopes and needs no import. No `*` reset in Tailwind projects (breaks Preflight spacing). See `jac-cl-styling`.
- **Start with `jac start --dev main.jac`** (NOT deprecated `jac serve`). HMR reloads only `.cl.jac` files - server-module / `glob` changes need a full restart (endpoints and `glob`s evaluate once at server boot). Kill stale `jac start` processes first: a held port makes the new server grab the next port while Vite's proxy still points at the old one → all RPC calls fail. `pkill -f "jac start"` then restart. `jac start` exits when stdin closes - launch background/long-running servers with `< /dev/null`.
- **QA the running app with `jac browse`** (bundled headless-browser driver, no extra deps): `jac browse open localhost:8000` → `jac browse snapshot` (accessibility tree with `@e1`-style refs) → `jac browse click @e5` / `fill '#email' val` → `jac browse screenshot` → `jac browse close`. Use it to verify rendered UI and flows end-to-end, not just that the server starts.
- **Build failures print structured `JAC_CLIENT_00x` diagnostics** (001 missing npm dep, 003 client syntax error, 004 unresolved import); set `JAC_DEBUG=1` (or `[client] debug = true`) for raw Vite output. Compiled JS for inspection: `.jac/client/compiled/`.

## See also

- `jac-scaffold` - project layout, `jac.toml`, scaffolders
- `jac-sv-endpoints` - writing `def:pub` / `def:priv` endpoints and walker endpoints
- `jac-sv-streaming` - SSE streaming endpoints: raw-fetch consumption and their registration rule
- `jac-cl-components` - writing `.cl.jac` + the `sv import` caller form
- `jac-cl-js-interop` - browser APIs, WebSockets, debugging compiled output
