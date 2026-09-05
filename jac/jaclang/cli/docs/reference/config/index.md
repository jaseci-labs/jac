# Configuration Reference

The `jac.toml` file is the central configuration for Jac projects -- similar to `pyproject.toml` in Python or `package.json` in Node.js. It defines project metadata (name, version, entry point), manages dependencies (both PyPI and npm packages), sets defaults for CLI commands (test verbosity, server port, lint rules), configures built-in capabilities (LLM models, deployment targets), and supports environment-specific profiles (development vs. production).

You typically don't need to edit `jac.toml` manually for basic projects. The `jac create` command generates one with sensible defaults, and commands like `jac install <pkg>` and `jac config set` modify it for you. But understanding the full configuration surface is valuable when you need to customize build behavior, configure LLM providers, set up lint rules, or manage deployment settings.

`jac` commands locate `jac.toml` by walking up from the current working directory. The only exception is `jac install -e <path>`, which reads `jac.toml` from the resolved `<path>` so editable installs work from anywhere.

## Creating a Project

```bash
# Basic project
jac create myapp
cd myapp

# Full-stack web app (recommended for web development)
jac create myapp --kind web-static
cd myapp
```

This creates a `jac.toml` with default settings. When using `--kind web-static`, the scaffolded project includes:

```
myapp/
├── main.jac                  # Entry point with the client app
├── jac.toml                  # Project configuration (auto-generated)
├── components/
│   └── Button.jac         # Example client component
├── assets/                   # Static assets
├── README.md
├── AGENTS.md                 # Points AI coding agents at `jac guide`
└── .gitignore
```

The auto-generated `jac.toml` for a `--kind web-static` project looks like:

```toml
[project]
name = "myapp"
version = "1.0.0"
description = "Jac client application: myapp"
entry-point = "main.jac"
kind = "web-static"

[dependencies.npm]
jac-client-node = "1.0.7"

[client]
```

You typically don't need to modify this file until you add dependencies or customize settings.

