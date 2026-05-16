---
name: jac-scaffold
description: Bootstrapping a new Jac project - how to use `jac create --use <template>`, what each template lays out on disk, how to fix the deprecated syntax it ships with, and the post-scaffold checklist. Load when starting a new project from scratch. Pair with `jac-fullstack-patterns` when building fullstack.
---

Use the Jac CLI's `jac create` to scaffold new projects. Run it via `run_command(...)`. JacCoder no longer ships its own scaffolder - `jac create` is the single source of truth and stays current with Jac releases.

## `jac create` - the only scaffolder

```
jac create myapp                       # default: empty backend project
jac create myapp --use client          # client-only template
jac create myapp --use fullstack       # fullstack template
jac create myapp --use ./local.jacpack # from a local jacpack archive
jac create --use https://.../t.jacpack # from a URL
jac create --list_jacpacks             # list available templates
```

Always pass an explicit project name - without one, `jac create` falls back to `jactastic`, `jactastic1`, etc.

## Templates and what each lays out

| `--use <template>` | When to pick it | What ships |
|---|---|---|
| (omitted) | Pure REST/RPC backend, no UI | `main.jac` (with node + `def:pub` endpoints), `jac.toml` |
| `client` | Pure client app, no server data | `main.jac`, `components/`, `lib/utils.cl.jac`, `styles/global.css`, `jac.toml` |
| `fullstack` | Client UI + server endpoints + auth | `main.jac` (server imports + `to cl:` + `def:pub app()`), `services/*.sv.jac`, `hooks/*.cl.jac`, `components/`, `lib/utils.cl.jac`, `styles/global.css`, `jac.toml` |

The fullstack layout matches `jac-fullstack-patterns`: server imports plain at the top of `main.jac`, `to cl:` opens the client section, services in `services/*.sv.jac`, hooks call them with `sv import from`.

## Always do this before scaffolding

`jac create` will create a subdirectory at `cwd/<name>` (or `<directory>/<name>` if you pass one). It does NOT detect or refuse if a Jac project already exists nearby - you'll silently nest a new project inside an existing one.

Before running `jac create`:

1. `list_files(workspace)` - see what's already there
2. If `jac.toml` is present at the workspace root, **do NOT scaffold a new project** - extend the existing one with `write_code` / `edit_code` instead
3. If the workspace is empty, then `jac create` is safe

When called by JacBuilder or any IDE harness, the workspace usually already has a project. Scaffolding into it creates a nested mess. Read first.

## Adapt the output - `jac create` ships deprecated syntax

`jac create --use fullstack` (and `--use client`) generate code with the old `cl { ... }` / `sv { ... }` braced blocks. These trigger W0064 and will not work going forward. After scaffolding:

1. Open `main.jac`
2. Replace `cl { ... }` blocks with a `to cl:` section header
3. Replace `sv { ... }` blocks with a `to sv:` section header
4. Replace any `cl import …` / `sv import …` prefixes with plain `import from …` (server) or move under `to cl:` (client)

See `jac-fullstack-patterns` for the canonical `main.jac` shape after this fix.

## Post-scaffold checklist

After `jac create`:

1. `cd <project>`
2. Adapt `cl { }` / `sv { }` blocks (see above) - fix deprecated syntax before running anything
3. Add any additional npm deps to `jac.toml` (see `jac-npm-packages` skill for format)
4. `jac install` - run after all jac.toml changes are final
5. `jac start --dev main.jac` (background, for hot reload). NOT `jac serve` (deprecated).

## Pitfalls

- **Don't hand-write `jac.toml`.** Generate it via `jac create`. For Tailwind setup, follow Build Workflow step 4 for the exact jac.toml format. Load `jac-cl-styling` for styling patterns.
- **Match the template to the user's actual need.** Picking `fullstack` for a UI-only spike adds unused server scaffolding; picking `client` for an app that needs persistence forces a later migration.
- **Don't scaffold into a non-empty workspace.** Run `list_files` first; if a project exists, extend it.
- **`-s` / `--skip` on `jac create --use client`** skips npm install - convenient for offline scaffolding, but you'll need `jac install` before running.
- **Project-name argument is optional but defaults to `jactastic`.** Always pass an explicit name.
