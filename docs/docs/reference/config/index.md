# Configuration Reference

The `jac.toml` file is the central configuration for Jac projects. It defines project metadata, dependencies, command defaults, and plugin settings.

## Creating a Project

```bash
jac create myapp
cd myapp
```

This creates a `jac.toml` with default settings.

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
- `.jac/packages/` - Installed packages
- `.jac/client/` - Client-side builds
- `.jac/data/` - Runtime data

---

### [test]

Defaults for `jac test`:

```toml
[test]
directory = "tests"     # Test directory
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
fix = false         # Auto-fix issues
```

---

### [check]

Defaults for `jac check`:

```toml
[check]
print_errs = true   # Print errors to console
warnonly = false    # Treat errors as warnings
```

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
```

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
```

---

### [scripts]

Custom command shortcuts:

```toml
[scripts]
dev = "jac run main.jac"
test = "jac test -v"
build = "jac build main.jac -t"
lint = "jac check ."
format = "jac format . --fix"
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
jac run main.jac --no-cache --session my_session

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

[plugins]
discovery = "auto"

[plugins.byllm]
model = "${LLM_MODEL:-gpt-4}"
api_key = "${OPENAI_API_KEY}"

[scripts]
dev = "jac run main.jac"
test = "jac test"
format = "jac format . --fix"
```

---

## See Also

- [CLI Reference](../cli/index.md) - Command-line interface documentation
- [CLI Reference](../cli/index.md) - Command-line interface documentation
- [Plugin Management](../cli/index.md#plugin-management) - Managing plugins
