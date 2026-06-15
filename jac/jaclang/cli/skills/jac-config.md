---
name: jac-config
description: The jac.toml control plane - every section ([project], [dependencies], [serve], [run], [check.lint], [test], [scripts], [environments], [plugins.*] incl. app_meta_data, [jac-shadcn], [npm], [jacpack]), ${VAR} interpolation, profiles via JAC_PROFILE, .jacignore, and the CLI verbs that manage it (jac config/add/install/remove/update/script/plugins). Load before editing jac.toml or wiring project settings, dependencies, scripts, or environment profiles.
---

`jac.toml` is the single config file (think `pyproject.toml` + `package.json`). Commands find it by walking up from cwd. Generate it with `jac create`, then edit sections directly or via `jac config set` / `jac add` - hand-editing is normal and expected.

## Section map

| Section | Purpose |
|---|---|
| `[project]` | name (required), version, description, **`entry-point`** (default for `jac run`/`jac start`, defaults to `main.jac`), `jac-version` compiler pin; publishing fields (`license`, `readme`, `requires-python`, `classifiers`, `authors`) feed `jac bundle` (see `jac-packaging`) |
| `[dependencies]` | PyPI packages + Jac plugins, pip-style specs (`requests = ">=2.28.0"`) |
| `[dependencies.npm]` / `[dependencies.npm.dev]` | npm packages for client code (see `jac-npm-packages`) |
| `[dependencies.git]` | `mylib = { git = "https://...", branch = "main" }` |
| `[dev-dependencies]` | dev-only tools; installed with `jac install --dev` |
| `[optional-dependencies.<group>]` | extras: `jac install --extras <group>`, wheel extras on publish |
| `[serve]` | `jac start` defaults: `port`, `base_route_app` (client app served at `/`), `cl_route_prefix` |
| `[run]` | `jac run` defaults: `cache`, `session`, `diagnostics` (`"error"`/`"all"`/`"none"`) |
| `[check.lint]` | lint rule selection: `select = ["default"]` / `["all"]`, `ignore = ["combine-has"]`, `exclude = ["legacy/*"]` |
| `[test]` | `jac test` defaults: `directory`, `filter`, `verbose`, `fail_fast`, `max_failures` |
| `[build]` | `typecheck`, `dir` (artifact root, default `.jac/` - holds `cache/`, `venv/`, `client/`, `data/`) |
| `[scripts]` | named command shortcuts run via `jac script <name>` |
| `[environments]` / `[environment]` | per-profile overrides (below) |
| `[plugins]` | `enabled` / `disabled` lists; `[plugins.<name>.*]` plugin settings (byllm models, scale server, client paths/vite) |
| `[plugins.client.app_meta_data]` | served page's head/SEO config: `title`, `description`, `keywords`, `author`, `theme_color`, `icon` |
| `[jac-shadcn]` | theme config (`style`, `baseColor`, `theme`, `font`, `radius`) managed by `jac add --shadcn` / `jac retheme` - don't hand-edit (see `jac-shadcn-components`) |
| `[npm]` | npm-publish overrides: `name = "@scope/pkg"`, `entry` (see `jac-packaging`) |
| `[jacpack]` | marks the project as a `jac create` template (see `jac-scaffold`) |

## Dependency verbs (don't pip-install into a Jac project by hand)

```
jac add requests              # install + record requests = "~=2.32" (auto-pinned to installed major.minor)
jac add pytest --dev          # -> [dev-dependencies]
jac add mylib --git https://github.com/user/repo.git
jac install                   # install everything in jac.toml (incl. npm deps)
jac install --dev --extras data
jac install -e /path/to/lib   # editable install of a sibling Jac package
jac remove requests           # uninstall + delete from jac.toml
jac update                    # bump deps; only rewrites the auto-generated ~= pins
```

## `jac config` - read/write settings from the CLI

```
jac config show               # explicitly-set values         jac config get project.name
jac config list -g serve      # all values incl. defaults     jac config set serve.port 3000
jac config groups             # list section groups           jac config unset run.cache
jac config path               # where the jac.toml is         jac config list -o toml
```

## Environment variables and profiles

`${VAR}` interpolation works in any string value:

```toml
[plugins.byllm.model]
api_key = "${OPENAI_API_KEY}"                  # error if unset
default_model = "${LLM_MODEL:-gpt-4o-mini}"    # default if unset
base_url = "${BASE_URL:?Base URL is required}" # custom error if unset
```

Profiles layer overrides per environment; activate with `JAC_PROFILE=production jac run main.jac` or the `--profile` flag on `jac run`/`jac start`/`jac test`:

```toml
[environment]
default_profile = "development"

[environments.development.run]
cache = false

[environments.production]
inherits = "development"
[environments.production.run]
cache = true
```

## Plugins

```
jac plugins                   # list installed (same as `jac plugins list`)
jac plugins disable byllm     # writes to [plugins].disabled in jac.toml
jac plugins enable byllm
jac plugins disabled          # list disabled
```

Install/uninstall plugins with pip (`pip install jac-client`); `jac plugins` only toggles already-installed ones. **There is no `jac plugins info` action.** The env var `JAC_DISABLED_PLUGINS` disables plugins without touching jac.toml (useful when a broken plugin blocks the CLI itself).

## .jacignore

`.jacignore` at the project root excludes files from compilation/analysis - one pattern per line, `.gitignore`-style (`*.generated.jac`, `test_fixtures/`).

## Pitfalls

- **Hyphen vs underscore is per-key and unforgiving**: `entry-point`, `requires-python`, `jac-version` (hyphens) but `fail_fast`, `max_failures`, `cl_route_prefix`, `base_route_app` (underscores). A wrong form is silently ignored - verify with `jac config get <key>`.
- **`jac add` without a version pins `~=major.minor`** of whatever pip resolved - pass an explicit spec (`jac add "requests>=2.28"`) when you need a different constraint.
- **CLI flags override jac.toml for that run** (`jac start --port 3000`, `jac test -v`, `jac run -e all`); jac.toml only sets defaults.
- **After editing `[dependencies*]`, run `jac install`** - editing the file alone installs nothing.

## See also

- `jac-packaging` - publishing fields, `[entrypoints]`, `[npm]`, extras on the wheel
- `jac-scaffold` - generating jac.toml, `[jacpack]` templates
- `jac-testing` / `jac-debugging` - `[test]`, `[check.lint]`, `[run] diagnostics` in action
