# Project Configuration with jac.toml

The `jac.toml` file is the central configuration file for Jac projects. Similar to `pyproject.toml` in Python or `package.json` in Node.js, it defines project metadata, dependencies, and command defaults.

## Getting Started

### Creating a New Project

To create a new Jac project with a `jac.toml` file:

```bash
jac create my-project
cd my-project
```

The `jac create` command supports several options:

- `-f, --force`: Overwrite existing `jac.toml` if present
- `-u, --use`: Jacpac template: registered name, file path, or URL

Examples:

```bash
# Create a basic project
jac create myapp

# Create with frontend support (requires jac-client plugin)
jac create myapp --use client

# Create in current directory (overwrites existing jac.toml)
jac create --force
```

This creates a project with a basic `jac.toml`:

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "A Jac project"
entry-point = "main.jac"

[dependencies]

[dev-dependencies]
watchdog = ">=3.0.0"  # Required for HMR (jac start --watch)

[run]
main = true
cache = true
```

### Project Structure

A typical Jac project looks like:

```
my-project/
├── jac.toml          # Project configuration
├── main.jac          # Entry point
├── packages/         # Installed dependencies
├── lib/              # Library modules (optional)
│   └── utils.jac
└── tests/            # Test files (optional)
    └── test_main.jac
```

## Configuration Reference

### [project] Section

Defines project metadata:

```toml
[project]
name = "my-awesome-app"
version = "1.0.0"
description = "An awesome Jac application"
authors = ["Your Name <you@example.com>"]
license = "MIT"
readme = "README.md"
jac-version = ">=0.7.0"
entry-point = "main.jac"

[project.urls]
homepage = "https://example.com"
repository = "https://github.com/user/repo"
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Project name (required) |
| `version` | string | Semantic version (e.g., "1.0.0") |
| `description` | string | Brief project description |
| `authors` | list | List of author strings |
| `license` | string | License identifier (e.g., "MIT", "Apache-2.0") |
| `readme` | string | Path to README file |
| `jac-version` | string | Required Jac version constraint |
| `entry-point` | string | Main entry file (default: "main.jac") |
| `urls` | table | Project URLs (homepage, repository, etc.) |

### [dependencies] Section

Specifies project dependencies:

```toml
[dependencies]
# Python/PyPI packages
requests = ">=2.28.0"
numpy = "1.24.0"

# Jac plugins
jac-byllm = ">=0.4.8"

# Version specifiers
some-package = ">=1.0,<2.0"  # Range
another = "~=1.4.2"          # Compatible release
```

**Version Specifier Formats:**

| Format | Example | Description |
|--------|---------|-------------|
| Exact | `"1.0.0"` | Exact version |
| Minimum | `">=1.0.0"` | At least this version |
| Maximum | `"<2.0.0"` | Less than this version |
| Range | `">=1.0,<2.0"` | Version range |
| Compatible | `"~=1.4.2"` | Compatible with 1.4.x |

### [dev-dependencies] Section

Development-only dependencies (not installed in production):

```toml
[dev-dependencies]
watchdog = ">=3.0.0"  # Required for HMR (jac start --watch)
pytest = ">=8.2.1"
mypy = ">=1.0.0"
black = ">=23.0.0"
```

The `watchdog` package is included by default in new projects to enable Hot Module Replacement during development.

### [dependencies.git] Section

Git-based dependencies:

```toml
[dependencies.git]
my-private-lib = { git = "https://github.com/user/repo.git", branch = "main" }
another-lib = { git = "git@github.com:user/repo.git", tag = "v1.0.0" }
```

### [run] Section

Default options for `jac run`:

```toml
[run]
session = ""        # Session name for persistence
main = true         # Run as main module
cache = true        # Enable bytecode caching
```

### [build] Section

Build configuration:

```toml
[build]
typecheck = false   # Enable type checking during build
```

### [test] Section

Test runner configuration:

```toml
[test]
directory = "tests"     # Test directory
filter = ""             # Test filter pattern
verbose = false         # Verbose output
fail_fast = false       # Stop on first failure
max_failures = 0        # Max failures before stopping (0 = unlimited)
```

