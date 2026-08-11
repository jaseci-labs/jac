# Breaking Changes

This page documents significant breaking changes in Jac and Jaseci that may affect your existing code or workflows. Use this information to plan and execute updates to your applications.

!!! note
    MTLLM library is now deprecated and replaced by the byLLM package. In all places where `mtllm` was used before, it can be replaced with `byllm`.

---

### The ambient permission constants are now one ambient `AccessLevel` enum (unreleased)

The four ambient access-level constants - `NoPerm`, `ReadPerm`, `ConnectPerm`, `WritePerm` - are removed. The `AccessLevel` enum they aliased is now itself ambient (no import needed), and its members are the one spelling of access levels everywhere a level is taken:

| Old | New |
|---|---|
| `grant(node, level=ReadPerm)` | `grant(node, level=AccessLevel.READ)` |
| `Jac.allow_root(node, rid, WritePerm)` | `Jac.allow_root(node, rid, AccessLevel.WRITE)` |
| `return WritePerm;` in `__jac_access__` | `return AccessLevel.WRITE;` |
| `NoPerm` / `ConnectPerm` | `AccessLevel.NO_ACCESS` / `AccessLevel.CONNECT` |

This also unifies the vocabulary with the Scale reference's `perm_grant` / `allow_root` API, which already spoke in `NO_ACCESS` / `READ` / `CONNECT` / `WRITE` levels, and it makes the honest hook signature type-check: `def __jac_access__ -> AccessLevel { return AccessLevel.WRITE; }` (the constants were stub-typed `int`, so the checker rejected exactly that form). String (`"WRITE"`) and int returns remain accepted at runtime for policies stored in data, but enum members are the canonical spelling - a typo'd string literal raises `KeyError` at access-check time.

**Impact:** a mechanical 1:1 rename. A bare removed name is now an unresolved-name error at compile time; importing one from `jaclang.runtimelib.builtin` raises an `AttributeError` that names the replacement member.

---

### All placement spellings removed: `sv`/`cl`/`na` markers, the `.sv.jac`/`.cl.jac` suffixes, and the `variant` directive ([#7772](https://github.com/jaseci-labs/jac/issues/7772), jaclang 0.35)

Placement no longer has any spelling in source code or filenames. The `sv { }` / `cl { }` / `na { }` blocks, the single-statement prefixes (`cl import ...`, `sv def ...`), the `.sv.jac` and `.cl.jac` file suffixes, and the short-lived `variant client;` / `variant native;` module directive are all removed -- marker code is a syntax error, and a leftover suffixed file fails loudly:

```text
the .cl.jac marker was retired -- rename the file to .jac; client placement
is inferred from JSX/npm imports (override via [placement.pins] in jac.toml).
Run 'jac fix placement' to migrate the project.
```

What replaces them:

- **Inference** places every declaration: JSX, browser globals, and npm imports seed client; extern C declarations seed native; python imports and graph archetypes anchor server (the default). Placement propagates from those seeds through symbol references.
- **`[placement.pins]` in `jac.toml`** is the override when a decision must be forced. A module-level `"client"` / `"native"` pin coerces the whole module the way the old suffix did; an element-level pin (`"mod.helper" = "server"`) forces one declaration.
- **`[scale.microservices.routes]`** is the authoritative microservice cut (`jac scale split <module>` writes an entry); imports of cut members lower to service RPC automatically -- this replaces the `sv import` boundary marker.

| Old | New |
|---|---|
| `cl { ... }` block / `cl` prefix | plain code (inferred client) or a `"client"` pin |
| `sv { ... }` block / `sv` prefix | plain code (server is the default) or a `"server"` pin |
| `mod.cl.jac` / `mod.sv.jac` | `mod.jac` (placement inferred; pin the module to coerce it whole) |
| `sv import from .svc { f }` | plain import + `[scale.microservices.routes]` entry (or a `"server"` module pin) |
| `variant client;` / `variant native;` | nothing -- placement has no per-file spelling |

**Impact:** run `jac fix placement` -- it strips markers, renames retired suffixed files, preserves service topology into the routes table, and pins any element whose inferred placement differs from its old marker. Review the result with `jac check <entry> --placements`. The placement lockfile briefly introduced alongside this work (`jac.placements.lock`, `jac check --update-placements-lock`) was removed before release: placement is the compiler's business, reviewed on demand, never snapshotted.

---

### The `.na.jac` filename marker retired ([#7770](https://github.com/jaseci-labs/jac/pull/7770), jaclang 0.35)

Native placement is no longer spelled in the filename. A plain `.jac` module becomes native by **inference**: under `[build] default_codespace = "native"` (the default), the placement solver's verdict (`scan_native_blockers` plus an import-closure fixpoint) decides, and a module that prefers native but cannot lower demotes to the server codespace with a note. Native is **forced** per-invocation rather than per-file: `jac nacompile file.jac` and `jac build --as native` coerce the module native outright -- lowering problems stay loud errors instead of demoting -- and `CompileOptions(force_codespace='native')` is the marker's programmatic successor.

