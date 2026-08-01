---
name: jac-fullstack-patterns
description: Wiring `main.jac` as the entry for a fullstack Jac app - endpoint registration, client mount, calling walkers from the client (`root spawn`), the import rules that tie client modules to server modules, endpoint caching, `[serve]` config. Load when starting a new app, adding the first server endpoint, creating a server module, or debugging how the top-level pieces connect. Pair with `jac-sv-endpoints`, `jac-cl-components`, `jac-scaffold`.
---

A fullstack Jac app has three layers: `main.jac` (entry), server modules (plain `.jac` files - server is the default placement), and client components (plain `.jac` with JSX infers client). Both halves of a feature live in the same folder - see `jac-cl-organization`. Codespace placement is **inferred** (see `jac-codespaces`): JSX and string-path npm imports mark a declaration client, references pull helpers/`glob`s/imports into the bundle, and `def:pub` endpoints in server-anchored modules stay server. `main.jac` mixes both sides naturally - server imports and endpoints first, client section below, no wrapper syntax exists or is needed:

```jac
import from recipes.store {
    ApiResponse, RecipePayload,
    save_profile, list_recipes,
}

import ".styles.global.css";                    # string-path import -> client
import from .recipes.RecipesShell { RecipesShell }   # pulled client: app() renders it

def:pub app() -> JsxElement {                   # JSX -> inferred client
    <RecipesShell />
}
```

That no-argument `app()` is the single-page / manual-routing shape. With file-based routing (a `pages/` directory) `app` must instead take `children` and render it - `def:pub app(children: any) -> JsxElement { return children as JsxElement; }` - or every route is silently dropped. See `jac-cl-routing`.

## Two call styles: function RPC vs walker spawn

The client reaches the server two ways:

| | `def:pub` function RPC | walker spawn |
|---|---|---|
| call form | `await save_profile(name, email)` or `await doc_tree(version=v)` | `result = root spawn add_task(title=t);` |
| argument rule | positional AND kwargs both work - resolved against the server signature | **KWARGS only** - they map to the walker's `has` fields |
| return value | the function's return value (typed, hydrated) | a result object: read `result.reports` |

**Function RPC:** the compiled stub resolves arguments against the *server's* declared parameter names - positional args map by position, kwargs by name, and the JSON body is keyed by the server's names regardless of the caller's local variable names (verified in the emitted JS: `get_moves(game_id, r, c)` wires `r`/`c` onto `row`/`col` by position). Passing the same parameter both ways is a compile error (E5080).

**Pick the shape by whether the endpoint walks: no `visit`, no walker.** A single-`Root entry` walker that just `report`s is better written as a `def:pub` function - typed return instead of `reports[0]`, real parameters instead of `has` fields, identical `root` binding. The full rule lives in `jac-sv-endpoints`.

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