A project can also hold several **apps** -- a web app, a mobile app, a CLI and a couple of services over one shared `core/` -- each declared as an `[apps.<name>]` table. That is a *workspace*; see [`[apps]`](#apps) below and the full [Workspaces & Apps](../apps.md) reference. `jac create --app <name> --kind <kind>` adds an app to an existing project.

---

## Configuration Sections

### [project]

Project metadata. `entry-point` and `kind` describe the project's single app (in a workspace they move onto the `[apps.<name>]` tables and `default-app` picks the app a bare `jac run` targets). `jac-version` pins the Jac toolchain the project targets: `jac create` stamps it automatically, and `jac scale deploy` uses it to select the pod runtime (see [jac-version](#jac-version) below). Publishing fields (`license`, `readme`, `keywords`, `requires-python`, `authors`, `maintainers`, and `[project.include]`) are used by `jac build --as wheel` when building a distributable wheel. All publishing fields are optional -- a project that is never published only needs `name`.

```toml
[project]
name = "myapp"
version = "1.0.0"
description = "My Jac application"
entry-point = "main.jac"
kind = "service"   # drives `jac run` (omit to infer from the entry-point); not allowed alongside [apps]
jac-version = "==0.34.3"   # stamped by `jac create`; widen to `>=`, `<=`, or a range
# default-app = "web"      # workspaces only: the app a bare `jac run` / `jac build` / `jac test` targets

# Publishing metadata -- only needed to run `jac build --as wheel`
license = "MIT"
readme = "README.md"
requires-python = ">=3.14"
keywords = ["jac", "ai"]
authors = [{ name = "Your Name", email = "you@example.com" }]
maintainers = [{ name = "Another Person", email = "them@example.com" }]

[project.urls]
homepage = "https://example.com"
repository = "https://github.com/user/repo"
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Project / PyPI package name (required) |
| `version` | string | Semantic version (default: `0.1.0`) |
| `description` | string | One-line summary (also shown on PyPI) |
| `entry-point` | string | Main file for `jac run` (default: `main.jac`). Single-app projects only -- in a workspace each app declares its own under `[apps.<name>]`, and setting it here is a hard error |
| `kind` | string | Project kind that drives `jac run` dispatch (execute / serve / build). Empty = inferred from the entry-point codespace. One of: `cli`, `cli-native`, `native-binary`, `native-lib`, `service`, `service-mesh`, `py-package`, `js-package`, `web-app`, `web-static`, `desktop`, `mobile`. Single-app projects only; a workspace sets `kind` per app |
| `default-app` | string | Workspaces only. The app that a bare `jac run`, `jac build`, `jac test` or `jac setup` targets. Must name a key of `[apps]`. With one app it is implied; with several and no default, the bare form errors and lists the apps |
| `jac-version` | string | Jac toolchain version the project targets, as a PEP 440-style specifier. `jac create` stamps `==<current>`; at `jac scale deploy` the pod runtime binary, admin console, and base image are all taken from the release that satisfies it, and the deploy aborts if none does. See [jac-version](#jac-version). |
| `license` | string | SPDX license identifier (e.g. `"MIT"`) |
| `readme` | string | Path to README file (default: `README.md`) |
| `requires-python` | string | Minimum Python version (e.g. `">=3.14"`) -- the wheel carries bytecode precompiled for the CPython the `jac` binary bundles, so a lower floor than that cannot load it |
| `keywords` | list | Search keywords shown on PyPI |
| `authors` | list of `{name, email}` | Package authors |
| `maintainers` | list of `{name, email}` | Package maintainers |
| `urls` | table | Links shown on PyPI (declared under `[project.urls]`) |

> **Note:** `authors` and `maintainers` also accept a plain string form (`authors = ["Your Name"]`), but the `{ name, email }` table form is recommended -- it is what published packages' `jac.toml` files use and what PyPI renders. See [`[project.include]`](#projectinclude) for controlling which files land in the wheel.

#### jac-version

`jac-version` records which Jac toolchain the project targets, written as a PEP 440-style specifier. Since the `jac` toolchain does not guarantee backward compatibility across versions (breaking changes ship as clean breaks), `jac create` stamps the **exact** version you created the project with:

```toml
jac-version = "==0.34.3"
```

You can widen or move it by editing the value -- `>=0.34.3`, `<=0.34.3`, `>=0.34,<0.35`, `~=0.34.3`, or a bare `0.34.3` (same as `==`).

At deploy time (`jac scale deploy`), the pin selects the **pod runtime**: the deployer downloads the released `jac` binary, admin console, and base image from the release that satisfies `jac-version` and ships them to the pods, so the app runs on the toolchain it was built against -- not on whatever `latest` happens to be. Resolution rules:

- **Unset** -> the latest published release.
- **Exact pin** (`==X` / `X`) -> the `vX` release.
- **Range** -> the newest published release that satisfies it.
- **No published release satisfies the pin** (or the matching release lacks the pod's CPU arch or a `jac-*` asset) -> the deploy **aborts** with an error naming the pin; a pinned deploy never silently ships a different version. Fix or remove `jac-version` to proceed.

The pin is honored only on the default (stable) channel; the `[dev]`, `[experimental]`, and `JAC_SCALE_BINARY_PATH` (local) channels select the pod binary by their own rules and ignore it.

---

### [apps]

One table per app turns the project into a **workspace**. Each app has a kind, an optional directory root, and an optional entry file; modules under no app root are shared code. The full model -- membership, ownership, the app dependency graph, per-app effective config, routes, and the consistency rules across apps -- is in [Workspaces & Apps](../apps.md).

```toml
[project]
name = "acme"
default-app = "web"

[apps.web]
kind = "web-app"                 # required: any project kind
path = "web"                     # dir root, relative to the project root
entry-point = "main.jac"         # relative to path; default = the kind's entry
platform = ""                    # default platform (mobile: android | ios | web; desktop: windows | macos | linux)
route = "/api/web"               # default "/api/<name>"; serving kinds only

[apps.social_graph]              # file-rooted: no path, the entry file is the whole app
kind = "service"
entry-point = "core/social_graph.jac"
```

| Field | Type | Description |
|-------|------|-------------|
| `kind` | string | **Required.** The app's project kind (same values as `[project] kind`). The kind decides the client too: `web-app`, `web-static`, `desktop` and `js-package` render React DOM; `mobile` renders native views through `@jac/mobui` (its modules are under the `E1105` host-tag guard) |
| `path` | string | Directory root of the app, relative to the project root; omit for a file-rooted app |
| `entry-point` | string | Entry file, relative to `path` (or to the project root without one); default = the kind's entry |
| `platform` | string | Default platform: `android`, `ios` or `web` for a `mobile` app; `windows`, `macos` or `linux` for a `desktop` app. `--platform` overrides it for one command |
| `route` | string | Public route prefix for apps with a server; must start with `/`; default `/api/<name>`. Two serving apps claiming one prefix is a config error |

`[project] kind` and `[project] entry-point` cannot be set alongside `[apps]` (hard error). Without `[apps]` the project is one implicit app named after `[project] name`, and nothing else changes.

**Per-app overlays.** Any recognized section can be nested under an app and is deep-merged over the base table for that app only:

```toml
[apps.web.serve]
port = 3000

[apps.mobile.dependencies.npm]
lucide-react-native = "^0.4"

[apps.social_graph.scale]        # per-app scale settings: replicas, resources, http_activation, ...
http_activation = true

[apps.web.placement.pins]        # merged over the base [placement.pins]
"core.docs.*" = "server"
```

The effective config an app sees is: base `jac.toml` → its `[apps.<name>.*]` overlays → the active profile (`jac.<profile>.toml` and/or `[environments.<profile>]`) → `jac.local.toml`. `${VAR}` interpolation applies uniformly to every string in every layer.

---

### [dependencies]

Python/PyPI packages:

```toml
[dependencies]
requests = ">=2.28.0"
numpy = "1.24.0"
byllm = ">=0.4.8"

[dev-dependencies]
pytest = ">=8.0.0"

[dependencies.git]
my-lib = { git = "https://github.com/user/repo.git", branch = "main" }

[dependencies.system]
git = "*"
ffmpeg = "*"
```

`[dependencies.system]` declares OS (apt) packages your app needs at runtime. On a `jac-scale` Kubernetes deploy they are installed into the service container at startup (Debian only; keys are apt package names). See [System Dependencies](../plugins/jac-scale-kubernetes.md#system-dependencies).

**Version specifiers:**

| Format | Example | Meaning |
|--------|---------|---------|
| Exact | `"1.0.0"` | Exactly 1.0.0 |
| Minimum | `">=1.0.0"` | 1.0.0 or higher |
| Range | `">=1.0,<2.0"` | 1.x only |
| Compatible | `"~=1.4.2"` | 1.4.x |

> **Default behavior:** When you run `jac install requests` without a version, the package is installed unconstrained and then the actual installed version is queried. A compatible-release spec (`~=X.Y`) is recorded -- e.g., if pip installs `2.32.5`, `jac.toml` gets `requests = "~=2.32"`. The `jac update` command also uses this format when writing updated versions back.

---

### [optional-dependencies]

Optional dependency groups that users can install on demand with `jac install --extras <group>`. Useful for heavy or situational dependencies (monitoring, test infrastructure, database drivers) that most users don't need.

```toml
[optional-dependencies.data]
pandas = ">=2.0,<3.0"
pyarrow = ">=17.0,<19.0"

[optional-dependencies.monitoring]
prometheus-client = ">=0.21.0,<1.0.0"

[optional-dependencies.all]
"mypkg[data,monitoring]" = "*"
```

Install a group at the command line:

```bash
jac install --extras data monitoring
jac install -e . --extras all    # editable install + extras
```

Version specifiers follow the same rules as `[dependencies]`. Use `"*"` or `"latest"` to express no constraint (the package is installed without a version pin).

**Group composition:**

An entry whose name matches `<project-name>[group,...]` is not installed as a package - it expands the listed groups transitively. In the example above, `"mypkg[data,monitoring]" = "*"` under `[optional-dependencies.all]` means `--extras all` pulls in everything from both `data` and `monitoring`.

Third-party extras syntax (e.g. `"moto[s3]"`) passes through to pip unchanged.

---

### [run]

Defaults for `jac run`:

```toml
[run]
session = ""            # Session name for persistence
main = true             # Run as main module
cache = true            # Use bytecode cache
diagnostics = "error"   # Diagnostic verbosity: "error", "all", or "none"
```

The `diagnostics` setting controls how compilation errors and warnings are reported during `jac run`:

| Value | Behavior |
|-------|----------|
| `"error"` | Show errors with full details, suppress warnings, exit code 1 on errors |
| `"all"` | Show both errors and warnings, exit code 1 on errors |
| `"none"` | Suppress all diagnostics, always exit code 0 |

The CLI flag `-e` / `--diagnostics` overrides this setting.

---

### [serve]

Everything the server process reads, for a laptop and a pod alike. Every key
has a `JAC_SERVE_*` environment mirror (listed with each table), and the
deploy target sets those same variables on the pod, so one resolver answers
both.

```toml
[serve]
host = "0.0.0.0"         # Interface to bind; 127.0.0.1 keeps a dev server off the network
port = 8000              # Server port
session = ""             # Session name
main = true              # Run as main module
docs_enabled = true      # /docs and /openapi.json
graph_enabled = true     # /graph and /graph/data (turn off in production)
cors_origins = ["*"]     # Origins allowed by the CORS middleware

# Optimistic-concurrency policy for concurrent check-then-create races
# (see Persistence -> Concurrent writes).
on_conflict = "retry"        # "retry": abort + replay so the loser converges
                             # "fail":  no replay, return HTTP 409 immediately
conflict_max_attempts = 5    # max walker/function attempts under "retry"
conflict_backoff_ms = 0      # linear backoff between replay attempts (0 = none)

[serve.workers]
count = "1"              # Worker processes; "auto" = the CPU quota. JAC_SERVE_WORKERS
threads = "auto"         # Sync-handler threads per worker; "auto" sizes from the quota. JAC_SERVE_THREADS
max_requests = 0         # Recycle a worker after this many requests (0 = never). JAC_SERVE_MAX_REQUESTS
max_requests_jitter = 0  # Random extra requests so workers do not recycle together
request_timeout = 0.0    # Seconds before a request is answered 504 (0 = no limit). JAC_SERVE_REQUEST_TIMEOUT
boot_timeout = 120.0     # Seconds a worker may take to start accepting before it is replaced
hang_timeout = 30.0      # Seconds without a worker heartbeat before it is killed and replaced

[serve.tls]
certfile = ""            # PEM certificate chain; set to serve HTTPS directly. JAC_SERVE_TLS_CERTFILE
keyfile = ""             # PEM private key. JAC_SERVE_TLS_KEYFILE
ca_certs = ""            # Optional CA bundle for client certificates
min_version = "1.2"      # "1.2" or "1.3"

[serve.proxy]
trusted = []             # Proxies (IPs or CIDRs) whose X-Forwarded-* / Forwarded headers are believed. JAC_SERVE_PROXY_TRUSTED

[serve.limits]
max_connections = 0      # Concurrent connections per worker before new ones get 503 (0 = unlimited)
backlog = 2048           # Listen backlog
max_body_bytes = 104857600
max_header_bytes = 65536
max_header_count = 100
max_request_line_bytes = 8192
multipart_spool_bytes = 1048576   # Multipart bodies above this spool to disk

[serve.timeouts]
header = 30.0            # Seconds to receive the request line and headers
body = 60.0              # Seconds per body read
keepalive = 65.0         # Idle seconds before a keep-alive connection is closed
drain = 10.0             # Seconds in-flight requests get after SIGTERM. JAC_SERVE_DRAIN_TIMEOUT
close = 5.0

[serve.access_log]
enabled = true           # JAC_SERVE_ACCESS_LOG
format = "text"          # "text" or "json". JAC_SERVE_ACCESS_LOG_FORMAT
suppress_health_checks = false

[serve.compression]
enabled = true           # gzip negotiable responses (JSON, text, JS, SVG, wasm)
min_bytes = 1024
level = 4

[serve.websocket]
allowed_origins = []     # Cross-origin upgrades to allow; [] = same-origin only. JAC_SERVE_WS_ALLOWED_ORIGINS
max_message_bytes = 0    # 0 = the 64 MiB frame cap
ping_interval = 20.0     # Idle seconds before the server pings
ping_timeout = 20.0      # Seconds to answer the ping before the socket is closed

[serve.auth]
secret = ""              # JWT signing secret. JAC_SERVE_AUTH_SECRET. Required in a cluster; a laptop mints one per project
algorithm = "HS256"
token_ttl_days = 7
password_hash_cost = 14  # log2 of the scrypt work factor, 10..17
```

The served app's client is at `/`. Other client-capable apps in the workspace whose bundle exists (`jac build --all` writes `dist/<app>/`) are served at `/cl/<app-name>/` -- a fixed prefix with no config key. Serving apps answer under their `route` (default `/api/<name>`, see [`[apps]`](#apps)).

Identity is one implementation: users, credentials and sessions live in the
project's Postgres store (the embedded server on a laptop, `JAC_DB_URL` or
`[scale.database] url` elsewhere) and every session token is an HS256 JWT
signed with `[serve.auth] secret`. With no secret configured a laptop keeps
one per project under `.jac/data/jwt_secret`; a cluster refuses to start
without one, and `jac scale deploy` mints one into the app Secret.

`workers` is the throughput and isolation knob. One worker is one Python
process and therefore one core of CPU-bound work; `count = "auto"` starts one
per core of the container's quota. Even on one core, more than one worker
keeps a slow request from stalling every other request. Anything that only
works in one process is refused when `count > 1`: `--dev` hot reload, a
memory WebSocket backplane, or events without a database.

`on_conflict` controls what happens when two concurrent requests race a "look it up, create it if missing" against the same node and the loser's commit is rejected. `retry` (default) re-runs the request against the now-current graph so it converges on the winner's node; `fail` surfaces a typed `409 write_conflict` for the client to handle. See [Persistence -> Concurrent writes: check-then-create](../persistence.md#concurrent-writes-check-then-create-and-convergence) for the full model.

---

### [build]

Build configuration:

```toml
[build]
dir = ".jac"                # Build artifacts directory
default_codespace = "native"  # Codespace for markerless .jac modules: "native"/"na" or "server"/"sv"
```

`default_codespace` controls how a plain `.jac` module (not a `.jac` implementation variant) is treated when whole-module native compilation is possible. With `"native"` (the default) the compiler infers: a module with no server-requiring constructs, and whose imported plain `.jac` modules are likewise native-clean, is compiled whole-module in the native codespace and executed through the native engine. Modules with server-requiring constructs (OSP archetypes, python imports, serve endpoints, test blocks, JSX, and similar) compile in the server codespace exactly as before, and an inferred-native module that does not lower yet is transparently recompiled server-side with a dim `note:` -- the preference is always safe. Set `"server"` to opt a project out of native inference entirely; `[placement.pins]` entries mapping to `"native"` and forced builds (`jac nacompile`, `jac build --as native`, `CompileOptions(force_codespace='native')`) remain strict mandates.

The `dir` setting controls where all build artifacts are stored:

- `.jac/cache/` - Bytecode cache
- `.jac/venv/` - Project virtual environment
- `.jac/client/` - Client-side builds
- `.jac/data/` - Runtime data

---

### [placement.pins]

Placement overrides. Element placement (server / client / native) is inferred
by the compiler from evidence in the source (see
[Placement](../placement.md)); this table is the escape hatch when a decision
must be forced. Keys are
[fnmatch](https://docs.python.org/3/library/fnmatch.html) patterns matched
against an element's dotted path -- `module` or `module.element`, relative to
the project root -- and values are `"server"`, `"client"`, or `"native"`
(any other value is a hard error at load time):

```toml
[placement.pins]
"app.API_KEY"   = "server"    # one element: keep a secret out of the JS bundle
"app.summarize" = "server"    # client calls to it bridge over RPC instead
"kernels.*"     = "server"    # every element of the kernels module
helpers         = "client"    # module-level pin: the whole module
```

A pinned element is immovable to the placement solver; everything else
re-solves around it. Module-level `"server"` pins additionally give client
imports of that module full service-boundary semantics (non-`:pub` items
callable with auth, boundary types collected). Pins are part of the program:
changing them invalidates the compilation cache, and
`jac check --placements` reports them in each element's evidence chain.

Pins can also be overlaid per app -- `[apps.<name>.placement.pins]` merges
over this table for that app's modules -- and a pin is one way to name the
**owner** of a server-placed shared module when several apps serve
(`E5107`). Declaring that a module runs as its own **service** is a different
fact with a different home: an `[apps.<name>]` table with `kind = "service"`
(see [Workspaces & Apps](../apps.md)); imports of what that app owns lower to
typed-async bridge stubs automatically.

---

### [gc]

Memory-management defaults for **native** compilation (`jac nacompile`):

```toml
[gc]
default = "cycles"    # gc mode emitted when --gc is not passed: "cycles", "rc", or "none"

[gc.enforce]
modules = []          # module-name patterns compiled under zero-RC nogc enforcement
grandfathered = []    # patterns exempted from enforcement (checked before `modules`)
```

`default` selects the memory-management runtime the native backend emits when `jac nacompile` is invoked without an explicit `--gc`: `cycles` (reference counting plus the cycle collector), `rc` (reference counting only), or `none` (no retain/release call sites).

`[gc.enforce] modules` lists `fnmatch`-style patterns matched against compiled module names; a native module matching one is compiled under **nogc enforcement**, which makes zero-RC ownership coverage a compile-time contract -- every heap-typed parameter, return type, and `has` field must be in the owned world, and violations are hard [`E1401`-`E1406`](../diagnostics.md#zero-rc-enforcement-errors) errors that block codegen. `grandfathered` patterns exempt matching modules, so a codebase can adopt enforcement incrementally. The `jac nacompile --enforce-nogc` flag enforces the compiled module regardless of these patterns. See [Zero-RC ownership compilation](../language/native-pathway.md#zero-rc-ownership-compilation).

---

### [test]

Defaults for `jac test`:

```toml
[test]
directory = ""          # Scopes no-argument `jac test` discovery (empty = walk project root)
directories = []        # Several discovery roots; takes precedence over `directory`
isolate = []            # Glob patterns of test files that each get a dedicated worker process
serial = []             # Glob patterns of test files that run one at a time after the parallel phase
filter = ""             # Filter pattern
verbose = false         # Verbose output
fail_fast = false       # Stop on first failure
max_failures = 0        # Max failures (0 = unlimited)
```

When `directory` (or the list form `directories`) is set, `jac test` with no
file argument collects tests only from those directories (resolved against the
project root), so application modules whose top-level `with entry` runs on
import are not pulled into test collection. Every path in `directories` must
exist. `isolate` names test files that must not share a worker process with
any other file (servers, sockets, module-level config); `serial` names files
that additionally run one after another once the parallel phase is done, for
suites that share one on-disk resource. Both take glob patterns relative to the
project root.

---

### [format]

Defaults for `jac fmt`:

```toml
[format]
outfile = ""        # Output file (empty = in-place)
```

---

### [check]

Defaults for `jac check`:

```toml
[check]
print_errs = true   # Print errors to console
untyped-external = "warn"   # "error" escalates undeclared npm/PyPI imports to E1120
```

`untyped-external` controls how `jac check` reports imports from external modules that ship no type information (no `.d.ts` for client npm packages, no `py.typed`/`.pyi` on the Python side). The default warns once per import with **`W1102`** and types the binding as foreign `any`. Set `untyped-external = "error"` to require declarations and emit **`E1120`** instead. See [npm import type checking](../plugins/jac-client.md#npm-import-type-checking-jac-check) in the jac-client reference.

#### [check.lint]

Configure which auto-lint rules are active during `jac check --lint` and `jac check --lint --fix`. Rules use a select/ignore model with two group keywords:

- `"default"` - code-transforming rules only (safe, auto-fixable)
- `"all"` - every rule, including unfixable rules like `no-print`

```toml
[check.lint]
select = ["default"]          # Code-transforming rules only (default)
ignore = ["combine-has"]      # Disable specific rules
exclude = []                  # File patterns to skip (glob syntax)
```

To enable all rules including warning-only rules:

```toml
[check.lint]
select = ["all"]              # Everything, including no-print
```

To add specific rules on top of defaults:

```toml
[check.lint]
select = ["default", "no-print"]  # Defaults + no-print warnings
```

To enable only specific rules:

```toml
[check.lint]
select = ["combine-has", "remove-empty-parens"]
```

**Available lint rules:**

| Rule Name | Code | Description | Group |
|-----------|------|-------------|-------|
| `staticmethod-to-static` | `W3001` | Convert `@staticmethod` decorator to `static` keyword | default |
| `combine-has` | `W3002` | Combine consecutive `has` statements with same modifiers | default |
| `combine-glob` | `W3003` | Combine consecutive `glob` statements with same modifiers | default |
| `init-to-can` | `W3004` | Convert `def __init__` / `def __post_init__` to `can init` / `can postinit` | default |
| `remove-empty-parens` | `W3005` | Remove empty parentheses from declarations (`def foo()` → `def foo`) | default |
| `hasattr-to-null-ok` | `W3007` | Convert `hasattr(obj, "attr")` to null-safe access (`obj?.attr`) | default |
| `simplify-ternary` | `W3008` | Simplify `x if x else default` to `x or default` | default |
| `remove-future-annotations` | `W3009` | Remove `import from __future__ { annotations }` (not needed in Jac) | default |
| `fix-impl-signature` | `W3010` | Fix signature mismatches between declarations and implementations | default |
| `no-print` | `E3012` | Error on bare `print()` calls (use console abstraction instead) | all |
| `remove-redundant-semi` | `W3013` | Remove standalone no-op semicolons from any body (`{;}` → `{}`, `x = 1;;` → `x = 1;`); `remove-import-semi` is an accepted alias for this rule | default |
| `strip-comments` | `W3050` | Remove **all** comments | opt-in |
| `strip-docstrings` | `W3051` | Remove **all** docstrings | opt-in |

Diagnostic codes can be suppressed inline with `# jac:ignore[CODE]` comments. See the full [Errors & Warnings](../diagnostics.md) reference for all diagnostic codes.

**Opt-in (deslop) rules:**

`strip-comments` and `strip-docstrings` are destructive "deslop" rules: they delete content rather than restructure it. Unlike every other rule, they are **never** activated by `select = ["all"]` or `select = ["default"]`; they fire only when named explicitly. A project that wants them on by default lists them alongside its other selections:

```toml
[check.lint]
select = ["default", "strip-comments", "strip-docstrings"]
```

The two are independent, so you can strip comments while keeping docstrings (or vice versa). With a rule selected, `jac fmt --lintfix` removes the content and `jac check` reports it. They are also the rules driving [`jac precommit`](../cli/index.md#jac-precommit) when configured.

**Excluding files from lint:**

Use `exclude` to skip files matching glob patterns:

```toml
[check.lint]
select = ["all"]
exclude = [
    "docs/*",
    "*/examples/*",
    "*/tests/*",
    "legacy_module.jac",
]
```

Patterns are matched against file paths relative to the project root. Use `*` for single-directory wildcards and `**` for recursive matching.

---

### [dot]

Defaults for `jac dot` (graph visualization):

```toml
[dot]
depth = -1          # Traversal depth (-1 = unlimited)
traverse = false    # Traverse connections
bfs = false         # Use BFS (default: DFS)
edge_limit = 512    # Maximum edges
node_limit = 512    # Maximum nodes
format = "dot"      # Output format
```

---

### [cache]

Bytecode cache settings:

```toml
[cache]
enabled = true   # Enable caching
dir = "cache"    # Cache subdirectory under the build dir (i.e. .jac/cache).
                 # An absolute path relocates the cache wholesale.
```

The format cache (`jac fmt --cache` / `jac precommit`) also lives here, under
`<cache dir>/fmt-v1/`. It stores one marker per file proven clean, keyed on the
file's content digest, the `lintfix` mode, the effective `[format]` and
`[check]` settings (including `suppress` / `suppress_categories` / nested
`lint`), the logical path when `lintfix` is on, and a formatter-pipeline
fingerprint -- so a content, config, path, or pipeline change automatically
invalidates the relevant entries. Entries are written only for fully
successful, unchanged (or just-rewritten) results; syntax errors, lint
failures, and annex failures are never cached as clean. `--cache` / precommit
enable this format cache explicitly and do **not** consult `[cache].enabled`
(that flag gates the bytecode cache). The directory is git-ignored, so it is
safe to delete at any time. See [`jac fmt --cache`](../cli/index.md#jac-fmt).

---

### [storage]

!!! note "Scale Configuration"
    The `[storage]` section is provided by the built-in **scale** subsystem (part of `jaclang` core). Its cloud backends (S3/GCS/Azure) require the relevant client libraries in the project venv -- declare the backend in config and run `jac install` to pull them in.

File storage configuration:

```toml
[storage]
storage_type = "local"       # Storage backend (local)
base_path = "./storage"      # Base directory for files
create_dirs = true           # Auto-create directories
```

| Field | Description | Default |
|-------|-------------|---------|
| `storage_type` | Storage backend type | `"local"` |
| `base_path` | Base directory for file storage | `"./storage"` |
| `create_dirs` | Automatically create directories | `true` |

**Environment Variable Overrides:**

| Variable | Description |
|----------|-------------|
| `JAC_STORAGE_TYPE` | Storage type (overrides config) |
| `JAC_STORAGE_PATH` | Base directory (overrides config) |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create directories (`"true"`/`"false"`) |

Configuration priority: `jac.toml` > environment variables > defaults.

See [Storage Reference](../plugins/jac-scale-persistence.md#storage) for the full storage API.

---

### Capability settings

Built-in capabilities (byLLM, scale, the client framework) are configured in top-level tables named after the capability:

```toml
# byLLM settings (model identity split from call params)
[byllm.model]
default_model = "gpt-4o"
api_key = "${OPENAI_API_KEY}"

[byllm.call_params]
temperature = 0.7

# Serving-process logging (scale); the listener itself is [serve]
[scale.server]
structured_logs = true

# Webhook settings (scale)
[scale.webhook]
secret = "your-webhook-secret-key"
signature_header = "X-Webhook-Signature"
verify_signature = true
api_key_expiry_days = 365
```

**Gateway and fleet topology (scale):**

```toml
[scale.gateway]
colocate = true                  # false: `jac run <app>` runs service apps as separate local processes
gateway_port = 8000
gateway_host = "0.0.0.0"
http_forward_timeout = 10.0
boot_health_timeout = 60.0
boot_max_wait = 90
health_monitor_interval = 10.0

[scale.gateway.cors]
allow_origins = ["*"]

[scale.gateway.rate_limit]
enabled = false
```

`[scale.gateway]` holds everything about the process that fronts a workspace's service apps: ports, boot timeouts, `cors`, `rate_limit`, `identity`, `ingress`, `logs`, `tracing`, `shared_volumes`, and `colocate`. The drain window on SIGTERM is `[serve.timeouts] drain`, shared by the gateway and every app. Per-app `workers` and `threads` in `[apps.<name>.scale]` size that app's pods. Which apps form the fleet is not configured here -- it is every app whose kind has a server -- and per-app settings (`replicas`, resources, `rpc_timeout`, `http_activation`, `env`, ...) live in the app's own `[apps.<name>.scale]` overlay. `jac run <app> --fleet` overrides `colocate` for one run; `jac scale deploy` always deploys a fleet. See [Service apps](../plugins/jac-scale-http.md#service-apps-cross-app-bridging).

**Prometheus Metrics (scale):**

```toml
[scale.monitoring]
enabled = true
endpoint = "/metrics"
namespace = "myapp"
walker_metrics = true
```

See [Prometheus Metrics](../plugins/jac-scale-kubernetes.md#prometheus-metrics) for details.

**Kubernetes Secrets (scale):**

```toml
[scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
DATABASE_PASSWORD = "${DB_PASS}"
```

See [Kubernetes Secrets](../plugins/jac-scale-kubernetes.md#kubernetes-secrets) for details.

See also [Scale Webhooks](../plugins/jac-scale-http.md#webhooks) and [Kubernetes Deployment](../plugins/jac-scale-kubernetes.md#kubernetes-deployment) for more options.

**Built-in Local Models (byllm):**

```toml
[byllm.model]
default_model = "local:gemma-4-e4b"   # in-process llama.cpp; no API key, no daemon

[byllm.local]
default_alias  = "gemma-4-e4b"        # used when default_model is unset
n_gpu_layers   = -1                   # -1 = offload all layers to GPU; 0 = CPU only
n_ctx          = 0                    # 0 = use the alias's bundled default
auto_download  = false                # true = skip the first-run TTY prompt
```

Bundled aliases are downloaded as Q4_K_M GGUFs into `~/.cache/jac/models/<alias>/` on first use and managed via `jac model list/pull/rm`. See [Built-in Local Models](../plugins/byllm.md#built-in-local-models) for the full reference and [`jac model`](../cli/index.md#jac-model) for cache management.

**Frontend Framework (jac-client):**

```toml
[client]
framework = "react"   # "react" (default), "solid" (experimental), or "preact"
```

Controls which JavaScript framework the `cl` compiler target emits. The default is `"react"`.

| Value | Status | Notes |
|-------|--------|-------|
| `"react"` | Stable | Default. Uses React hooks and `@vitejs/plugin-react`. |
| `"solid"` | Experimental | Uses Solid signals and `vite-plugin-solid`. API may change. |
| `"preact"` | Stable | Drop-in React alternative with a smaller bundle. |

Switching frameworks automatically adjusts the installed npm packages and the generated Vite config; no other changes are needed. Delete your `.jac/client/` build cache after switching so the previous framework's output is not mixed in.

!!! warning "Solid support is experimental"
    The `solid` framework target is under active development. Some jac-client features (error boundaries, suspense slots, advanced routing) may not yet be fully supported. Check the [release notes](../../community/release_notes/jaclang.md) before upgrading.

**Import Path Aliases (jac-client):**

```toml
[client.paths]
"@components/*" = "./components/*"
"@utils/*" = "./utils/*"
"@shared" = "./shared/index"
```

Defines custom import aliases applied to Vite `resolve.alias`, TypeScript `compilerOptions.paths`, and the Jac module resolver. See [jac-client Import Path Aliases](../plugins/jac-client.md#import-path-aliases) for details.

**Asset Directory (jac-client):**

```toml
[client.assets]
dir = "core/site/assets"        # default: the app's own assets/
custom_extensions = [".pdf"]    # extra file types to copy into the bundle
```

Files in the assets directory are served at `/static/assets/<path>` and compiled into the client bundle. In a workspace each app defaults to its own `assets/`; apps that share one UI point `dir` at the shared directory, relative to the project root. Like every client section it overlays per app under `[apps.<name>.client.assets]`.

**NPM Registry Configuration (jac-client):**

```toml
[client.npm.scoped_registries]
"@mycompany" = "https://npm.pkg.github.com"

[client.npm.auth."//npm.pkg.github.com/"]
_authToken = "${NODE_AUTH_TOKEN}"
```

This generates an `.npmrc` file during dependency installation for private/scoped npm packages. See [jac-client NPM Registry Configuration](../plugins/jac-client.md#npm-registry-configuration) for details.

**Build-Time Constants (jac-client):**

Define global variables that are replaced at compile time in client code via the `[client.vite.define]` section:

```toml
[client.vite.define]
"globalThis.API_URL" = "\"https://api.example.com\""
"globalThis.FEATURE_ENABLED" = true
"globalThis.BUILD_VERSION" = "\"1.2.3\""
```

These values are inlined by Vite during bundling. String values must be double-quoted (JSON-encoded). In client code, access them directly:

```jac
def:pub Footer() -> JsxElement {
    <p>Version: {globalThis.BUILD_VERSION}</p>
}
```

---

### [scripts]

Custom command shortcuts:

```toml
[scripts]
dev = "jac run main.jac"
test = "jac test -v"
build = "jac build main.jac -t"
lint = "jac check . --lint --fix"
format = "jac fmt ."
```

Run with:

```bash
jac x dev
jac x test
```

---

### [environments]

Environment-specific overrides:

```toml
[environment]
default_profile = "development"

[environments.development]
[environments.development.run]
cache = false
[environments.development.byllm]
model = "gpt-3.5-turbo"

[environments.production]
inherits = "development"
[environments.production.run]
cache = true
[environments.production.byllm]
model = "gpt-4"
```

Activate a profile:

```bash
JAC_PROFILE=production jac run main.jac
```

---

## Environment Variable Interpolation

Use environment variable interpolation inside `jac.toml` values:

```toml
[byllm.model]
api_key = "${OPENAI_API_KEY}"                       # Required
default_model = "${MODEL:-gpt-4o-mini}"             # With default
base_url = "${BASE_URL:?Base URL is required}"      # Required with error
```

| Syntax | Description |
|--------|-------------|
| `${VAR}` | Use variable (error if not set) |
| `${VAR:-default}` | Use default if not set |
| `${VAR:?error}` | Custom error if not set |

---

### [project.include]

Controls which files and directories `jac build --as wheel` collects into the wheel.

```toml
[project.include]
# Explicit list of package directories to include.
# Defaults to a directory matching the package name (hyphens replaced with underscores).
packages = ["mylib", "mylib_utils"]

[project.include.data]
# "*" sets global file patterns for all packages.
"*" = ["**/*.jac", "**/*.py", "**/*.pyi", "py.typed"]

# Per-package overrides add extra patterns on top of globals.
mylib = ["**/*.lark", "data/*.json", "templates/**/*"]
```

| Key | Description |
|-----|-------------|
| `packages` | Glob list of package directories to ship. Defaults to one directory named after the project (hyphens → underscores). |
| `data` | Map of file-glob patterns. The `"*"` key sets global patterns for every package; a per-package key adds extra patterns on top. |

Simple patterns without a path separator (e.g. `"*.jac"`) are matched recursively, so sub-packages are covered automatically.

**Default included patterns** (when `[project.include.data]` is absent):

| Pattern | Description |
|---------|-------------|
| `**/*.jac` | Jac source files |
| `**/*.py` | Python source files |
| `**/*.pyi` | Type stub files |
| `**/*.lark` | Lark grammar files |
| `**/py.typed` | PEP 561 type marker |
| `**/*.jir` | Pre-compiled JIR bytecode (collected if already present -- see [`jac build`](../cli/index.md#jac-build)) |
| `_precompiled/manifest.json` | JIR precompile manifest |

**Always excluded** (regardless of patterns):

- Directories: `.jac/`, `__pycache__/`, `dist/`, `build/`, `venv/`, `.venv/`, `env/`, `.git/`, `.hg/`, `node_modules/`, `*.egg-info/`
- File suffixes: `.pyc`

---

### [entrypoints]

Declare console scripts and other entry-point groups. Maps directly to `entry_points.txt` in the wheel's `.dist-info`.

```toml
[entrypoints.scripts]
# Installs a "mylib" CLI command pointing to mylib.cli:main
mylib = "mylib.cli:main"
```

The `[entrypoints.scripts]` group is written as `[console_scripts]` in `entry_points.txt`, which is the standard pip convention for installing CLI commands. After a user runs `pip install mylib`, the `mylib` command is available on their `PATH`.

Any other `[entrypoints.<group>]` table is written through to the wheel metadata verbatim, for consumers that discover packages via `importlib.metadata.entry_points()`. (Jac itself no longer loads any entry-point group at startup -- the former `jac` plugin group is defunct.)

---

## CLI Override

Most settings can be overridden via CLI flags:

```bash
# Override run settings
jac run --no-cache main.jac

# Override test settings
jac test --verbose -x

# Override serve settings
jac run --port 3000
```

---

## Complete Example

```toml
[project]
name = "my-ai-app"
version = "1.0.0"
description = "An AI-powered application"
entry-point = "main.jac"

[dependencies]
byllm = ">=0.4.8"
requests = ">=2.28.0"

[dev-dependencies]
pytest = ">=8.0.0"

[run]
main = true
cache = true

[serve]
port = 8000

[test]
directory = "tests"
verbose = true

[build]
dir = ".jac"

[check.lint]
select = ["all"]
ignore = []
exclude = []

[byllm.model]
default_model = "${LLM_MODEL:-gpt-4o-mini}"
api_key = "${OPENAI_API_KEY}"

[scripts]
dev = "jac run main.jac"
test = "jac test"
lint = "jac check . --lint --fix"
```

---

## .jacignore

The `.jacignore` file controls which Jac files are excluded from compilation and analysis. Place it in the project root.

### Format

One pattern per line, similar to `.gitignore`:

```
# Comments start with #
vite_client_bundle.impl.jac
test_fixtures/
*.generated.jac
```

Each line is a filename or pattern that should be skipped during Jac compilation passes (type checking, formatting, etc.). Blank lines and `#` comments are ignored; a pattern containing `/` is matched against the path relative to the project root, a bare pattern against any path component.

A `jac scale deploy` reads the same file when it stages the app bundle, so a parked tree is not copied to the pods and is never compiled there. Because `.jacignore` itself ships in the bundle, editing it changes the bundle's content address and the next deploy re-ships.

---

## Environment Variables

### General

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable colored terminal output |
| `NO_EMOJI` | Disable emoji in terminal output |
| `JAC_PROFILE` | Activate a configuration profile (e.g., `production`) |
| `JAC_BASE_PATH` | Override base directory for data/storage |
| `JAC_DATA_PATH` | Override the base directory for application data (graph storage, user db, dev signing secret) |
| `JAC_SERVE_*` | Every `[serve]` key, one variable each: `JAC_SERVE_HOST`, `JAC_SERVE_PORT`, `JAC_SERVE_WORKERS`, `JAC_SERVE_THREADS`, `JAC_SERVE_AUTH_SECRET`, `JAC_SERVE_PROXY_TRUSTED`, `JAC_SERVE_DRAIN_TIMEOUT`, `JAC_SERVE_ACCESS_LOG_FORMAT`, ... (see [serve](#serve)) |
| `JAC_SCALE_RUNTIME` | Set to `1` by the serving path so scale features (microservices, deploy context) know they are serving |
| `JACPATH` | Colon-separated extra search path for Jac module resolution (like `PYTHONPATH`) |
| `JAC_SCHEMA_REPAIR` | Schema-drift handling on load: `repair` (default) or `strict` |
| `JAC_STRICT_PERMISSIONS` | Enable strict permission checking for security-sensitive operations (`1`/`true`) |

### Storage

| Variable | Description |
|----------|-------------|
| `JAC_STORAGE_TYPE` | Storage backend type |
| `JAC_STORAGE_PATH` | Base directory for file storage |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create directories |

### Scale: Database

| Variable | Description |
|----------|-------------|
| `JAC_DB_URL` | Postgres connection URL for **this process** (overrides `[scale.database].url` at runtime). A deploy ignores it: what database the deployed app gets is decided by `[scale.kubernetes]` `database_mode` / `database_url`, then `[scale.database]` `url`, then provisioning |
| `JAC_CACHE_HOME` | Root of the machine-wide jac cache; the shared embedded Postgres cluster lives in `<JAC_CACHE_HOME>/pg/main` (default `~/.cache/jac`) |
| `JAC_DB_RETENTION_DAYS` | Drop databases unused for this many days when the embedded cluster starts; overrides `[database] retention_days`, unset means never |
| `JAC_DB_SCRATCH` | `1` makes this process open one throwaway database that is dropped when it exits, instead of a per-project one (used by the test runner and deploy staging) |
| `FIREBASE_PROJECT_ID` | Shared Firebase project ID fallback for Auth SSO and Storage |

Project ID vars (`FIREBASE_AUTH_PROJECT_ID`, `JAC_STORAGE_FIREBASE_PROJECT_ID`, `JAC_STORAGE_GCS_PROJECT_ID`) override `FIREBASE_PROJECT_ID` when set.

### Scale: Authentication

| Variable | Description | Default |
|----------|-------------|---------|
| `JWT_SECRET` | Secret key for JWT signing | `supersecretkey` |
| `JWT_ALGORITHM` | JWT algorithm | `HS256` |
| `JWT_EXP_DELTA_DAYS` | Token expiration in days | `7` |
| `SSO_HOST` | SSO callback host URL | `http://localhost:8000/sso` |
| `SSO_GOOGLE_CLIENT_ID` | Google OAuth client ID | None |
| `SSO_GOOGLE_CLIENT_SECRET` | Google OAuth client secret | None |
| `EMAILER_SMTP_PASSWORD` | SMTP password for the built-in email sender | None |

### Scale: Service apps

| Variable | Description |
|----------|-------------|
| `JAC_APP_<APP>_URL` | Point bridged calls into app `<APP>` (an `[apps]` key, upper-cased, non-alphanumerics as `_`) at a provider running elsewhere. Set by hand for a multi-host fleet; injected automatically by `jac scale deploy` and by `--fleet` |
| `JAC_APP_<APP>_ROUTE` | The provider's route prefix when it differs from the default `/api/<app>` |

### Client

| Variable | Description |
|----------|-------------|
| `JAC_CLIENT_SKIP_NPM_INSTALL` | Skip `npm install` during client build setup |
| `JAC_MOBILE_PLATFORM` | Set by `jac run --platform <android\|ios> <mobile-app>`; overrides `[client.react_native] default_platform` for that run |

### Scale: Webhooks

| Variable | Description |
|----------|-------------|
| `WEBHOOK_SECRET` | Secret for webhook HMAC signatures |
| `WEBHOOK_SIGNATURE_HEADER` | Header name for signature |
| `WEBHOOK_VERIFY_SIGNATURE` | Enable signature verification |
| `WEBHOOK_API_KEY_EXPIRY_DAYS` | API key expiry in days |

### Scale: Kubernetes

Deployment settings (app name, namespace, node port, CPU/memory requests and limits, health probes) are configured in `jac.toml` under `[scale.kubernetes]` -- see the [Kubernetes reference](../plugins/jac-scale-kubernetes.md). At deploy time, jac-scale injects these variables into every pod:

| Variable | Description |
|----------|-------------|
| `K8S_APP_NAME` | Application name (used by observability and admin tooling inside the pod) |
| `K8S_NAMESPACE` | Namespace the workload runs in |

---

## See Also

- [CLI Reference](../cli/index.md) - Command-line interface documentation
- [Publishing Packages](../publishing.md) - Building and uploading wheels to PyPI