### [serve] Section

Server configuration for `jac start`:

```toml
[serve]
port = 8000              # Server port
session = ""             # Session name
main = true              # Run as main module
cl_route_prefix = "cl"   # URL prefix for client apps (default: "cl")
base_route_app = ""      # Client app to serve at root "/" (default: none)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `port` | int | `8000` | Server port number |
| `session` | string | `""` | Session file name for persistence |
| `main` | bool | `true` | Run as main module |
| `cl_route_prefix` | string | `"cl"` | URL prefix for client-side apps. Apps are served at `/<prefix>/<app_name>`. |
| `base_route_app` | string | `""` | Name of a client app to serve at root `/`. When set, visiting `/` renders this app instead of the API info page. |

### [format] Section

Code formatter configuration:

```toml
[format]
outfile = ""        # Output file (empty = in-place)
fix = false         # Auto-fix formatting issues
```

### [check] Section

Type checker configuration:

```toml
[check]
print_errs = true   # Print errors to console
warnonly = false    # Treat errors as warnings
```

### [dot] Section

Graph visualization configuration for `jac dot`:

```toml
[dot]
depth = -1          # Traversal depth (-1 = unlimited)
traverse = false    # Traverse connections
bfs = false         # Use BFS traversal (vs DFS)
edge_limit = 512    # Maximum edges in output
node_limit = 512    # Maximum nodes in output
format = "dot"      # Output format
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `depth` | int | `-1` | How deep to traverse (-1 = unlimited) |
| `traverse` | bool | `false` | Whether to traverse connections |
| `bfs` | bool | `false` | Use breadth-first search (default is DFS) |
| `edge_limit` | int | `512` | Maximum number of edges to include |
| `node_limit` | int | `512` | Maximum number of nodes to include |
| `format` | string | `"dot"` | Output format for the graph |

### [cache] Section

Bytecode cache configuration:

```toml
[cache]
enabled = true          # Enable bytecode caching

[build]
dir = ".jac"            # Base directory for all build artifacts (cache, packages, client, data)
```

All build artifacts are organized under the `[build].dir` directory (default `.jac/`):

- `.jac/cache/` - Bytecode cache files
- `.jac/packages/` - Installed Python packages
- `.jac/client/` - Client-side build artifacts
- `.jac/data/` - Runtime data (databases, sessions)

### [scripts] Section

Custom scripts and shortcuts:

```toml
[scripts]
dev = "jac run main.jac"
build = "jac build main.jac --typecheck"
test = "jac test tests/"
lint = "jac check ."
format = "jac format . --fix"
```

Run scripts with:

```bash
jac script dev
jac script test
```

### [plugins] Section

Plugin configuration:

```toml
[plugins]
discovery = "auto"      # "auto", "manual", or "disabled"
enabled = ["jac-byllm"] # Explicitly enabled plugins
disabled = []           # Explicitly disabled plugins

# Plugin-specific configuration
[plugins.jac-byllm]
model = "gpt-4"
temperature = 0.7
```

### [environment] and [environments] Sections

Environment-based configuration profiles:

```toml
[environment]
default_profile = "development"

[environments.development]
[environments.development.run]
cache = false

[environments.development.plugins.jac-byllm]
model = "gpt-3.5-turbo"

[environments.production]
inherits = "development"  # Inherit from another profile

[environments.production.run]
cache = true

[environments.production.plugins.jac-byllm]
model = "gpt-4"
```

Activate a profile:

```bash
JAC_PROFILE=production jac run main.jac
```

## Environment Variable Interpolation

Use environment variables in configuration values:

```toml
[plugins.jac-byllm]
api_key = "${OPENAI_API_KEY}"                    # Required variable
model = "${MODEL_NAME:-gpt-3.5-turbo}"           # With default value
secret = "${API_SECRET:?API secret is required}" # Required with custom error
```

| Syntax | Description |
|--------|-------------|
| `${VAR}` | Use variable (error if not set) |
| `${VAR:-default}` | Use default if not set |
| `${VAR:?error}` | Custom error message if not set |

## Dependency Management

### Installing Dependencies