- **Name every endpoint in the entry module's import list.** `import from <feature>.X { fn, Types }` in `main.jac` is what reliably registers `fn` at `/function/fn` (walkers at `/walker/<name>`). The compile-time interop manifest is *meant* to let any endpoint a client module imports self-register at server start, and often it does - but registration tracks the **exact name**, and a newly added `def:pub` in a module the entry already imports still returns **405 Method Not Allowed** until that new name joins the same import (jaseci-labs/jac#7695). Renaming it or changing its return type does not help; adding it to the entry import does. **405/404 on RPC = the name is missing from the entry-module import.** Related: keep server-calling client code in separate client modules, not inside the entry module's own client section - endpoint imports made there do not register.
- **One import form everywhere: plain `import from <feature>.X { ... }`.** In `main.jac` (server side) it is an in-process import that registers the endpoint at `/function/<name>` (walkers at `/walker/<name>`). In a client module the same import of a server-placed endpoint compiles to the async JS RPC stub instead - the compiler knows the target's placement (`jac-codespaces`). Within a feature use the sibling form - `import from .store { list_recipes }` - which is the whole point of keeping both halves together.
- **Always `await` client-side calls to server functions.** RPC stubs are `async` - `items = fetch_items()` assigns a `Promise` → silent runtime crash. `items = await fetch_items()`.
- **A separate provider process is a config fact, not an import form.** Listing a module in `[scale.microservices.routes]` turns its imports into server-to-server HTTP stubs and runs it as its own service; session cookies don't cross → `def:priv` fails with `401 Unauthorized`. Only put actual microservices in the routes table (see `jac-sv-microservices`).
- **Import obj/node TYPES alongside functions** in both places - missing types mean a server `NameError` at runtime or lost typed attribute access on the client (`has posts: list[Post] = [];` needs `Post` imported).
- **Reader responses are cached for 60s.** The client runtime auto-classifies endpoints: **readers** (no side effects) get an LRU response cache (60s TTL, deduped concurrent calls); calling any **writer** invalidates all cached reads; login/logout clears the cache. This is why a read can look "stale" after out-of-band changes (another tab, server-side mutation) - it's the cache, not your code.
- **Write-then-refetch is the canonical mutation handler:** call the writer, then re-spawn/re-call every reader whose data it changed and assign the fresh reports into state (post a tweet, then reload feed + profile + trending). The writer call already invalidated the read cache, so the refetches hit the server.
- **Contract drift is a `jac check` away.** After editing a server endpoint's signature or types, run `jac check` across the project: a W1101 `Cannot import name` / W1051 at the stale client import or spawn line is the cross-boundary drift signal, at the exact stale line (a conventional tsc+mypy stack sees nothing across that seam). Debugging workflow: `jac-debugging`.
- **`[serve] base_route_app = "app"` serves the client at `/`.** Without it the app lives at `/cl/app` and `/` stays the JSON API index. Scaffolded client projects set it by default. The server's SPA catch-all then serves the app HTML for clean URLs (BrowserRouter), excluding API prefixes (`cl/`, `walker/`, `function/`, `user/`, `static/`).
- **Client entry is `def:pub app`** - lowercase `app`. Not `App()`, `ClientApp()`. Runtime mounts the literal name. Don't wrap it in `with entry { }`. The export is always required; its signature depends on the routing system - `app()` for manual/single-page, `app(children)` rendering `children` for file-based (`jac-cl-routing`).
- **There is no wrapper syntax for the client section.** Inference places JSX-bearing declarations, string-path imports, and the helpers they pull client (see `jac-codespaces`); when inference must be overridden (a helper that has to stay server-side), pin it in `jac.toml` via `[placement.pins]`, not in the source.
- **Global vs scoped CSS:** import app-wide CSS once in `main.jac`'s client section (`import ".styles.global.css";` for the Tailwind import and custom CSS variables). For component-specific classes, add a same-basename `Comp.style.css` beside the component `.jac` - it auto-scopes and needs no import. No `*` reset in Tailwind projects (breaks Preflight spacing). See `jac-cl-styling`.
- **Start with `jac start --dev main.jac`** (NOT deprecated `jac serve`). HMR reloads only client modules - server-module / `glob` changes need a full restart (endpoints and `glob`s evaluate once at server boot). Kill stale `jac start` processes first: a held port makes the new server grab the next port while Vite's proxy still points at the old one → all RPC calls fail. `pkill -f "jac start"` then restart. `jac start` exits when stdin closes - launch background/long-running servers with `< /dev/null`.
- **QA the running app with `jac browse`** (bundled headless-browser driver, no extra deps): `jac browse open localhost:8000` → `jac browse snapshot` (accessibility tree with `@e1`-style refs) → `jac browse click @e5` / `fill '#email' val` → `jac browse screenshot` → `jac browse close`. Use it to verify rendered UI and flows end-to-end, not just that the server starts.
- **Build failures print structured `JAC_CLIENT_00x` diagnostics** (001 missing npm dep, 003 client syntax error, 004 unresolved import); set `JAC_DEBUG=1` (or `[client] debug = true`) for raw Vite output. Compiled JS for inspection: `.jac/client/compiled/`.

## See also

- `jac-codespaces` - the inference rules, `[placement.pins]` overrides, placement tooling
- `jac-scaffold` - project layout, `jac.toml`, scaffolders
- `jac-sv-endpoints` - writing `def:pub` / `def:priv` endpoints and walker endpoints
- `jac-sv-streaming` - SSE streaming endpoints: raw-fetch consumption and their registration rule
- `jac-cl-components` - writing client components + the RPC caller form
- `jac-cl-js-interop` - browser APIs, WebSockets, debugging compiled output
