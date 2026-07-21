# Breaking Changes

This page documents significant breaking changes in Jac and Jaseci that may affect your existing code or workflows. Use this information to plan and execute updates to your applications.

!!! note
    MTLLM library is now deprecated and replaced by the byLLM package. In all places where `mtllm` was used before, it can be replaced with `byllm`.

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

**Impact:** rewrite any `to cl:` / `to sv:` / `to na:` section into the matching braced block, wrapping exactly the statements that belonged to that section. Single-statement prefixes (`cl def:pub foo() {...}`, `sv ...`, `na ...`) and file-extension contexts (`.cl.jac`, `.na.jac`) are unaffected. (At the time, `to` still drove the iter-for loop; `to` has since been removed as a keyword entirely -- see [the clean-break entry above](#legacy-syntax-removed-in-one-clean-break-7514).)

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
