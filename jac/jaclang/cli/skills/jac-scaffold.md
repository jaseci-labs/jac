---
name: jac-scaffold
description: Bootstrapping a new Jac project - how to use `jac create --use <template>`, what each template lays out on disk, how to fix the deprecated syntax it ships with, and the post-scaffold checklist. Load when starting a new project from scratch. Pair with `jac-fullstack-patterns` when building fullstack.
---

Use the Jac CLI's `jac create` to scaffold new projects. Run it via `run_command(...)`. JacCoder no longer ships its own scaffolder - `jac create` is the single source of truth and stays current with Jac releases.

## `jac create` - the only scaffolder

```
jac create myapp                       # default: minimal backend project
jac create myapp --use client          # client-only template  (needs jac-client)
jac create myapp --use fullstack       # fullstack template     (needs jac-client)
jac create myapp --use ./local.jacpack # from a local jacpack archive
jac create --use https://.../t.jacpack # from a URL
jac create --list_jacpacks             # list available templates
```

Always pass an explicit project name - without one, `jac create` falls back to `jactastic`, `jactastic1`, etc.

**`client` and `fullstack` are provided by the `jac-client` plugin.** Only `default` ships with `jaclang`. Without `jac-client` installed, `jac create --use client` fails with `Unknown jacpack template`, and `--list_jacpacks` shows only `default`. Run `jac install` / `pip install jac-client` first, or check `--list_jacpacks` to see what is actually available.

## Templates and what each lays out

| `--use <template>` | When to pick it | What ships |
|---|---|---|
| (omitted) `default` | Backend / library project, no UI | `main.jac` (a `with entry` stub), `jac.toml`, `AGENTS.md`, `.gitignore` |
| `client` | Pure client app, no server data | `main.jac` (`to cl:` + `def:pub app`), `components/Button.cl.jac`, `jac.toml`, `README.md`, `.gitignore` |
| `fullstack` | Client UI + server endpoints | `main.jac`, `endpoints.sv.jac`, `frontend.cl.jac` + `frontend.impl.jac`, `components/*.cl.jac`, `jac.toml`, `README.md`, `.gitignore` |

The `default` template's `main.jac` is a minimal `with entry { ... }` stub - it does **not** pre-wire endpoints; add `node`/`def:pub` declarations yourself (see `jac-sv-endpoints`).

## Always do this before scaffolding

`jac create` will create a subdirectory at `cwd/<name>` (or `<directory>/<name>` if you pass one). It does NOT detect or refuse if a Jac project already exists nearby - you'll silently nest a new project inside an existing one.

Before running `jac create`:

1. `list_files(workspace)` - see what's already there
2. If `jac.toml` is present at the workspace root, **do NOT scaffold a new project** - extend the existing one with `write_code` / `edit_code` instead
3. If the workspace is empty, then `jac create` is safe

When called by JacBuilder or any IDE harness, the workspace usually already has a project. Scaffolding into it creates a nested mess. Read first.

## Adapt the output - the `fullstack` template ships deprecated syntax

The `fullstack` template's `main.jac` still uses the old `cl { ... }` / `sv { ... }` braced blocks, which trigger **W0064**. (The `client` template is already on the modern `to cl:` form - no adaptation needed.) After scaffolding `fullstack`:

1. Open `main.jac`
2. Replace the `sv { ... }` block with plain top-level imports (server is the default context)
3. Replace the `cl { ... }` block with a `to cl:` section header
4. Move client imports under `to cl:`

See `jac-fullstack-patterns` for the canonical `main.jac` shape after this fix.

## Post-scaffold checklist

After `jac create`:

1. `cd <project>`
2. For the `fullstack` template, adapt the `cl { }` / `sv { }` blocks (see above) before running anything
3. Add any additional npm deps to `jac.toml` (see `jac-npm-packages` skill for format)
4. `jac install` - run after all jac.toml changes are final
5. `jac start --dev main.jac` (background, for hot reload). NOT `jac serve` (deprecated).

## Pitfalls

- **Don't hand-write `jac.toml`.** Generate it via `jac create`. For Tailwind setup, follow Build Workflow step 4 for the exact jac.toml format. Load `jac-cl-styling` for styling patterns.
- **Match the template to the user's actual need.** Picking `fullstack` for a UI-only spike adds unused server scaffolding; picking `client` for an app that needs persistence forces a later migration.
- **Don't scaffold into a non-empty workspace.** Run `list_files` first; if a project exists, extend it.
- **`-s` / `--skip` on `jac create --use client`** skips npm install - convenient for offline scaffolding, but you'll need `jac install` before running.
- **Project-name argument is optional but defaults to `jactastic`.** Always pass an explicit name.
