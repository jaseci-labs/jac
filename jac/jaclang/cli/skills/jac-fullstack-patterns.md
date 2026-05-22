---
name: jac-fullstack-patterns
description: Wiring `main.jac` as the entry for a fullstack Jac app - server-endpoint registration, client mount, and the `sv import` rules that tie `.cl.jac` to `.sv.jac`. Load when starting a new app, adding the FIRST server endpoint to a client-only app, creating a new `.sv.jac`, or debugging how the top-level pieces connect. Pair with `jac-sv-endpoints` (write the endpoints), `jac-cl-components` (write the UI), `jac-scaffold` (bootstrap a new project).
---

A fullstack Jac app has three files: `main.jac` (entry + registry), `services/*.sv.jac` (endpoints + types), `components/**/*.cl.jac` (UI). `main.jac` mixes contexts - server imports first (plain, no block; server is the default), then a `cl { ... }` block holds the client section.

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

## Rules

- **`main.jac` is the server's endpoint registry.** EVERY `.sv.jac` you create needs its functions AND obj/node types added to `main.jac`'s `import from services.X { ... }` block. Missing = `404 Not Found` on RPC calls.
- **Adding a new endpoint is ALWAYS a 2-file change:** the `.sv.jac` service file + the import in `main.jac`. Especially easy to miss when extending a client-only app - no server import block existed before.
- **In `main.jac`: plain `import from services.X { ... }`** (NEVER `sv import`). Plain = in-process Python import; the endpoint registers at `/function/<name>`.
- **In `.cl.jac`: `sv import from ..services.X { ... }`** (prefix required). Generates the JS RPC stub. Plain `import from` to a `.sv.jac` fails the Vite build with `Could not resolve "services/X.js"`.
- **`sv import` in `main.jac` = microservice RPC.** Spawns a separate provider server process; session cookies don't cross → `def:priv` fails with `401 Unauthorized`. Only use for actual microservices.
- **Import obj/node TYPES alongside functions** in both places. Missing types → server `NameError` at runtime or lost typed attribute access on the client.
- **Call server endpoints with POSITIONAL args, not kwargs.** `save_profile(name, email)` works; `save_profile(name=name, email=email)` sends empty body → `422 Field required`.
- **Client entry is `def:pub app()`** - lowercase `app`. Not `App()`, `ClientApp()`. Runtime mounts the literal name.
- **Global vs scoped CSS:** import app-wide CSS once in `main.jac`'s `cl { }` block (`import ".styles.global.css";` for themes, resets, Tailwind). For component-specific classes, add a same-basename `Comp.style.css` beside the `.cl.jac` -- it auto-scopes and needs no import. See `jac-cl-styling`.
- **Start with `jac start --dev main.jac`** (background for hot reload). NOT `jac serve` (deprecated).
- **HMR only reloads client (`.cl.jac`) files. Server (`.sv.jac`) changes need a full restart.** `def:pub`/`def:priv` endpoints + `glob` declarations evaluate once at server boot - editing a `.sv.jac` does not invalidate cached endpoints. `pkill -f "jac start"` then `jac start --dev main.jac` to pick up changes.
- **Don't wrap the client entry in `with entry { ... }`.** Runtime mounts `def:pub app` directly.
- **Wrap the client section in a `cl { ... }` block.** The braces bracket exactly the client region; server is the default context so server imports above the block need no wrapper. (`to cl:` section headers also work and are a flatter alternative for a mostly-client file.)
- **In `sv import` RPC calls, the caller's local variable names are used as JSON keys - they must exactly match the server-side parameter names.** `get_moves(game_id, r, c)` sends `{"game_id":…, "r":…, "c":…}` but if the server signature is `def:pub get_moves(game_id: str, row: int, col: int)`, it gets 422 because `row` and `col` are missing. Rename caller variables: `get_moves(game_id, row, col)`.
- **Kill old `jac start` processes before restarting.** If port 8001 is held by a stale process, the new server grabs 8002 but Vite's proxy still points at 8001 → all RPC calls fail. Use `pkill -f "jac start"` before restarting.

## See also

- `jac-scaffold` - project layout, `jac.toml`, scaffolders
- `jac-sv-endpoints` - writing `def:pub` / `def:priv` endpoints
- `jac-cl-components` - writing `.cl.jac` + the `sv import` caller form
- `jac-core-cheatsheet` - import-form rules (brace vs module, when `;` applies)
