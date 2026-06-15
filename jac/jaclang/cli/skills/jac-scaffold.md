---
name: jac-scaffold
description: Bootstrapping a new Jac project - `jac create --use <template>`, what each lays out, post-scaffold checklist, and choosing standard vs jac-shadcn. Load when starting a new project from scratch. Pair with `jac-project-kinds` (choose the right kind first), `jac-fullstack-patterns` (fullstack wiring), `jac-shadcn-components` (jac-shadcn primitives).
---

Use the Jac CLI's `jac create` to scaffold new projects. It is the single source of truth for project layout and stays current with Jac releases.

## `jac create` - the only scaffolder

```
jac create myapp                       # default: minimal backend project
jac create myapp --use client          # client-only template  (needs jac-client)
jac create myapp --use fullstack       # fullstack template     (needs jac-client)
jac create myapp --use ./my-template/  # from a local template DIRECTORY
jac create myapp --use ./local.jacpack # from a local jacpack archive
jac create --use https://.../t.jacpack # from a URL
jac create --list_jacpacks             # list available templates
jac create myapp --force               # overwrite an existing dir / reinit
```

Without a project name, `jac create` initializes the **current directory** and names the project after it (like `cargo init` / `uv init`). Pass a name to create a subdirectory instead (`jac create myapp`).

**The flag is `--list_jacpacks` (underscore), not `--list-jacpacks`** - the hyphen form is rejected with `unrecognized arguments`.

**`client` and `fullstack` are provided by the `jac-client` plugin.** Only `default` ships with `jaclang`. Without `jac-client` installed, `jac create --use client` fails with `Unknown jacpack template`, and `--list_jacpacks` shows only `default`. Run `jac install` / `pip install jac-client` first, or check `--list_jacpacks` to see what is actually available.

## Templates and what each lays out

| `--use <template>` | When to pick it | What ships |
|---|---|---|
| (omitted) `default` | Backend / library project, no UI | `main.jac` (a `with entry` stub), `jac.toml`, `AGENTS.md`, `.gitignore` |
| `client` | Pure client app, no server data | `main.jac` (`to cl:` + `def:pub app`), `components/Button.cl.jac`, `assets/`, `jac.toml`, `README.md`, `AGENTS.md`, `.gitignore` |
| `fullstack` | Client UI + server endpoints | `main.jac`, `endpoints.sv.jac`, `frontend.cl.jac` + `frontend.impl.jac`, `components/*.cl.jac`, `assets/`, `jac.toml`, `README.md`, `AGENTS.md`, `.gitignore` |
| `jac-shadcn` | Client UI with shadcn component system | same as `client` + `components/ui/` (pre-installed button + card), `lib/utils.cl.jac` (`cn()`), `styles/global.css` (themed CSS vars), `[jac-shadcn]` block in `jac.toml` |

The `default` template's `main.jac` is a minimal `with entry { ... }` stub - it does **not** pre-wire endpoints; add `node`/`def:pub` declarations yourself (see `jac-sv-endpoints`).

## Choosing a UI method

| Method | When to use | Template |
|---|---|---|
| Standard (plain Jac JSX + Tailwind) | Full control, no pre-built primitives, research spikes | `--use client` or `--use fullstack` |
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
5. **Run the project**: a bare `jac run` (no filename) dispatches on the project's `kind` in `jac.toml` - execute / serve / build as appropriate (`jac run --show` prints the plan first). For fullstack, `jac start --dev` runs the server with hot reload. NOT `jac serve` (deprecated).
6. QA in a headless browser with `jac browse`: `jac browse open localhost:8000`, `jac browse snapshot`, `jac browse click @e5`, `jac browse close`. See `jac-fullstack-patterns` for the full loop.

## Make your own template

Any Jac project becomes a template by adding a `[jacpack]` section to its `jac.toml`; `{{name}}` placeholders in files are substituted at create time:

```toml
[jacpack]
name = "mytemplate"
description = "My custom project template"
```

```
jac jacpack list                       # registered templates (same list as --list_jacpacks)
jac jacpack pack ./my-template/        # bundle dir -> mytemplate.jacpack
jac jacpack info ./my-template/        # inspect a template DIRECTORY
jac create app --use ./my-template/    # use directly, no packing needed
jac create app --use mytemplate.jacpack
```

All non-`[jacpack]` sections of the template's `jac.toml` become the created project's config.

## Pitfalls

- **Generate `jac.toml` via `jac create`, then edit specific sections as needed** - load `jac-config` for the full section map (`[serve]`, `[scripts]`, `[check.lint]`, ...) before hand-editing.
- **Match the template to the user's actual need.** Picking `fullstack` for a UI-only spike adds unused server scaffolding; picking `client` for an app that needs persistence forces a later migration.
- **Don't scaffold into a non-empty workspace.** The named form inside an existing project nests silently (see above); inspect the workspace first and extend an existing project instead.
- **`-s` / `--skip` on `jac create --use client`** skips npm install - convenient for offline scaffolding, but you'll need `jac install` before running.
- **Project-name argument is optional.** Omit it to scaffold in cwd; pass a name to create `cwd/<name>/`.
