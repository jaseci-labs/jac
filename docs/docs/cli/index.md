# CLI Reference

The Jac CLI provides commands for running, building, testing, and deploying Jac applications.

## Quick Reference

| Command | Description |
|---------|-------------|
| `jac run` | Execute a Jac file |
| `jac serve` | Serve as HTTP API server |
| `jac create` | Create new project |
| `jac build` | Compile to bytecode |
| `jac check` | Type check code |
| `jac test` | Run tests |
| `jac format` | Format code |
| `jac enter` | Run specific entrypoint |
| `jac dot` | Generate graph visualization |
| `jac debug` | Interactive debugger |
| `jac plugins` | Manage plugins |
| `jac scale` | Deploy to Kubernetes (jac-scale) |
| `jac destroy` | Remove deployment |
| `jac add` | Add packages to project |
| `jac install` | Install project dependencies |
| `jac remove` | Remove packages from project |
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

```bash
jac run [-h] [-s SESSION] [-m] [-nm] [-c] [-nc] filename
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to run | Required |
| `-s, --session` | Session name for persistence | None |
| `-m, --main` | Run main entry point | `True` |
| `-c, --cache` | Use cached bytecode | `True` |

**Examples:**

```bash
# Run a file
jac run main.jac

# Run with persistent session
jac run main.jac -s my_session

# Run without cache
jac run main.jac --no-cache
```

---

### jac serve

Serve a Jac application as an HTTP API server.

```bash
jac serve [-h] [-s SESSION] [-p PORT] [-m] [-nm] [-f] [-nf] filename
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to serve | Required |
| `-s, --session` | Session name | None |
| `-p, --port` | Port number | `8000` |
| `-m, --main` | Run main entry point | `True` |
| `-f, --faux` | Faux mode (mock) | `False` |

**Examples:**

```bash
# Serve on default port
jac serve main.jac

# Serve on custom port
jac serve main.jac -p 3000

# Serve with session
jac serve main.jac -s prod_session
```

---

### jac create

Initialize a new Jac project with configuration. Creates a project folder with the given name containing the project files.

```bash
jac create [-h] [-f] [-c] [-s] [-v] [name]
```

| Option | Description | Default |
|--------|-------------|---------|
| `name` | Project name (creates folder with this name) | `main` |
| `-f, --force` | Overwrite existing project | `False` |
| `-c, --cl` | Include client-side setup | `False` |
| `-s, --skip` | Skip package installation | `False` |
| `-v, --verbose` | Verbose output | `False` |

**Examples:**

```bash
# Create basic project (creates myapp/ folder)
jac create myapp
cd myapp

# Create full-stack project with frontend
jac create --cl myapp

# Force overwrite existing
jac create myapp --force
```

---

### jac build

Compile Jac code to bytecode.

```bash
jac build [-h] [-t] [-nt] filename
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to build | Required |
| `-t, --typecheck` | Enable type checking | `False` |

**Examples:**

```bash
# Build without type checking
jac build main.jac

# Build with type checking
jac build main.jac -t
```

---

### jac check

Type check Jac code for errors.

```bash
jac check [-h] [-p] [-np] [-w] [-nw] paths [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to check | Required |
| `-p, --print_errs` | Print errors | `True` |
| `-w, --warnonly` | Warnings only (no errors) | `False` |

**Examples:**

```bash
# Check a file
jac check main.jac

# Check a directory
jac check src/

# Warnings only mode
jac check main.jac -w
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

# Uninstall
jac plugins uninstall byllm
```

---

## Deployment (jac-scale)

### jac scale

Deploy to Kubernetes (requires jac-scale plugin).

```bash
jac scale [-h] [-b] file_path
```

| Option | Description | Default |
|--------|-------------|---------|
| `file_path` | Jac file to deploy | Required |
| `-b, --build` | Build before deploy | `False` |

**Examples:**

```bash
# Deploy
jac scale main.jac

# Build and deploy
jac scale main.jac -b
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
jac add [-h] [-d] [-g GIT] [-c] [-v] [packages ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Package names to add | None |
| `-d, --dev` | Add as dev dependency | `False` |
| `-g, --git` | Git repository URL | None |
| `-c, --cl` | Add as client (frontend) package | `False` |
| `-v, --verbose` | Show detailed output | `False` |

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

# Add client-side (npm) package
jac add react --cl
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
jac remove [-h] [packages ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Package names to remove | None |

**Examples:**

```bash
# Remove a package
jac remove requests

# Remove multiple packages
jac remove numpy pandas
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
# Serve locally
jac serve main.jac -p 8000

# Deploy to Kubernetes
jac scale main.jac

# Remove deployment
jac destroy main.jac
```

## See Also

- [Project Configuration](../configuration/index.md)
- [jac-scale Documentation](../production/index.md)
- [Testing Guide](../testing-debugging/index.md)