This is a **clean break** -- a leftover `.na.jac` file fails loudly everywhere (the compiler, the importer, and `jac nacompile`) with:

```text
the .na.jac marker was retired in 0.35 -- rename the file to .jac
```

| Old | New |
|---|---|
| `mod.na.jac` | `mod.jac` (placement inferred) |
| `jac nacompile mod.na.jac` | `jac nacompile mod.jac` (forces native) |
| `mod.na.impl.jac` | `mod.impl.jac` (the `.na.impl.jac` annex variant no longer exists) |

**Impact:** rename every `*.na.jac` to `*.jac` and rely on inference; where native must be mandatory (AOT binaries, `--shared` libraries, wasm), use `jac nacompile` / `jac build --as native` / `force_codespace='native'`. The `.sv.jac` and `.cl.jac` variants were unchanged by this PR (they were retired separately -- see the entry above); the `.impl.jac` / `.test.jac` annexes are unchanged. One clarification makes the old native-library idiom carry over unchanged: `pub` elements anchor a *standalone* module to the server (endpoint semantics), but a module pulled in as a **native dependency** may freely use `pub` as its C-ABI export marker. The bundled native stdlib (`jaclang/runtimelib/na_stdlib/`) is native **by location**; its files are plain `.jac`, with per-OS variants as `<name>.<os>.jac` (e.g. `_dirent_native.darwin.jac`).

---

### Legacy syntax removed in one clean break ([#7514](https://github.com/jaseci-labs/jac/issues/7514))

A set of long-deprecated or redundant forms is removed with no deprecation window -- the old spellings are now hard errors:

