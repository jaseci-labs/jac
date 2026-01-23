# CLI Reference

The Jac CLI provides commands for running, building, testing, and deploying Jac applications.

> **💡 Enhanced Output**: For beautiful, colorful terminal output with Rich formatting, install the optional `jac-super` plugin: `pip install jac-super`. All CLI commands will automatically use enhanced output with themes, panels, and spinners.

## Quick Reference

| Command | Description |
|---------|-------------|
| `jac run` | Execute a Jac file |
| `jac start` | Start REST API server (use `--scale` for K8s deployment) |
| `jac create` | Create new project |
| `jac check` | Type check code |
| `jac test` | Run tests |
| `jac format` | Format code |
| `jac clean` | Clean project build artifacts |
| `jac enter` | Run specific entrypoint |
| `jac dot` | Generate graph visualization |
| `jac debug` | Interactive debugger |
| `jac plugins` | Manage plugins |
| `jac config` | Manage project configuration |
| `jac destroy` | Remove Kubernetes deployment (jac-scale) |
| `jac add` | Add packages to project |
| `jac install` | Install project dependencies |
| `jac remove` | Remove packages from project |
| `jac jacpack` | Manage project templates (.jacpack files) |
| `jac get_object` | Retrieve object by ID |
| `jac py2jac` | Convert Python to Jac |
| `jac jac2py` | Convert Jac to Python |
| `jac tool` | Language tools (IR, AST) |
| `jac lsp` | Language server |
| `jac js` | JavaScript output |

---

## Core Commands

### jac run

Execute a Jac file.

**Note:** `jac <file>` is shorthand for `jac run <file>` - both work identically.

```bash
jac run [-h] [-m] [--no-main] [-c] [--no-cache] [filename]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to run | Required |
| `-m, --main` | Treat module as `__main__` | `True` |
| `-c, --cache` | Enable compilation cache | `True` |

**Examples:**

```bash
# Run a file
jac run main.jac

# Run without cache
jac run main.jac --no-cache
```

---

### jac start

Start a Jac application as an HTTP API server. With the jac-scale plugin installed, use `--scale` to deploy to Kubernetes. Use `--dev` for Hot Module Replacement (HMR) during development.

```bash
jac start [-h] [-p PORT] [-m] [--no-main] [-f] [--no-faux] [-d] [--no-dev] [-a API_PORT] [-n] [--no-no_client] [--scale] [--no-scale] [-b] [--no-build] [filename]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to serve | `main.jac` |
| `-p, --port` | Port number | `8000` |
| `-m, --main` | Treat as `__main__` | `True` |
| `-f, --faux` | Print docs only (no server) | `False` |
| `-d, --dev` | Enable HMR (Hot Module Replacement) mode | `False` |
| `-a, --api_port` | Separate API port for HMR mode (0=same as port) | `0` |
| `-n, --no_client` | Skip client bundling/serving (API only) | `False` |
| `--scale` | Deploy to Kubernetes (requires jac-scale) | `False` |
| `-b, --build` | Build Docker image before deploy (with `--scale`) | `False` |

**Examples:**

```bash
# Start with default main.jac on default port
jac start

# Start on custom port
jac start -p 3000

# Start with Hot Module Replacement (development)
jac start --dev

# HMR mode without client bundling (API only)
jac start --dev --no-client

# Deploy to Kubernetes (requires jac-scale plugin)
jac start --scale

# Build and deploy to Kubernetes
jac start --scale --build
```

> **Note**:
>
> - If your project uses a different entry file (e.g., `app.jac`, `server.jac`), you can specify it explicitly: `jac start app.jac`
>
---

### jac create

Initialize a new Jac project with configuration. Creates a project folder with the given name containing the project files.

```bash
jac create [-h] [-f] [-u USE] [-l] [name]
```

| Option | Description | Default |
|--------|-------------|---------|
| `name` | Project name (creates folder with this name) | Current directory name |
| `-f, --force` | Overwrite existing project | `False` |
| `-u, --use` | Jacpac template: registered name, file path, or URL | `default` |
| `-l, --list-jacpacks` | List available jacpack templates | `False` |

**Examples:**

```bash
# Create basic project (creates myapp/ folder)
jac create myapp
cd myapp

# Create full-stack project with client template (requires jac-client)
jac create myapp --use client

# Create from a local .jacpack file
jac create myapp --use ./my-template.jacpack

# Create from a local template directory
jac create myapp --use ./my-template/

# Create from a URL
jac create myapp --use https://example.com/template.jacpack

# List available jacpack templates
jac create --list-jacpacks

# Force overwrite existing
jac create myapp --force

# Create in current directory
jac create
```

**See Also:** Use `jac jacpack` to create and bundle custom templates.

