---
name: jac-config
description: Edit jac.toml project, app, dependency, build, and runtime settings. Use when selecting configuration keys or resolving configuration errors.
---

`jac.toml` is the single config file (think `pyproject.toml` + `package.json`). Commands find it by walking up from cwd. Generate it with `jac create`, then edit sections directly or via `jac config set` / `jac install <pkg>` - hand-editing is normal and expected.

## Section map

| Section | Purpose |
|---|---|
| `[project]` | name (required), version, description, **`entry-point`** (default for `jac run`, defaults to `main.jac`), **`kind`** (project kind that makes a bare `jac run` execute / serve / build the project - empty = inferred from the entry-point codespace; see `jac-project-kinds`), **`default-app`** (workspaces: the app a bare `jac run`/`build`/`test`/`setup` targets), `jac-version` compiler pin; publishing fields (`license`, `readme`, `requires-python`, `classifiers`, `authors`) feed `jac build --as wheel` (see `jac-packaging`). `entry-point` and `kind` are single-app only - alongside `[apps]` they are a hard error |
| `[apps.<name>]` | one table per app turns the project into a **workspace**: `kind` (required; decides the client too: `web-app`/`web-static`/`desktop` render React DOM, `mobile` is React Native through `@jac/mobui`), `entry-point` (required, relative to the project root), `platform`, `route` (default `/api/<name>`). Ordinary imports inherit the selected app context. No `[apps]` = one implicit app. See `jac-sv-microservices` for service apps |
| `[apps.<name>.<section>]` | per-app **overlay** of any section (`[apps.web.serve]`, `[apps.mobile.dependencies.npm]`, `[apps.svc.scale]`, `[apps.web.placement.pins]`), deep-merged over the base for that app only. Effective config = base → app overlays → profile → `jac.local.toml` |
| `[dependencies]` | PyPI packages, pip-style specs (`requests = ">=2.28.0"`) |
| `[dependencies.npm]` / `[dependencies.npm.dev]` | npm packages for client code (see `jac-npm-packages`); `[dependencies.npm.web]` / `.static` / `.desktop` / `.mobile` scope a table to one client kind, `[dependencies.npm.native]` feeds a mobile app's Expo project |
| `[dependencies.git]` | `mylib = { git = "https://...", branch = "main" }` |
| `[dev-dependencies]` | dev-only tools; installed with `jac install --dev` |
| `[optional-dependencies.<group>]` | extras: `jac install --extras <group>`, wheel extras on publish |
| `[serve]` | `jac run` defaults: `port`, `session`, `on_conflict` (the served app's client is at `/`; sibling apps with a built bundle at `/cl/<app>/`) |
| `[run]` | `jac run` defaults: `cache`, `session`, `diagnostics` (`"error"`/`"all"`/`"none"`) |
| `[check]` | type-check behavior: `enforce_access` (promote `:pub`/`:protect`/`:priv` visibility violations from warnings to hard errors), `warn_native_seams` (warn when a native-eligible method falls back to Python) |
| `[check.lint]` | lint rule selection: `select = ["default"]` / `["all"]`, `ignore = ["combine-has"]`, `exclude = ["legacy/*"]` |
| `[test]` | `jac test` defaults: `directory`, `filter`, `verbose`, `fail_fast`, `max_failures` |
| `[build]` | `dir` (artifact root, default `.jac/` - holds `cache/`, `venv/`, `client/`, `data/`) |
| `[memory]` | the memory profile: `profile = "managed"/"rc"/"nogc"` (overridable per build with `--memory`); `enforce`/`exempt` glob patterns hold modules to the zero-RC contract under a managed profile (see `jac-native-memory`) |
| `[native]` | native build knobs: `target`, `opt`, `debug`, `threads` |
| `[placement]` | `default = "native"/"server"` for markerless modules, beside `[placement.pins]` |
| `[scripts]` | named command shortcuts run via `jac x <name>` |
| `[environments]` / `[environment]` | per-profile overrides (below) |
| `[byllm]` / `[byllm.model]` / `[byllm.call_params]` | AI settings: model identity, API keys, call params (see `jac-by-llm`) |
| `[serve]` | the server process: host, port, workers, TLS, proxy, limits, timeouts, access log, compression, auth (every key has a `JAC_SERVE_*` mirror) |
| `[scale.*]` | deployment and scale features: `[scale.database]`, `[scale.kubernetes]`, `[scale.gateway]` (the fleet gateway: `colocate`, ports, `cors`, `rate_limit`, `logs`, `shared_volumes`), ... (see `jac-sv-deploy`, `jac-sv-microservices`) |
| `[client]` | `framework` = `"react"` (default) / `"preact"` / `"solid"` (experimental) - which JS framework the client bundle uses; `[client.routing] auth_redirect = "/path"` for unauthenticated redirects; `[client.pwa]` (theme_color, cache_name, install_banner...) turns a web app into a PWA at build; `[client.react_native]` holds a mobile app's Expo/EAS knobs - see `jac-mobile-app` |
| `[client.app_meta_data]` | served page's head/SEO config: `title`, `description`, `keywords`, `author`, `theme_color`, `icon` |
| `[desktop]` / `[desktop.plugins]` | desktop app identity, `engine` (`"native"` OS webview or `"cef"`) + window geometry; per-capability OS-plugin gates (`fs`/`clipboard`/`shell` allow-lists) - see `jac-desktop-app` |
| `[jac-shadcn]` | theme config (`style`, `baseColor`, `theme`, `font`, `radius`) managed by `jac install --shadcn` / `jac retheme` - don't hand-edit. Two paths you MAY set by hand: `components_dir` and `utils_path`, which tell the installer where your primitives and `cn()` live if not `components/ui/` and `lib/utils.jac` (see `jac-shadcn-components`) |
| `[npm]` | npm-publish overrides: `name = "@scope/pkg"`, `entry` (see `jac-packaging`) |
| `[jacpack]` | marks the project as a `jac create` template (see `jac-scaffold`) |

## Dependency verbs (don't pip-install into a Jac project by hand)

```
jac install requests          # install + record requests = "~=2.32" (auto-pinned to installed major.minor)
jac install pytest --dev      # -> [dev-dependencies]
jac install mylib --git https://github.com/user/repo.git
jac install numpy --no-save   # install into .jac/venv without recording in jac.toml
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

`${VAR}` interpolation works in **every** string value, uniformly - app tables, overlays, profiles, capability tables:

```toml
[byllm.model]
api_key = "${OPENAI_API_KEY}"                  # error if unset
default_model = "${LLM_MODEL:-gpt-4o-mini}"    # default if unset
base_url = "${BASE_URL:?Base URL is required}" # custom error if unset
```

Profiles layer overrides per environment; activate with `JAC_PROFILE=production jac run main.jac` or the `--profile` flag on `jac run`/`jac test`:

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

byLLM, scale, the client/desktop framework, and the MCP server all ship inside the `jac` binary - there is no plugin system, nothing to enable or disable, and no `jac plugins` command. Configure a capability with its top-level table (`[byllm]`, `[scale.*]`, `[client]`, `[desktop]`) and run `jac install` to resolve its optional third-party dependencies into `.jac/venv` (e.g. a `[byllm]` model config pulls litellm/pillow; `[scale.deploy] target = "kubernetes"` pulls the kubernetes/docker clients -- `[scale.database]` pulls nothing, the Postgres wire client is built in). Old `[plugins.<name>]` config paths no longer parse - use the top-level names.

## .jacignore

`.jacignore` at the project root excludes files from compilation/analysis - one pattern per line, `.gitignore`-style (`*.generated.jac`, `test_fixtures/`). A `jac scale deploy` honors it too: a parked tree is not staged into the app bundle, so it never reaches the pods or their boot compile.

## Pitfalls

- **Hyphen vs underscore is per-key and unforgiving**: `entry-point`, `requires-python`, `jac-version`, `default-app` (hyphens) but `fail_fast`, `max_failures`, `on_conflict`, `theme_color` (underscores). A wrong form is silently ignored - verify with `jac config get <key>` (`jac config list -g apps` for the app tables).
- **`[apps]` is exclusive with `[project] kind` / `entry-point`** - a hard config error (exit 2). An unknown key inside an `[apps.<name>]` table is also a hard error naming the accepted keys (`kind`, `path`, `entry-point`, `platform`, `route`).
- **`jac install <pkg>` without a version pins `~=major.minor`** of whatever pip resolved - pass an explicit spec (`jac install "requests>=2.28"`) when you need a different constraint.
- **CLI flags override jac.toml for that run** (`jac run --port 3000`, `jac test -v`, `jac run -e all`); jac.toml only sets defaults.
- **After editing `[dependencies*]`, run `jac install`** - editing the file alone installs nothing.

## See also

- `jac-packaging` - publishing fields, `[entrypoints]`, `[npm]`, extras on the wheel
- `jac-scaffold` - generating jac.toml, `[jacpack]` templates
- `jac-testing` / `jac-debugging` - `[test]`, `[check.lint]`, `[run] diagnostics` in action