| Old | New |
|---|---|
| `global x;` / `nonlocal x;` | Removed -- assignment binds to the nearest enclosing binding (see below) |
| `a && b` / `a \|\| b` | `a and b` / `a or b` |
| `def area() -> float abs;` | `def area() -> float abst;` (`abs` is now only the builtin function) |
| `nodes(?:Type, cond)` / `[-->(?:Type)]` | `nodes[?:Type, cond]` / `[-->[?:Type]]` (error **E0048**) |
| `root()` in `.jac` source | bare `root` (error **E0049**) |
| `has x: T by postinit;` | `has x: T postinit;` |
| `for i = 0 to i < 10 by i += 1 { }` | `for i = 0 while i < 10 with i += 1 { }` -- keyword separators (`while` condition, `with` step); the condition may be any expression. `to` is no longer a keyword at all |
| `can foo() { ... }` (function-style) | `def foo() { ... }` (error **E0034**; `can` is only for abilities with `with entry` / `with exit`) |
| `` has `class: str; `` (backticked Python reserved word as field/parameter name) | Rejected at compile time (error **E0067**) -- rename the field |

**New scoping semantics** replace the `global`/`nonlocal` directives: a bare assignment (including `+=`) inside a function binds to the **nearest enclosing binding** -- an enclosing function's local or a module-level `glob` -- and creates a new local only when no such binding exists. Only `glob`-declared variables are implicitly rebindable this way (imports, functions, and archetypes are not). To shadow an outer binding, write a typed declaration (`x: int = 5;`) before the name's first use in the scope; declaring it after the name was already bound in that scope is an error (**E0064**). Loop targets, `except ... as`, and `with ... as` always bind fresh locals. Python's `x += 1`-on-a-global `UnboundLocalError` gotcha is gone, and `glob` remains the only globals keyword.

**Impact:** the rewrites are mechanical (see the table). Deprecation warnings **W0061**/**W0062** no longer exist -- they are superseded by errors **E0048**/**E0049**. Functions inside `def` bodies that relied on `global`/`nonlocal` just delete the directive line -- the assignment already binds to the outer variable. Python **library mode** is unaffected: there `root` is a function imported from `jaclang.lib` and must still be called as `root()`. Identifiers named `to` no longer need backtick escaping.

---

### `region { }` blocks replaced by first-class `Region` handles and `in <handle> { }` opens

Regions are now a complete feature ([#7491](https://github.com/jaseci-labs/jac/issues/7491)): a `Region` is an ownable, sendable, escape-checked allocation extent, opened for allocation with the `in <handle> { ... }` statement. The old `region { ... }` contextual soft keyword is removed; its anonymous replacement is `in Region() { ... }`, and named handles (`r: own Region = Region(); in r { ... }`) add dynamic extent, helper opens through `&Region` parameters, and subgraph transfer across `flow`/`wait`.

This is a **clean break** -- `region { ... }` no longer parses.

| Old | New |
|---|---|
| `region { ... }` | `in Region() { ... }` |

On the native backend the open now bump-allocates into a real arena and reclaims wholesale (dtor-log walk, then one bulk free) at the handle's drop point, so the `E1307` escape rules are correspondingly stricter: heap-typed region values handed to opaque callees, laundered through aug-assigns, or wired into managed topology are now rejected. Scalars copy out freely and `own <expr>` reboxes a scalar or string copy out of the region.

**Impact:** mechanically rewrite `region {` to `in Region() {`. Code that leaked region references through calls or containers now gets `E1307` and needs an `own` rebox, a `&Region` helper signature, or restructuring.

---

### `jac create --list_jacpacks` renamed to `jac create --list`

The flag never listed jacpacks. A `.jacpack` is a distributable bundle you produce with `jac create --pack <dir>` and consume with `jac create --use <path|url>`; the flag instead lists the **project kinds** (used with `--kind`) and **named variants** (used with `--use <name>`) registered in the template registry. The name promised one thing and printed another, and its underscore spelling (`--list_jacpacks`, since `--list-jacpacks` was rejected) made it easy to get wrong.

This is a **clean break** -- there is no deprecated alias, and `--list_jacpacks` now fails with `unrecognized arguments`.

| Old | New |
|---|---|
| `jac create --list_jacpacks` | `jac create --list` |

**Impact:** replace `--list_jacpacks` with `--list` in scripts, CI, and docs. The short form `-l` is unchanged, so `jac create -l` works before and after. Nothing about the `.jacpack` format, `--pack`, or `--use` changes.

### Kubernetes image-build pipeline removed

`jac start --scale` no longer builds, tags, or pushes a Docker image. Copying the
project source into the cluster ("no-image") is now the only deploy path, so a
deploy needs no container registry and no registry credentials.

Removed, with no replacement:

| Removed | Notes |
|---|---|
| `--build` / `-b` on `jac start` | The flag no longer exists; `jac start --scale` is the whole deploy |
| `--registry` on `jac start` | Ditto |
| `image_registry`, `docker_image_name` under `[scale.kubernetes]` | Silently ignored if still present in `jac.toml` |
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` in `.env` | No longer read |
| Local-cluster image loading (`kind load docker-image`, `k3d image import`, `minikube docker-env`) | Nothing to load -- pods run a stock base image |

**Impact:** drop `--build` / `--registry` from any CI/CD script, and delete
`image_registry` / `docker_image_name` from `jac.toml`. Pods now boot from a
stock base image (`jaseci/jaclang`, or `python:3.12-slim` as a fallback) and
receive your code as a source bundle on a PVC. If your cluster cannot pull that
base image, set `python_image` under `[scale.kubernetes]` to one it can.

---

### `to cl:` / `to sv:` / `to na:` section markers removed

The module-level colon-section-marker syntax has been removed. A `to cl:` / `to sv:` / `to na:` line used to switch every following statement into the client / server / native context until the next marker or end of file. This is a **clean break** -- writing `to cl:` (or `to sv:` / `to na:`) now fails to parse.

Use the braced block form instead. It compiles to the same node and is now the canonical way to scope a region to a context:

| Old | New |
|---|---|
| `to cl:` <br> `<client stmts>` | `cl { <client stmts> }` |
| `to sv:` <br> `<server stmts>` | `sv { <server stmts> }` (or leave at module top level -- server is the default context) |
| `to na:` <br> `<native stmts>` | `na { <native stmts> }` |

**Impact:** rewrite any `to cl:` / `to sv:` / `to na:` section into the matching braced block, wrapping exactly the statements that belonged to that section. Single-statement prefixes (`cl def:pub foo() {...}`, `sv ...`, `na ...`) and file-extension contexts (`.jac`, `.na.jac`) are unaffected. (At the time, `to` still drove the iter-for loop; `to` has since been removed as a keyword entirely -- see [the clean-break entry above](#legacy-syntax-removed-in-one-clean-break-7514).)

---

### `jac add` merged into `jac install`

The `jac add` verb has been removed; `jac install <pkg>` absorbs it. This is a **clean break** -- `jac add ...` now fails with a pointer to the new spelling.

| Old | New |
|---|---|
| `jac add requests` | `jac install requests` |
| `jac add pytest --dev` | `jac install pytest --dev` |
| `jac add --git <url>` | `jac install --git <url>` |
| `jac add --npm <pkg>` | `jac install --npm <pkg>` |
| `jac add --shadcn <name>` | `jac install --shadcn <name>` |

**Behavior change:** `jac install <pkg>` now **records the dependency in `jac.toml`** (what `jac add` did) instead of installing without tracking. Pass the new `--no-save` flag for the old untracked behavior; `--global` and `--dry-run` continue to never touch `jac.toml`.

**Impact:** update scripts and CI invocations of `jac add` to `jac install`, and add `--no-save` to any `jac install <pkg>` call that relied on jac.toml staying unmodified. `jac remove` and `jac update` are unchanged.

---

### Plugin system removed; `[plugins.*]` config flattened

The pluggy-style plugin/hook system has been removed entirely. The `jac plugins` command, the `JAC_DISABLED_PLUGINS` env var, the `[plugins]` `discovery`/`enabled`/`disabled` keys, and entry-point plugin discovery are all gone. Built-in features (byLLM, scale, the client/desktop framework, MCP, shadcn) are now called directly by core, and **external third-party plugins are no longer supported**.

Feature config moved from the `[plugins.<name>]` namespace to top-level `[<name>]` tables:

| Old | New |
|---|---|
| `[plugins.byllm]` / `[plugins.byllm.model]` | `[byllm]` / `[byllm.model]` |
| `[plugins.scale.database]` | `[scale.database]` |
| `[plugins.client.pwa]` | `[client.pwa]` |

**Impact:** rename any `[plugins.<name>]` sections in existing `jac.toml` files to the top-level form; drop any `[plugins]` enable/disable lists and `jac plugins` invocations from scripts. Everything the built-in features do is always available -- there is nothing to enable. (Older entries below that mention `[plugins.<name>]` config predate this flattening; use the top-level names.)

---

### Project kinds renamed to deliverable-oriented names

The `jac create --kind` / `[project] kind` taxonomy was renamed to describe **what you ship**. The old names are **not** accepted as aliases -- `jac create --kind pypi-package` and a `jac.toml` carrying `kind = "fullstack"` both fail with `Unknown project kind`.

| Old | New |
|---|---|
| `native-app` | `cli-native` |
| `shared-library` | `native-lib` |
| `api-service` | `service` |
| `microservices` | `service-mesh` |
| `pypi-package` | `py-package` |
| `npm-package` | `js-package` |
| `fullstack` | `web-app` |
| `client` | `web-static` |

`cli`, `native-binary`, `desktop`, and `mobile` are unchanged.

**Impact:** update the `kind` value in existing `jac.toml` files and any scripts calling `jac create --kind` with an old name. Behavior of each kind is unchanged -- see the [Build Anything grid](../quick-guide/project-kinds.md) for the current taxonomy.

---

### jac-byllm folded into `jaclang` core

`jac-byllm` is no longer a separate PyPI package or plugin. The `by llm()` feature is now built into `jaclang` core and importable as `jaclang.byllm` (was `byllm`). This is a **clean break** -- there is no backward-compatible `byllm` package or import shim.

**Impact:**

- There is no more `pip install byllm` / `jac install -e jac-byllm`. byLLM ships inside the `jac` binary.
- Code that did `import from byllm...` must change to `import from jaclang.byllm...` (e.g. `import from byllm.lib { Model }` becomes `import from jaclang.byllm.lib { Model }`; `import from byllm.llm { Model }` becomes `import from jaclang.byllm.llm { Model }`).
- byLLM's third-party dependencies (litellm, pillow, ...) are no longer installed via the `byllm` package. Instead they form the `llm` capability: declare `[byllm]` in `jac.toml` and run `jac install`; the capability registry resolves litellm + pillow into the project's `.jac/venv`. Optional runtimes are separate capabilities -- `llm.local` (llama-cpp-python, huggingface_hub), `llm.mcp` (mcp), `llm.video` (opencv). Using a real model without the `llm` capability raises an actionable "run `jac install`" error.

**Unchanged from a user's perspective:** the `by llm()` syntax, `[byllm.*]` config, and the `jac model` CLI behave exactly as before -- only the packaging and import path changed.

---

### jac-scale folded into `jaclang` core

`jac-scale` is no longer a separate PyPI package or plugin. Its serving and deployment subsystem is now built into `jaclang` core and importable as `jaclang.scale` (was `jac_scale`). This is a **clean break** -- there is no backward-compatible `jac-scale` package or `jac_scale` import shim.

**Impact:**

- There is no more `jac install jac-scale` / `jac install 'jac-scale[...]'` / `pip install jac-scale`. The scale subsystem ships inside the `jac` binary.
- Code that did `import from jac_scale...` (e.g. `import from jac_scale.persistence.lib { kvstore }`) must change to `import from jaclang.scale...` (e.g. `import from jaclang.scale.persistence.lib { kvstore }`).
- `jac plugins enable scale` is no longer needed -- scale is always available.
- Scale's optional third-party dependencies (fastapi, pymongo, redis, kubernetes, prometheus-client, ...) are no longer installed via package extras. Instead, declare the matching `[scale.*]` config in `jac.toml` and run `jac install`; the capability registry resolves the required libraries into the project's `.jac/venv`.

**Unchanged from a user's perspective:** `jac start`, `jac start --scale`, and all `[scale.*]` config behave exactly as before -- only the packaging changed.