```bash
# Install all dependencies
jac install

# Install including dev dependencies
jac install --dev

# Install a specific package
jac install requests

# Install and add to jac.toml
jac add requests>=2.28.0

# Add a dev dependency
jac add --dev pytest
```

### Packages Directory

Dependencies are installed to the `packages/` directory in your project root:

```
my-project/
├── jac.toml
└── packages/
    ├── requests/
    ├── numpy/
    └── ...
```

The `packages/` directory is automatically added to the Python path when running Jac code.

## CLI Integration

Most `jac.toml` settings can be overridden via CLI flags:

```bash
# Override run settings
jac run main.jac --no-cache --session my-session

# Override test settings
jac test --verbose --fail-fast --max-failures 5

# Override serve settings
jac start --port 3000

# Override build settings
jac build main.jac --typecheck
```

## Complete Example

Here's a comprehensive `jac.toml` example:

```toml
# jac.toml - Jac Project Configuration

[project]
name = "my-ai-app"
version = "1.0.0"
description = "An AI-powered application built with Jac"
authors = ["Developer <dev@example.com>"]
license = "MIT"
entry-point = "main.jac"

[project.urls]
homepage = "https://my-ai-app.example.com"
repository = "https://github.com/user/my-ai-app"

#===============================================================================
# DEPENDENCIES
#===============================================================================

[dependencies]
jac-byllm = ">=0.4.8"
requests = ">=2.28.0"
pydantic = ">=2.0.0"

[dev-dependencies]
watchdog = ">=3.0.0"  # Required for HMR
pytest = ">=8.2.1"
pytest-asyncio = ">=0.21.0"

[dependencies.git]
private-utils = { git = "https://github.com/myorg/utils.git", branch = "main" }

#===============================================================================
# COMMAND DEFAULTS
#===============================================================================

[run]
main = true
cache = true

[test]
directory = "tests"
verbose = true
fail_fast = false

[serve]
port = 8000
cl_route_prefix = "cl"   # Client apps at /cl/<name>
base_route_app = ""      # Set to app name to serve at /

[format]
fix = false

[check]
print_errs = true
warnonly = false

[dot]
depth = -1               # Unlimited depth
edge_limit = 512
node_limit = 512

#===============================================================================
# BUILD AND CACHE SETTINGS
#===============================================================================

[build]
typecheck = true
dir = ".jac"             # All build artifacts go here (.jac/cache, .jac/packages, etc.)

[cache]
enabled = true

#===============================================================================
# PLUGINS
#===============================================================================

[plugins]
discovery = "auto"

[plugins.jac-byllm]
model = "${LLM_MODEL:-gpt-4}"
api_key = "${OPENAI_API_KEY}"
temperature = 0.7

#===============================================================================
# ENVIRONMENTS
#===============================================================================

[environment]
default_profile = "development"

[environments.development]
[environments.development.run]
cache = false
[environments.development.plugins.jac-byllm]
model = "gpt-3.5-turbo"

[environments.production]
inherits = "development"
[environments.production.run]
cache = true
[environments.production.plugins.jac-byllm]
model = "gpt-4"

#===============================================================================
# SCRIPTS
#===============================================================================

[scripts]
dev = "jac run main.jac"
build = "jac build main.jac --typecheck"
test = "jac test"
serve = "jac start --port 8000"
format = "jac format . --fix"
```

## Project Discovery

Jac automatically discovers `jac.toml` by searching from the current directory upward to the filesystem root. This means you can run Jac commands from any subdirectory within your project:

```bash
cd my-project/lib
jac run ../main.jac  # jac.toml is found automatically
```

## Programmatic Access

You can access project configuration programmatically in Jac code:

```jac
import from jaclang.project { JacConfig, get_config };

with entry {
    config = get_config();

    if config {
        print(f"Project: {config.project.name}");
        print(f"Version: {config.project.version}");
        print(f"Dependencies: {list(config.dependencies.keys())}");
    }
}
```

Or in Python:

```python
from jaclang.project import JacConfig, get_config

config = get_config()
if config:
    print(f"Project: {config.project.name}")
    print(f"Version: {config.project.version}")
```
