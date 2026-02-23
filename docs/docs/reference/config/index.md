# Configuration Reference

The `jac.toml` file is the central configuration for Jac projects. It defines project metadata, dependencies, command defaults, and plugin settings.

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

### [run]

Defaults for `jac run`:

```toml
[run]
session = ""        # Session name for persistence
main = true         # Run as main module
cache = true        # Use bytecode cache
```

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
warnonly = false     # Treat errors as warnings
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

| Rule Name | Description | Group |
|-----------|-------------|-------|
| `combine-has` | Combine consecutive `has` statements with same modifiers | default |
| `combine-glob` | Combine consecutive `glob` statements with same modifiers | default |
| `staticmethod-to-static` | Convert `@staticmethod` decorator to `static` keyword | default |
| `init-to-can` | Convert `def __init__` / `def __post_init__` to `can init` / `can postinit` | default |
| `remove-empty-parens` | Remove empty parentheses from declarations (`def foo()` → `def foo`) | default |
| `remove-kwesc` | Remove unnecessary backtick escaping from non-keyword names | default |
| `hasattr-to-null-ok` | Convert `hasattr(obj, "attr")` to null-safe access (`obj?.attr`) | default |
| `simplify-ternary` | Simplify `x if x else default` to `x or default` | default |
| `remove-future-annotations` | Remove `import from __future__ { annotations }` (not needed in Jac) | default |
| `fix-impl-signature` | Fix signature mismatches between declarations and implementations | default |
| `remove-import-semi` | Remove trailing semicolons from `import from X { ... }` | default |
| `no-print` | Error on bare `print()` calls (use console abstraction instead) | all |

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

# Plugin-specific settings
[plugins.byllm]
model = "gpt-4"
temperature = 0.7
api_key = "${OPENAI_API_KEY}"

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
```

**Prometheus Metrics (jac-scale):**

```toml
[plugins.scale.metrics]
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
[plugins.byllm]
api_key = "${OPENAI_API_KEY}"              # Required
model = "${MODEL:-gpt-3.5-turbo}"          # With default
secret = "${SECRET:?Secret is required}"   # Required with error
```

| Syntax | Description |
|--------|-------------|
| `${VAR}` | Use variable (error if not set) |
| `${VAR:-default}` | Use default if not set |
| `${VAR:?error}` | Custom error if not set |

---

## CLI Override

Most settings can be overridden via CLI flags:

```bash
# Override run settings
jac run --no-cache --session my_session main.jac

# Override test settings
jac test --verbose --fail-fast

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

[plugins.byllm]
model = "${LLM_MODEL:-gpt-4}"
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