---

### jac check

Type check Jac code for errors.

```bash
jac check [-h] [-p] [-np] [-w] [-nw] [--ignore PATTERNS] paths [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to check | Required |
| `-p, --print_errs` | Print errors | `True` |
| `-w, --warnonly` | Warnings only (no errors) | `False` |
| `--ignore` | Comma-separated list of files/folders to ignore | None |

**Examples:**

```bash
# Check a file
jac check main.jac

# Check a directory
jac check src/

# Warnings only mode
jac check main.jac -w

# Check directory excluding specific folders/files
jac check myproject/ --ignore fixtures,tests

# Check excluding multiple patterns
jac check . --ignore node_modules,dist,__pycache__
```

---

### jac test

Run tests in Jac files.

```bash
jac test [-h] [-t TEST_NAME] [-f FILTER] [-x] [-m MAXFAIL] [-d DIRECTORY] [-v] [filepath]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filepath` | Test file to run | None |
| `-t, --test_name` | Specific test name | None |
| `-f, --filter` | Filter tests by pattern | None |
| `-x, --xit` | Exit on first failure | `False` |
| `-m, --maxfail` | Max failures before stop | None |
| `-d, --directory` | Test directory | None |
| `-v, --verbose` | Verbose output | `False` |

**Examples:**

```bash
# Run all tests in a file
jac test main.jac

# Run tests in directory
jac test -d tests/

# Run specific test
jac test main.jac -t my_test

# Stop on first failure
jac test main.jac -x

