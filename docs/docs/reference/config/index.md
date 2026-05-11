# Configuration Reference

The `jac.toml` file is the central configuration for Jac projects -- similar to `pyproject.toml` in Python or `package.json` in Node.js. It defines project metadata (name, version, entry point), manages dependencies (both PyPI and npm packages), sets defaults for CLI commands (test verbosity, server port, lint rules), configures plugins (LLM models, deployment targets), and supports environment-specific profiles (development vs. production).

You typically don't need to edit `jac.toml` manually for basic projects. The `jac create` command generates one with sensible defaults, and commands like `jac add` and `jac config set` modify it for you. But understanding the full configuration surface is valuable when you need to customize build behavior, configure LLM providers, set up lint rules, or manage deployment settings.

`jac` commands locate `jac.toml` by walking up from the current working directory. The only exception is `jac install -e <path>`, which reads `jac.toml` from the resolved `<path>` so editable installs work from anywhere.

## Creating a Project

```bash
# Basic project
jac create myapp
cd myapp

# Full-stack web app (recommended for web development)
jac create myapp --use client
cd myapp
```

This creates a `jac.toml` with default settings. When using `--use client`, the scaffolded project includes:

```
myapp/
├── main.jac       # Entry point with server and client code
├── jac.toml       # Project configuration (auto-generated)
└── styles.css     # Default stylesheet
```

The auto-generated `jac.toml` for a `--use client` project looks like:

```toml
[project]
name = "myapp"
version = "0.0.1"
entry-point = "main.jac"
```

You typically don't need to modify this file until you add dependencies or customize settings.

---

## Configuration Sections

### [project]

Project metadata:

```toml
[project]
name = "myapp"
version = "1.0.0"
description = "My Jac application"
authors = ["Your Name <you@example.com>"]
license = "MIT"
entry-point = "main.jac"
jac-version = ">=0.9.0"

[project.urls]
homepage = "https://example.com"
repository = "https://github.com/user/repo"
```

| Field | Description |
|-------|-------------|
| `name` | Project name (required) |
| `version` | Semantic version |
| `description` | Brief description |
| `authors` | List of authors |
| `license` | License identifier |
| `entry-point` | Main file (default: `main.jac`) |
| `jac-version` | Required Jac version |

---

### [dependencies]

Python/PyPI packages and Jac plugins:

```toml
[dependencies]
requests = ">=2.28.0"
numpy = "1.24.0"
byllm = ">=0.4.8"

[dev-dependencies]
pytest = ">=8.0.0"

[dependencies.git]
my-lib = { git = "https://github.com/user/repo.git", branch = "main" }
```

**Version specifiers:**

| Format | Example | Meaning |
|--------|---------|---------|
| Exact | `"1.0.0"` | Exactly 1.0.0 |
| Minimum | `">=1.0.0"` | 1.0.0 or higher |
| Range | `">=1.0,<2.0"` | 1.x only |
| Compatible | `"~=1.4.2"` | 1.4.x |

> **Default behavior:** When you run `jac add requests` without a version, the package is installed unconstrained and then the actual installed version is queried. A compatible-release spec (`~=X.Y`) is recorded -- e.g., if pip installs `2.32.5`, `jac.toml` gets `requests = "~=2.32"`. The `jac update` command also uses this format when writing updated versions back.

---

### [optional-dependencies]

Optional dependency groups that users can install on demand with `jac install --extras <group>`. Useful for heavy or situational dependencies (monitoring, test infrastructure, database drivers) that most users don't need.

```toml
[optional-dependencies.data]
pymongo = ">=4.0,<5.0"
redis = ">=7.0,<8.0"

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

Third-party extras syntax (e.g. `"testcontainers[mongodb,redis]"`) passes through to pip unchanged.

---

### [run]

Defaults for `jac run`:

```toml
[run]
session = ""            # Session name for persistence
main = true             # Run as main module
cache = true            # Use bytecode cache
topology_index = true   # Build topology index for graph query optimization
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

Defaults for `jac start`:

```toml
[serve]
port = 8000              # Server port
session = ""             # Session name
main = true              # Run as main module
cl_route_prefix = "cl"   # URL prefix for client apps
base_route_app = ""      # Client app to serve at /
```

---

### [build]

Build configuration:

```toml
[build]
typecheck = false   # Enable type checking
dir = ".jac"        # Build artifacts directory
```

The `dir` setting controls where all build artifacts are stored:

