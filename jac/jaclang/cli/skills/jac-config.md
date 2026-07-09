---
name: jac-config
description: The jac.toml control plane - every section ([project], [dependencies], [serve], [run], [check.lint], [test], [scripts], [environments], capability tables ([byllm], [scale], [client] incl. app_meta_data, [desktop]), [jac-shadcn], [npm], [jacpack]), ${VAR} interpolation, profiles via JAC_PROFILE, .jacignore, and the CLI verbs that manage it (jac config/add/install/remove/update/x). Load before editing jac.toml or wiring project settings, dependencies, scripts, or environment profiles.
---

`jac.toml` is the single config file (think `pyproject.toml` + `package.json`). Commands find it by walking up from cwd. Generate it with `jac create`, then edit sections directly or via `jac config set` / `jac add` - hand-editing is normal and expected.

## Section map

| Section | Purpose |
|---|---|
| `[project]` | name (required), version, description, **`entry-point`** (default for `jac run`/`jac start`, defaults to `main.jac`), **`kind`** (project kind that makes a bare `jac run` execute / serve / build the project - empty = inferred from the entry-point codespace; see `jac-project-kinds`), `jac-version` compiler pin; publishing fields (`license`, `readme`, `requires-python`, `classifiers`, `authors`) feed `jac build --as wheel` (see `jac-packaging`) |
| `[dependencies]` | PyPI packages, pip-style specs (`requests = ">=2.28.0"`) |
| `[dependencies.npm]` / `[dependencies.npm.dev]` | npm packages for client code (see `jac-npm-packages`) |
| `[dependencies.git]` | `mylib = { git = "https://...", branch = "main" }` |
| `[dev-dependencies]` | dev-only tools; installed with `jac install --dev` |
| `[optional-dependencies.<group>]` | extras: `jac install --extras <group>`, wheel extras on publish |
| `[serve]` | `jac start` defaults: `port`, `base_route_app` (client app served at `/`), `cl_route_prefix` |
| `[run]` | `jac run` defaults: `cache`, `session`, `diagnostics` (`"error"`/`"all"`/`"none"`) |
| `[check]` | type-check behavior: `enforce_access` (promote `:pub`/`:protect`/`:priv` visibility violations from warnings to hard errors), `warn_native_seams` (warn when a native-eligible method falls back to Python) |
| `[check.lint]` | lint rule selection: `select = ["default"]` / `["all"]`, `ignore = ["combine-has"]`, `exclude = ["legacy/*"]` |
| `[test]` | `jac test` defaults: `directory`, `filter`, `verbose`, `fail_fast`, `max_failures` |
| `[build]` | `typecheck`, `dir` (artifact root, default `.jac/` - holds `cache/`, `venv/`, `client/`, `data/`) |
| `[scripts]` | named command shortcuts run via `jac x <name>` |
| `[environments]` / `[environment]` | per-profile overrides (below) |
| `[byllm]` / `[byllm.model]` / `[byllm.call_params]` | AI settings: model identity, API keys, call params (see `jac-by-llm`) |
| `[scale.*]` | serving/deployment settings: `[scale.server]`, `[scale.database]`, `[scale.kubernetes]`, ... (see `jac-sv-deploy`) |
| `[client]` | `framework` = `"react"` (default) / `"preact"` / `"solid"` (experimental) - which JS framework the `cl` target emits; `[client.routing] auth_redirect = "/path"` for unauthenticated redirects |
| `[client.app_meta_data]` | served page's head/SEO config: `title`, `description`, `keywords`, `author`, `theme_color`, `icon` |
| `[desktop]` / `[desktop.plugins]` | desktop app identity + window geometry; per-capability OS-plugin gates (`fs`/`clipboard`/`shell` allow-lists) - see `jac-desktop-app` |
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
[byllm.model]
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

## Built-in capabilities

byLLM, scale, the client/desktop framework, and the MCP server all ship inside the `jac` binary - there is no plugin system, nothing to enable or disable, and no `jac plugins` command. Configure a capability with its top-level table (`[byllm]`, `[scale.*]`, `[client]`, `[desktop]`) and run `jac install` to resolve its optional third-party dependencies into `.jac/venv` (e.g. a `[byllm]` model config pulls litellm/pillow; `[scale.database]` pulls pymongo). Old `[plugins.<name>]` config paths no longer parse - use the top-level names.

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