# Verbose output
jac test main.jac -v
```

---

### jac format

Format Jac code according to style guidelines.

```bash
jac format [-h] [-t] [-f] paths [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to format | Required |
| `-t, --to_screen` | Print to screen (don't write) | `False` |
| `-f, --fix` | Apply fixes in place | `False` |

**Examples:**

```bash
# Preview formatting
jac format main.jac -t

# Apply formatting
jac format main.jac --fix

# Format entire directory
jac format . --fix
```

---

### jac enter

Run a specific entrypoint in a Jac file.

```bash
jac enter [-h] -e ENTRYPOINT [-s SESSION] [-m] [-r ROOT] [-n NODE] filename [args ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file | Required |
| `-e, --entrypoint` | Entrypoint function/walker | Required |
| `args` | Arguments to pass | None |
| `-s, --session` | Session name | None |
| `-r, --root` | Root node ID | None |
| `-n, --node` | Target node ID | None |

**Examples:**

```bash
# Run specific entrypoint
jac enter main.jac -e my_walker

# With arguments
jac enter main.jac -e process_data arg1 arg2

# With session
jac enter main.jac -e my_walker -s my_session
```

---

## Visualization & Debug

### jac dot

Generate DOT graph visualization.

```bash
jac dot [-h] [-s SESSION] [-i INITIAL] [-d DEPTH] [-t] [-b] [-e EDGE_LIMIT] [-n NODE_LIMIT] [-sa SAVETO] [-to] [-f FORMAT] filename [connection ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file | Required |
| `-s, --session` | Session name | None |
| `-i, --initial` | Initial node | None |
| `-d, --depth` | Traversal depth | `-1` (unlimited) |
| `-t, --traverse` | Traverse connections | `False` |
| `-b, --bfs` | Use BFS traversal | `False` |
| `-e, --edge_limit` | Max edges | `512` |
| `-n, --node_limit` | Max nodes | `512` |
| `-sa, --saveto` | Output file path | None |
| `-to, --to_screen` | Print to screen | `False` |
| `-f, --format` | Output format | `dot` |

**Examples:**

```bash
# Generate DOT output
jac dot main.jac -s my_session --to_screen

# Save to file
jac dot main.jac -s my_session --saveto graph.dot

# Limit depth
jac dot main.jac -s my_session -d 3
```

---

### jac debug

Start interactive debugger.

```bash
jac debug [-h] [-m] [-c] filename
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to debug | Required |
| `-m, --main` | Run main entry | `True` |
| `-c, --cache` | Use cache | `False` |

**Examples:**

```bash
# Start debugger
jac debug main.jac
```

---

## Plugin Management

### jac plugins

Manage Jac plugins.

```bash
jac plugins [-h] [-v] [action] [names ...]
```

| Action | Description |
|--------|-------------|
| `list` | List installed plugins (default) |
| `install` | Install plugins |
| `uninstall` | Remove plugins |
| `enable` | Enable plugins |
| `disable` | Disable plugins |

| Option | Description | Default |
|--------|-------------|---------|
| `-v, --verbose` | Verbose output | `False` |

**Examples:**

```bash
# List plugins (action defaults to 'list')
jac plugins

# Explicitly list plugins
jac plugins list

# Install a plugin
jac plugins install jac-scale

# Install jac-super for enhanced console output
jac plugins install jac-super

# Uninstall
jac plugins uninstall byllm
```

> **💡 Popular Plugins**:
>
> - **jac-super**: Enhanced console output with Rich formatting, colors, and spinners (`pip install jac-super`)
> - **jac-client**: Full-stack web development with client-side rendering (`pip install jac-client`)
> - **jac-scale**: Kubernetes deployment and scaling (`pip install jac-scale`)

---

## Configuration Management

### jac config

View and modify project configuration settings in `jac.toml`.

```bash
jac config [action] [-k KEY] [-v VALUE] [-g GROUP] [-o FORMAT]
```

| Action | Description |
|--------|-------------|
| `show` | Display explicitly set configuration values (default) |
| `list` | Display all settings including defaults |
| `get` | Get a specific setting value |
| `set` | Set a configuration value |
| `unset` | Remove a configuration value |
| `path` | Show path to config file |
| `groups` | List available configuration groups |

| Option | Description | Default |
|--------|-------------|---------|
| `-k, --key` | Configuration key (e.g., `project.name`) | None |
| `-v, --value` | Value to set | None |
| `-g, --group` | Filter by configuration group | None |
| `-o, --output` | Output format (`table`, `json`, `toml`) | `table` |

**Configuration Groups:**

- `project` - Project metadata (name, version, description)
- `run` - Runtime settings (cache, session)
- `build` - Build settings (typecheck, output directory)
- `test` - Test settings (verbose, filters)
- `serve` - Server settings (port, host)
- `format` - Formatting options
- `check` - Type checking options
- `dot` - Graph visualization settings
- `cache` - Cache configuration
- `plugins` - Plugin management
- `environment` - Environment variables

**Examples:**

```bash
# Show explicitly set configuration
jac config show

# Show all settings including defaults
jac config list

# Show settings for a specific group
jac config show -g project

# Get a specific value
jac config get -k project.name

# Set a value
jac config set -k project.version -v "2.0.0"

# Remove a value (revert to default)
jac config unset -k run.cache

# Show config file path
jac config path

# List available groups
jac config groups

# Output as JSON
jac config show -o json

# Output as TOML
jac config list -o toml
```

---

## Deployment (jac-scale)

### jac start --scale

Deploy to Kubernetes using the jac-scale plugin. See the [`jac start`](#jac-start) command above for full options.

```bash
jac start --scale           # Deploy without building
jac start --scale --build   # Build and deploy
```

---

### jac destroy

Remove a deployment.

```bash
jac destroy [-h] file_path
```

| Option | Description | Default |
|--------|-------------|---------|
| `file_path` | Jac file to undeploy | Required |

**Examples:**

```bash
jac destroy main.jac
```

---

## Package Management

### jac add

Add packages to your project's dependencies.

```bash
jac add [-h] [-d] [-g GIT] [-v] [packages ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Package names to add | None |
| `-d, --dev` | Add as dev dependency | `False` |
| `-g, --git` | Git repository URL | None |
| `-v, --verbose` | Show detailed output | `False` |

**With jac-client plugin:**

| Option | Description | Default |
|--------|-------------|---------|
| `--npm` | Add as client-side (npm) package | `False` |

**Examples:**

```bash
# Add a package
jac add requests

# Add multiple packages
jac add numpy pandas scipy

# Add as dev dependency
jac add pytest --dev

# Add from git repository
jac add --git https://github.com/user/package.git

# Add npm package (requires jac-client)
jac add react --npm
```

---

### jac install

Install all dependencies defined in jac.toml.

```bash
jac install [-h] [-d] [-v]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --dev` | Include dev dependencies | `False` |
| `-v, --verbose` | Show detailed output | `False` |

**Examples:**

```bash
# Install all dependencies
jac install

# Install including dev dependencies
jac install --dev

# Install with verbose output
jac install -v
```

---

### jac remove

Remove packages from your project's dependencies.

```bash
jac remove [-h] [-d] [packages ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Package names to remove | None |
| `-d, --dev` | Remove from dev dependencies | `False` |

**With jac-client plugin:**

| Option | Description | Default |
|--------|-------------|---------|
| `--npm` | Remove client-side (npm) package | `False` |

**Examples:**

```bash
# Remove a package
jac remove requests

# Remove multiple packages
jac remove numpy pandas

# Remove dev dependency
jac remove pytest --dev

# Remove npm package (requires jac-client)
jac remove react --npm
```

---

### jac clean

Clean project build artifacts from the `.jac/` directory.

```bash
jac clean [-h] [-a] [-d] [-c] [-p] [-f]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-a, --all` | Clean all `.jac` artifacts (data, cache, packages, client) | `False` |
| `-d, --data` | Clean data directory (`.jac/data`) | `False` |
| `-c, --cache` | Clean cache directory (`.jac/cache`) | `False` |
| `-p, --packages` | Clean packages directory (`.jac/packages`) | `False` |
| `-f, --force` | Force clean without confirmation prompt | `False` |

By default (no flags), `jac clean` removes only the data directory (`.jac/data`).

**Examples:**

```bash
# Clean data directory (default)
jac clean

# Clean all build artifacts
jac clean --all

# Clean only cache
jac clean --cache

# Clean data and cache directories
jac clean --data --cache

# Force clean without confirmation
jac clean --all --force
```

> **💡 Troubleshooting Tip:** If you encounter unexpected syntax errors, "NodeAnchor is not a valid reference" errors, or other strange behavior after modifying your code, try clearing the cache with `jac clean --cache` or `rm -rf .jac`. Stale bytecode can cause issues when source files change.

---

## Template Management

### jac jacpack

Manage project templates. Bundle template directories into distributable `.jacpack` files or list available templates.

```bash
jac jacpack [action] [path] [-o OUTPUT]
```

| Action | Description |
|--------|-------------|
| `pack` | Bundle a template directory into a `.jacpack` file |
| `list` | List available templates (default) |
| `info` | Show information about a template |

| Option | Description | Default |
|--------|-------------|---------|
| `path` | Template directory (for pack) or `.jacpack` file (for info) | None |
| `-o, --output` | Output file path for bundled template | `<name>.jacpack` |

**Template Directory Structure:**

A template directory should contain:

- `jac.toml` - Project config with a `[jacpack]` section for metadata
- Template files (`.jac`, `.md`, etc.) with `{{name}}` placeholders

To make any Jac project packable as a template, simply add a `[jacpack]` section to your `jac.toml`. All other sections become the config for created projects.

**Example `jac.toml` for a template:**

```toml
# Standard project config (becomes the created project's jac.toml)
[project]
name = "{{name}}"
version = "0.1.0"
entry-point = "main.jac"

[dependencies]

# Jacpac metadata - used when packing, stripped from created projects
[jacpack]
name = "mytemplate"
description = "My custom project template"
jaclang = "0.9.0"

[[jacpack.plugins]]
name = "jac-client"
version = "0.1.0"

[jacpack.options]
directories = [".jac"]
gitignore_entries = ["*"]
root_gitignore_entries = [".jac/"]
```

**Examples:**

```bash
# List available templates
jac jacpack list

# Bundle a template directory
jac jacpack pack ./my-template

# Bundle with custom output path
jac jacpack pack ./my-template -o custom-name.jacpack

# Show template info
jac jacpack info ./my-template
jac jacpack info mytemplate.jacpack
```

**Using Templates with `jac create`:**

Once a template is registered, use it with the `--use` flag:

```bash
jac create myproject --use mytemplate
```

---

### jac js

Generate JavaScript output from Jac code (used for jac-client frontend compilation).

```bash
jac js [-h] filename
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to compile to JS | Required |

**Examples:**

```bash
# Generate JS from Jac file
jac js app.jac
```

---

## Utility Commands

### jac get_object

Retrieve an object by ID from a session.

```bash
jac get_object [-h] -i ID [-s SESSION] filename
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file | Required |
| `-i, --id` | Object ID | Required |
| `-s, --session` | Session name | None |

**Examples:**

```bash
jac get_object main.jac -i "node_123" -s my_session
```

---

### jac py2jac

Convert Python code to Jac.

```bash
jac py2jac filename
```

**Examples:**

```bash
jac py2jac script.py
```

---

### jac jac2py

Convert Jac code to Python.

```bash
jac jac2py filename
```

**Examples:**

```bash
jac jac2py main.jac
```

---

### jac tool

Access language tools (IR, AST, etc.).

```bash
jac tool tool [args ...]
```

**Available tools:**

```bash
# View IR options
jac tool ir

# View AST
jac tool ir ast main.jac

# View symbol table
jac tool ir sym main.jac

# View generated Python
jac tool ir py main.jac
```

---

### jac lsp

Start the Language Server Protocol server (for IDE integration).

```bash
jac lsp
```

---

## Common Workflows

### Development

```bash
# Create project
jac create myapp
cd myapp

# Run
jac run main.jac

# Test
jac test -v

# Format
jac format . --fix
```

### Production

```bash
# Start locally
jac start -p 8000

# Deploy to Kubernetes
jac start main.jac --scale

# Remove deployment
jac destroy main.jac
```

## See Also

- [Project Configuration](../config/index.md)
- [jac-scale Documentation](../plugins/jac-scale.md)
- [Testing Guide](../testing.md)