- `.jac/cache/` - Bytecode cache
- `.jac/venv/` - Project virtual environment
- `.jac/client/` - Client-side builds
- `.jac/data/` - Runtime data

---

### [test]

Defaults for `jac test`:

```toml
[test]
directory = ""          # Test directory (empty = current directory)
filter = ""             # Filter pattern
verbose = false         # Verbose output
fail_fast = false       # Stop on first failure
max_failures = 0        # Max failures (0 = unlimited)
```

---

### [format]

Defaults for `jac format`:

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
```

#### [check.lint]

Configure which auto-lint rules are active during `jac lint` and `jac lint --fix`. Rules use a select/ignore model with two group keywords:

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
| `remove-kwesc` | `W3006` | Remove unnecessary backtick escaping from non-keyword names | default |
| `hasattr-to-null-ok` | `W3007` | Convert `hasattr(obj, "attr")` to null-safe access (`obj?.attr`) | default |
| `simplify-ternary` | `W3008` | Simplify `x if x else default` to `x or default` | default |
| `remove-future-annotations` | `W3009` | Remove `import from __future__ { annotations }` (not needed in Jac) | default |
| `fix-impl-signature` | `W3010` | Fix signature mismatches between declarations and implementations | default |
| `remove-import-semi` | `W3011` | Remove trailing semicolons from `import from X { ... }` | default |
| `no-print` | `E3012` | Error on bare `print()` calls (use console abstraction instead) | all |

Diagnostic codes can be suppressed inline with `# jac:ignore[CODE]` comments. See the full [Errors & Warnings](../diagnostics.md) reference for all diagnostic codes.

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
enabled = true      # Enable caching
dir = ".jac_cache"  # Cache directory
```

---

### [storage]

!!! warning "Plugin-Specific Configuration"
    The `[storage]` section requires the **jac-scale** plugin and may not be available in all configurations. Running `jac config list -g storage` will return "Unknown group 'storage'" if the plugin is not installed.

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

See [Storage Reference](../plugins/jac-scale.md#storage) for the full storage API.

---

### [plugins]

Plugin configuration:

```toml
[plugins]
discovery = "auto"      # "auto", "manual", or "disabled"
enabled = ["byllm"] # Explicitly enabled
disabled = []           # Explicitly disabled

# Plugin-specific settings (byllm splits model identity from call params)
[plugins.byllm.model]
default_model = "gpt-4o"
api_key = "${OPENAI_API_KEY}"

[plugins.byllm.call_params]
temperature = 0.7

# Server settings (jac-scale)
[plugins.scale.server]
port = 8000
host = "0.0.0.0"
docs_enabled = true              # Set to false to disable /docs, /redoc, /openapi.json

# Webhook settings (jac-scale)
[plugins.scale.webhook]
secret = "your-webhook-secret-key"
signature_header = "X-Webhook-Signature"
verify_signature = true
api_key_expiry_days = 365

