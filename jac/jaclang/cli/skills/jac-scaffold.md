---
name: jac-scaffold
description: Bootstrapping a new Jac project - `jac create --use <template>`, what each lays out, post-scaffold checklist, and choosing standard vs jac-shadcn. Load when starting a new project from scratch. Pair with `jac-project-kinds` (choose the right kind first), `jac-fullstack-patterns` (fullstack wiring), `jac-shadcn-components` (jac-shadcn primitives).
---

Use the Jac CLI's `jac create` to scaffold new projects. It is the single source of truth for project layout and stays current with Jac releases.

## `jac create` - the only scaffolder

`jac create` is **kind-aware**: `--kind <kind>` scaffolds a project for a
specific project *kind*. It stamps `[project] kind` into `jac.toml`, lays down
the entry-point in the right codespace, and produces a project whose bare
`jac run` does the natural action for that kind (execute / serve / build).

```
jac create myapp                        # cli kind (default): a runnable script
jac create myapp --kind service     # headless server walkers (serve)
jac create myapp --kind native-binary   # natively-compiled binary (build dist/)
jac create myapp --kind web-app       # server + client UI    (built into jaclang)
jac create myapp --kind desktop         # OS-webview app         (built into jaclang)
jac create myapp --use ./my-template/   # from a local template DIRECTORY
jac create myapp --use ./local.jacpack  # from a local jacpack archive
jac create --use https://.../t.jacpack  # from a URL
jac create --use jac-shadcn             # shadcn variant of web-app (built into jaclang)
jac create --list                       # list available kinds and named variants
jac create myapp --force                # overwrite an existing dir / reinit
```

Without a project name, `jac create` initializes the **current directory** and names the project after it (like `cargo init` / `uv init`). Pass a name to create a subdirectory instead (`jac create myapp`).

`--kind` and `--use` are mutually exclusive: `--kind` picks a built-in kind template; `--use` loads a custom template (path / URL) or a named variant.

## Project kinds and what each scaffolds

`--kind` accepts any of the 12 project kinds -- **all built into `jaclang` core**, so none require a separate plugin install. (The full-stack client/desktop kinds were folded in from the former `jac-client` / `jac-desktop` plugins.)

| `--kind` | Provider | `jac run` does | Entry-point |
|---|---|---|---|
| `cli` *(default)* | core | execute the script | `main.jac` |
| `cli-native` | core | native-compile + run (JIT) | `main.jac` |
| `native-binary` | core | build a binary into `dist/` | `main.jac` |
| `native-lib` | core | build a `.so`/`.dylib`/`.dll` | `main.jac` |
| `service` | core | serve headless API (no client) | `main.sv.jac` |
| `service-mesh` | core | serve microservice | `main.sv.jac` |
| `py-package` | core | build a wheel into `dist/` | `lib.jac` |
| `js-package` | core | build an npm tarball into `dist/` | `lib.jac` |
| `web-app` | core | serve app (dev mode) | `main.jac` + `.sv` |
| `web-static` | core | serve client-only page | `main.jac` |
| `mobile` | core | build the mobile app | `main.jac` |
| `desktop` | core | run the OS-webview app | `main.jac` |

Named variants (selected with `--use`, not `--kind`) layer on a kind:

| `--use <variant>` | Kind | Provider | What it adds |
|---|---|---|---|
| `jac-shadcn` | web-app | jaclang (built-in) | shadcn `components/ui/`, `lib/utils.jac` (`cn()`), themed `global.css`, `[jac-shadcn]` block |

The `cli` template's `main.jac` is a minimal `with entry { ... }` stub - it does **not** pre-wire endpoints; use `--kind service` for a server, or add `node`/`walker:pub` declarations yourself (see `jac-sv-endpoints`).

## Choosing a UI method

| Method | When to use | How to scaffold |
|---|---|---|
| Standard (plain Jac JSX + Tailwind) | Full control, no pre-built primitives, research spikes | `--kind web-app` (or `--kind web-static` for client-only) |
| jac-shadcn | Production UI with 53 accessible primitives, fast iteration | `--use jac-shadcn` |

Detect from an existing project: check `jac.toml` for a `[jac-shadcn]` section, or look for a `components/ui/` directory. **Do NOT mix methods** - raw HTML form elements in a shadcn project ignore available primitives; importing `components/ui/` primitives in a non-shadcn project fails with unresolved module errors.

## Always do this before scaffolding

The behavior depends on which form you use:

- **No-name form in cwd** (`jac create`): refuses if you are already inside a Jac project - `Already in a Jac project: .../jac.toml. Use --force to reinitialize.`
- **Named form** (`jac create myapp`): refuses if `myapp/` already exists - `Directory 'myapp' already exists. Use --force to overwrite.`
- **Named form run INSIDE an existing project** (`cd myproj && jac create other`): **nests silently** - it happily creates `myproj/other/` with its own `jac.toml`. This is the one case with no guardrail.

So before running the named form:

1. List the workspace contents - see what's already there
2. If `jac.toml` is present at the workspace root, **do NOT scaffold a new project** - extend the existing one in place instead
3. If the workspace is empty, then `jac create` is safe

## Post-scaffold checklist

After `jac create`:

1. `cd <project>`
2. Add any additional npm deps to `jac.toml` (see `jac-npm-packages` skill for format)
3. `jac install` - run after all jac.toml changes are final
4. **Verify the scaffold compiles**: `jac check .` (then `jac run main.jac` for backend projects)
5. **Run the project**: a bare `jac run` (no filename) dispatches on the project's `kind` in `jac.toml` - execute / serve / build as appropriate (`jac run --show` prints the plan first). For web-app, `jac start --dev` runs the server with hot reload. NOT `jac serve` (deprecated).
6. QA in a headless browser with `jac browse`: `jac browse open localhost:8000`, `jac browse snapshot`, `jac browse click @e5`, `jac browse close`. See `jac-fullstack-patterns` for the full loop.

## Make your own template

Any Jac project becomes a template by adding a `[jacpack]` section to its `jac.toml`; `{{name}}` placeholders in files are substituted at create time:

```toml
[jacpack]
name = "mytemplate"
description = "My custom project template"
```

```
jac create --list                      # registered kinds and named variants
jac create --pack ./my-template/       # bundle dir -> mytemplate.jacpack (--pack_output for a custom path)
jac create app --use ./my-template/    # use directly, no packing needed
jac create app --use mytemplate.jacpack
```

All non-`[jacpack]` sections of the template's `jac.toml` become the created project's config.

## Pitfalls

- **Generate `jac.toml` via `jac create`, then edit specific sections as needed** - load `jac-config` for the full section map (`[serve]`, `[scripts]`, `[check.lint]`, ...) before hand-editing.
- **Match the template to the user's actual need.** Picking `web-app` for a UI-only spike adds unused server scaffolding; picking `web-static` for an app that needs persistence forces a later migration.
- **Don't scaffold into a non-empty workspace.** The named form inside an existing project nests silently (see above); inspect the workspace first and extend an existing project instead.
- **Setting `JAC_CLIENT_SKIP_NPM_INSTALL=1` for `--kind web-app`/`web-static`/`mobile`** skips the Bun/npm install - convenient for offline scaffolding, but you'll need `jac install` before running.
- **Project-name argument is optional.** Omit it to scaffold in cwd; pass a name to create `cwd/<name>/`.