# Kubernetes version pinning (jac-scale)
[plugins.scale.kubernetes.plugin_versions]
jaclang = "latest"
jac_scale = "latest"
jac_client = "latest"
jac_byllm = "none"           # Use "none" to skip installation
jac_mcp = "latest"
```

**Prometheus Metrics (jac-scale):**

```toml
[plugins.scale.monitoring]
enabled = true
endpoint = "/metrics"
namespace = "myapp"
walker_metrics = true
```

See [Prometheus Metrics](../plugins/jac-scale.md#prometheus-metrics) for details.

**Kubernetes Secrets (jac-scale):**

```toml
[plugins.scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
DATABASE_PASSWORD = "${DB_PASS}"
```

See [Kubernetes Secrets](../plugins/jac-scale.md#kubernetes-secrets) for details.

See also [jac-scale Webhooks](../plugins/jac-scale.md#webhooks) and [Kubernetes Deployment](../plugins/jac-scale.md#kubernetes-deployment) for more options.

**Built-in Local Models (byllm):**

```toml
[plugins.byllm.model]
default_model = "local:gemma-4-e4b"   # in-process llama.cpp; no API key, no daemon

[plugins.byllm.local]
default_alias  = "gemma-4-e4b"        # used when default_model is unset
n_gpu_layers   = -1                   # -1 = offload all layers to GPU; 0 = CPU only
n_ctx          = 0                    # 0 = use the alias's bundled default
auto_download  = false                # true = skip the first-run TTY prompt
```

Bundled aliases are downloaded as Q4_K_M GGUFs into `~/.cache/jac/models/<alias>/` on first use and managed via `jac model list/pull/rm`. See [Built-in Local Models](../plugins/byllm.md#built-in-local-models) for the full reference and [`jac model`](../cli/index.md#jac-model) for cache management.

**Import Path Aliases (jac-client):**

```toml
[plugins.client.paths]
"@components/*" = "./components/*"
"@utils/*" = "./utils/*"
"@shared" = "./shared/index"
```

Defines custom import aliases applied to Vite `resolve.alias`, TypeScript `compilerOptions.paths`, and the Jac module resolver. See [jac-client Import Path Aliases](../plugins/jac-client.md#import-path-aliases) for details.

**NPM Registry Configuration (jac-client):**

```toml
[plugins.client.npm.scoped_registries]
"@mycompany" = "https://npm.pkg.github.com"

[plugins.client.npm.auth."//npm.pkg.github.com/"]
_authToken = "${NODE_AUTH_TOKEN}"
```

This generates an `.npmrc` file during dependency installation for private/scoped npm packages. See [jac-client NPM Registry Configuration](../plugins/jac-client.md#npm-registry-configuration) for details.

**Build-Time Constants (jac-client):**

Define global variables that are replaced at compile time in client code via the `[plugins.client.vite.define]` section:

```toml
[plugins.client.vite.define]
"globalThis.API_URL" = "\"https://api.example.com\""
"globalThis.FEATURE_ENABLED" = true
"globalThis.BUILD_VERSION" = "\"1.2.3\""
```

These values are inlined by Vite during bundling. String values must be double-quoted (JSON-encoded). In client code, access them directly:

```jac
to cl:

def:pub Footer() -> JsxElement {
    return <p>Version: {globalThis.BUILD_VERSION}</p>;
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
lint = "jac lint . --fix"
format = "jac format ."
```

Run with:

```bash
jac script dev
jac script test
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
[environments.development.plugins.byllm]
model = "gpt-3.5-turbo"

[environments.production]
inherits = "development"
[environments.production.run]
cache = true
[environments.production.plugins.byllm]
model = "gpt-4"
```

Activate a profile:

```bash
JAC_PROFILE=production jac run main.jac
```

---

## Environment Variables

Use environment variable interpolation:

```toml
[plugins.byllm.model]
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

### [package]

PyPI-publishable package metadata. This section is required to run `jac bundle`. It is separate from `[project]` so that application-level metadata (entry point, run settings) does not pollute the distributed package manifest.

```toml
[package]
name = "mylib"
version = "1.0.0"
description = "A Jac library"
license = "MIT"
readme = "README.md"
requires-python = ">=3.12"
keywords = ["jac", "ai"]

[[package.authors]]
name = "Your Name"
email = "you@example.com"

[[package.maintainers]]
name = "Another Person"
email = "them@example.com"

[package.urls]
homepage = "https://example.com"
repository = "https://github.com/user/mylib"
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Package name on PyPI (required) |
| `version` | string | Semantic version (required) |
| `description` | string | One-line summary shown on PyPI |
| `license` | string | SPDX license identifier (e.g. `"MIT"`) |
| `readme` | string | Path to README file (default: `README.md`) |
| `requires-python` | string | Minimum Python version (e.g. `">=3.12"`) |
| `keywords` | list | Search keywords on PyPI |
| `authors` | list of `{name, email}` | Package authors |
| `maintainers` | list of `{name, email}` | Package maintainers |
| `urls` | table | Links shown on PyPI (homepage, repository, etc.) |

> **Note:** `[project]` fields like `entry-point` and `jac-version` are for running your app. `[package]` fields are for distributing a library. A publishable project can have both.

---

### [package.include]

Controls which files and directories are bundled into the wheel.

```toml
[package.include]
# Explicit list of package directories to include.
# Defaults to a directory matching the package name (hyphens replaced with underscores).
packages = ["mylib", "mylib_utils"]

[package.include.data]
# "*" sets global file patterns for all packages.
"*" = ["**/*.jac", "**/*.py", "**/*.pyi", "py.typed"]

# Per-package overrides add extra patterns on top of globals.
mylib = ["**/*.lark", "data/*.json", "templates/**/*"]
```

**Default included patterns** (when `[package.include.data]` is absent):

| Pattern | Description |
|---------|-------------|
| `**/*.jac` | Jac source files |
| `**/*.py` | Python source files |
| `**/*.pyi` | Type stub files |
| `**/*.lark` | Lark grammar files |
| `**/py.typed` | PEP 561 type marker |
| `**/*.jir` | Pre-compiled JIR bytecode |

**Always excluded** (regardless of patterns):

- Directories: `.jac/`, `__pycache__/`, `dist/`, `build/`, `venv/`, `.venv/`, `env/`, `.git/`, `.hg/`, `node_modules/`, `*.egg-info/`
- File suffixes: `.pyc`

---

### [entrypoints]

Declare console scripts and plugin entry points. Maps directly to `entry_points.txt` in the wheel's `.dist-info`.

```toml
[entrypoints.scripts]
# Installs a "mylib" CLI command pointing to mylib.cli:main
mylib = "mylib.cli:main"

[entrypoints.jac]
# Declare a Jac plugin; discovered via entry_points(group="jac")
mylib = "mylib.plugin:setup"
```

The `[entrypoints.scripts]` group is written as `[console_scripts]` in `entry_points.txt`, which is the standard pip convention for installing CLI commands. After a user runs `pip install mylib`, the `mylib` command is available on their `PATH`.

The `[entrypoints.jac]` group is the entry point group Jac's plugin system queries at startup (`entry_points(group="jac")`). Any package that declares an entry point here will be auto-discovered when the user has it installed.

---

## CLI Override

Most settings can be overridden via CLI flags:

```bash
# Override run settings
jac run --no-cache main.jac

# Override test settings
jac test --verbose -x

# Override serve settings
jac start --port 3000
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
topology_index = true

[serve]
port = 8000
cl_route_prefix = "cl"

[test]
directory = "tests"
verbose = true

[build]
typecheck = true
dir = ".jac"

[check.lint]
select = ["all"]
ignore = []
exclude = []

[plugins]
discovery = "auto"

[plugins.byllm.model]
default_model = "${LLM_MODEL:-gpt-4o-mini}"
api_key = "${OPENAI_API_KEY}"

[scripts]
dev = "jac run main.jac"
test = "jac test"
lint = "jac lint . --fix"
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

Each line is a filename or pattern that should be skipped during Jac compilation passes (type checking, formatting, etc.).

---

## Environment Variables

### General

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable colored terminal output |
| `NO_EMOJI` | Disable emoji in terminal output |
| `JAC_PROFILE` | Activate a configuration profile (e.g., `production`) |
| `JAC_BASE_PATH` | Override base directory for data/storage |

### Storage

| Variable | Description |
|----------|-------------|
| `JAC_STORAGE_TYPE` | Storage backend type |
| `JAC_STORAGE_PATH` | Base directory for file storage |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create directories |

### jac-scale: Database

| Variable | Description |
|----------|-------------|
| `MONGODB_URI` | MongoDB connection URI |
| `REDIS_URL` | Redis connection URL |

### jac-scale: Authentication

| Variable | Description | Default |
|----------|-------------|---------|
| `JWT_SECRET` | Secret key for JWT signing | `supersecretkey` |
| `JWT_ALGORITHM` | JWT algorithm | `HS256` |
| `JWT_EXP_DELTA_DAYS` | Token expiration in days | `7` |
| `SSO_HOST` | SSO callback host URL | `http://localhost:8000/sso` |
| `SSO_GOOGLE_CLIENT_ID` | Google OAuth client ID | None |
| `SSO_GOOGLE_CLIENT_SECRET` | Google OAuth client secret | None |

### jac-scale: Webhooks

| Variable | Description |
|----------|-------------|
| `WEBHOOK_SECRET` | Secret for webhook HMAC signatures |
| `WEBHOOK_SIGNATURE_HEADER` | Header name for signature |
| `WEBHOOK_VERIFY_SIGNATURE` | Enable signature verification |
| `WEBHOOK_API_KEY_EXPIRY_DAYS` | API key expiry in days |

### jac-scale: Kubernetes

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_NAME` | Application name for K8s resources | `jaseci` |
| `K8s_NAMESPACE` | Kubernetes namespace | `default` |
| `K8s_NODE_PORT` | External NodePort | `30001` |
| `K8s_CPU_REQUEST` | CPU resource request | None |
| `K8s_CPU_LIMIT` | CPU resource limit | None |
| `K8s_MEMORY_REQUEST` | Memory resource request | None |
| `K8s_MEMORY_LIMIT` | Memory resource limit | None |
| `DOCKER_USERNAME` | DockerHub username | None |
| `DOCKER_PASSWORD` | DockerHub password/token | None |

---

## See Also

- [CLI Reference](../cli/index.md) - Command-line interface documentation
- [Plugin Management](../cli/index.md#plugin-management) - Managing plugins
