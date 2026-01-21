# **Jac Language Command Line Interface (CLI)**

Jac Language CLI is with a variety of commands to facilitate users. Additionally, Jac language offers users the ability to define custom CLI commands through plugins. This document aims to provide an overview of each command along with clear usage instructions. Jac CLI can ba accessed using bash commands as well as by bashing ```jac``` which will start the Jac CLI.

## `jac tool`

Jac Language offers language tools to perform various tasks efficiently. The `tool` command is utilized to execute specific language tools along with any optional arguments as needed. This command enables users to interact with language-specific command line tools designed to manage the language effectively.

```bash
jac tool <jac_tool> <args>
```

Parameters to execute the tool command:

- `jac_tool`: The name of the language tool to execute.
  - `ir`, `pass_template`, `py_uni_nodes`, `md_doc` are the jac_tools used to handle (Usage instruction is below)
- `args`: Optional arguments for the specific language tool.

> 1.1. jac_tool `ir`:
  `ir` tool generates an Abstract Syntax Tree (AST) and SymbolTable tree for a .jac file, or a Python AST for a .py file. `ir` tool is used with `tool` cli command.

```bash
jac tool ir <output_type> <file_path>
```

*Parameters for `jac tool ir`*

- `output_type`: Choose one of the following options:
- `sym`: Provides the symbol table of the specified .jac file.
- `sym.`: Generates a dot graph representation of the symbol table for the specified .jac file.
- `ast`: Displays the Abstract Syntax Tree (AST) of the specified .jac file.
- `ast.`: Generates a dot graph representation of the AST for the specified .jac file.
- `cfg.`: Genarates a dot graph of the control flow graph(s) for the specified .jac file.
- `pyast`: Generates the Python AST for a .py file or the relevant Python AST for the generated Python code from a .jac file.
- `py`: Displays the relevant generated Python code for the respective Jac code in a .jac file.
- `file_path`: Path to the .jac or .py file.

- To get the symbol table tree of a Jac file:

```bash
jac tool ir sym <file_path>
```

- To generate a dot graph of the symbol table tree for a Jac file:

```bash
jac tool ir sym. <file_path>
```

- To view the AST tree of a Jac file:

```bash
jac tool ir ast <file_path>
```

> jac_tool `pass_template`:
  `pass_template` tool generates pass template for jac.

```bash
jac tool pass_template
```

> jac_tool `py_uni_nodes`:
  `py_uni_nodes` tool lists python ast nodes.

```bash
jac tool py_uni_nodes
```

> jac_tool `md_doc`:
  `md_doc` tool generate mermaid markdown doc.

```bash
jac tool md_doc
```

## `jac run`

The `run` command is utilized to run the specified .jac file.

```bash
jac run <filename> [options]
```

Parameters to execute the run command:

- `filename`: Path of .jac file to run.
- `-s, --session`: Session identifier for persistence. Enables state to persist between runs. Defaults to empty.
- `-m, --main`: Run as main module. Defaults to True.
- `-c, --cache`: Use cached compilation if available. Defaults to True.

Examples:

```bash
# Run a Jac file
jac run app.jac

# Run with a session for persistence
jac run app.jac -s my_session

# Run without caching
jac run app.jac --no-cache
```

## `jac format`

The `format` command is utilized to format the specified .jac file(s) or all .jac files in a given directory.

```bash
jac format <paths...> [--to_screen] [--fix]
```

Parameters to execute the format command:

- `paths`: One or more paths to .jac files or directories containing .jac files.
- `-t, --to_screen`: Print formatted output to screen instead of modifying files. Defaults to False.
- `-f, --fix`: Apply formatting fixes directly to files. Defaults to False.

Examples:

```bash
# Check formatting of all .jac files in current directory (no changes made)
jac format .

# Format and fix all .jac files in current directory
jac format . --fix

# Preview formatted output without modifying files
jac format myfile.jac --to_screen

# Format specific files
jac format file1.jac file2.jac --fix
```

## `jac check`

The `check` command is utilized to run type checker for specified .jac files or directories.

```bash
jac check <paths...> [options]
```

Parameters to execute the check command:

- `paths`: One or more paths to .jac files or directories containing .jac files.
- `-p, --print_errs`: Print errors. Defaults to True.
- `-w, --warnonly`: Treat errors as warnings. Defaults to False.
- `--ignore`: Comma-separated list of files/folders to ignore during checking.

Examples:

```bash
# Check a single file
jac check main.jac

# Check multiple files
jac check file1.jac file2.jac

# Check all files in a directory
jac check myproject/

# Check with warnings only mode
jac check myprogram.jac --warnonly

# Check excluding specific folders/files
jac check myproject/ --ignore fixtures,tests

# Check excluding build artifacts
jac check . --ignore node_modules,dist,__pycache__
```

## `jac build`

The `build` command is utilized to build the specified .jac file.

```bash
jac build <file_path>
```

  Parameters to execute the build command:

- `file_path`: Path of .jac file to build.

## `jac enter`

The `enter` command is utilized to run a specified entrypoint (walker or function) in the given .jac file.

```bash
jac enter <filename> -e <entrypoint> [args...] [options]
```

Parameters to execute the enter command:

- `filename`: The path to the .jac file.
- `-e, --entrypoint`: (Required) The name of the entrypoint walker or function.
- `args`: Additional arguments to pass to the entrypoint.
- `-s, --session`: Session identifier for persistence. Defaults to empty.
- `-m, --main`: Run as main module. Defaults to True.
- `-r, --root`: Root node identifier. Defaults to empty.
- `-n, --node`: Target node identifier. Defaults to empty.

Examples:

```bash
# Run a walker named 'my_walker' in app.jac
jac enter app.jac -e my_walker

# Run with a session for persistence
jac enter app.jac -e my_walker -s my_session

# Pass arguments to the entrypoint
jac enter app.jac -e my_walker -- arg1 arg2
```

## `jac test`

The `test` command is utilized to run the test suite in the specified .jac file.

```bash
jac test <file_path>
```

Parameters to execute the test command:

- `file_path`: The path to the .jac file.

## `jac plugins`

The `plugins` command provides comprehensive plugin management for the Jac runtime. It allows you to list installed plugins, and enable or disable them.

```bash
jac plugins [action] [names...] [--verbose]
```

### Actions

- `list` (default): Show all installed plugins organized by PyPI package
- `disable`: Disable specified plugins (they won't be loaded on startup)
- `enable`: Re-enable previously disabled plugins
- `disabled`: Show currently disabled plugins

### Parameters

- `action`: The action to perform (`list`, `disable`, `enable`, or `disabled`)
- `names`: Plugin or package names to disable/enable
- `--verbose`: Show detailed plugin information including module paths and hooks

### Plugin Naming

Plugins use fully qualified names in the format `package:plugin` for unambiguous identification:

- `jac-scale:JacScaleRuntimeImpl` - A specific plugin from jac-scale
- `jac-client:serve` - A specific plugin from jac-client

### Examples

```bash
# List all installed plugins
jac plugins

# List plugins with detailed information
jac plugins list --verbose

# Disable all plugins from a package
jac plugins disable jac-scale

# Disable a specific plugin using qualified name
jac plugins disable jac-client:serve

# Disable all external plugins
jac plugins disable *

# Enable a previously disabled plugin
jac plugins enable jac-scale

# Show currently disabled plugins
jac plugins disabled
```

### Configuration

Plugin settings are stored in `jac.toml` under the `[plugins]` section:

```toml
[plugins]
disabled = ["jac-scale:JacScaleRuntimeImpl"]
```

You can also use the `JAC_DISABLED_PLUGINS` environment variable for runtime override:

```bash
# Disable all external plugins for this run
JAC_DISABLED_PLUGINS=* jac run myapp.jac

# Disable specific plugins
JAC_DISABLED_PLUGINS=jac-scale:JacScaleRuntimeImpl,jac-client:serve jac run myapp.jac
```

### Wildcard Support

- `*` - Disable all external plugins
- `package:*` - Disable all plugins from a specific package

## `jac config`

The `config` command allows you to view and modify project configuration settings in `jac.toml`.

```bash
jac config [action] [-k KEY] [-v VALUE] [-g GROUP] [-o FORMAT]
```

### Actions

- `show` (default): Display only explicitly set configuration values
- `list`: Display all settings including defaults
- `get`: Get a specific setting value by key
- `set`: Set a configuration value
- `unset`: Remove a configuration value (revert to default)
- `path`: Show the path to the config file
- `groups`: List available configuration groups

### Parameters

- `action`: The action to perform (see above)
- `-k, --key`: Configuration key in dot notation (e.g., `project.name`, `run.cache`)
- `-v, --value`: Value to set (for `set` action)
- `-g, --group`: Filter output by configuration group
- `-o, --output`: Output format (`table`, `json`, or `toml`). Defaults to `table`

### Configuration Groups

The following configuration groups are available:

- `project` - Project metadata (name, version, description, author)
- `run` - Runtime settings (cache, session)
- `build` - Build settings (typecheck, output directory)
- `test` - Test settings (verbose, filters, maxfail)
- `serve` - Server settings (port, host)
- `format` - Formatting options
- `check` - Type checking options
- `dot` - Graph visualization settings
- `cache` - Cache configuration
- `plugins` - Plugin management (disabled plugins list)
- `environment` - Environment variables

### Examples

```bash
# Show explicitly set configuration values
jac config show

# Show all settings including defaults
jac config list

# Filter by configuration group
jac config show -g project

# Get a specific setting
jac config get -k project.name

# Set a configuration value
jac config set -k project.version -v "2.0.0"

# Set a boolean value
jac config set -k run.cache -v false

# Remove a value (revert to default)
jac config unset -k run.cache

# Show config file path
jac config path

# List available configuration groups
jac config groups

# Output as JSON (useful for scripting)
jac config show -o json

# Output as TOML
jac config list -o toml
```

### Use Cases

**Checking current project settings:**

```bash
jac config show
```

**Scripting with JSON output:**

```bash
# Get project name in a script
PROJECT_NAME=$(jac config get -k project.name -o json | jq -r '.value')
```

**Quickly modifying settings:**

```bash
# Enable type checking for builds
jac config set -k build.typecheck -v true

# Disable caching for debugging
jac config set -k run.cache -v false
```

## `jac dot`

The `dot` command generates a DOT graph visualization of your Jac graph data. This is useful for visualizing node relationships and debugging graph structures.

```bash
jac dot <filename> [connection...] [options]
```

Parameters:

- `filename`: Path to the .jac file.
- `connection`: Optional connection strings to filter the graph.
- `-s, --session`: Session identifier for persistence. Defaults to empty.
- `-i, --initial`: Initial node identifier. Defaults to empty.
- `-d, --depth`: Maximum depth to traverse. -1 for unlimited. Defaults to -1.
- `-t, --traverse`: Enable traversal mode. Defaults to False.
- `-b, --bfs`: Use breadth-first search instead of depth-first. Defaults to False.
- `-e, --edge_limit`: Maximum number of edges to include. Defaults to 512.
- `-n, --node_limit`: Maximum number of nodes to include. Defaults to 512.
- `-sa, --saveto`: File path to save the output. Defaults to empty (stdout).
- `-to, --to_screen`: Print output to screen. Defaults to False.
- `-f, --format`: Output format (e.g., 'dot', 'svg', 'png'). Defaults to 'dot'.

Examples:

```bash
# Generate DOT output for a graph
jac dot app.jac

# Save graph visualization to a file
jac dot app.jac --saveto graph.dot

# Limit traversal depth
jac dot app.jac -d 3

# Use BFS traversal
jac dot app.jac --bfs
```

## `jac script`

The `script` command runs predefined scripts from your project's `jac.toml` configuration file.

```bash
jac script <name> [options]
```

Parameters:

- `name`: The name of the script to run (as defined in jac.toml).
- `-l, --list_scripts`: List all available scripts instead of running one.

Scripts are defined in your `jac.toml` file:

```toml
[scripts]
test = "jac test ."
build = "jac build app.jac"
deploy = "jac start --scale app.jac"
```

Examples:

```bash
# List available scripts
jac script --list_scripts

# Run a named script
jac script test

# Run the build script
jac script build
```

## `jac get_object`

The `get_object` command retrieves a specific object by its ID from a running Jac session.

```bash
jac get_object <filename> -i <id> [options]
```

Parameters:

- `filename`: Path to the .jac file.
- `-i, --id`: (Required) The object ID to retrieve.
- `-s, --session`: Session identifier for persistence. Defaults to empty.
- `-m, --main`: Run as main module. Defaults to True.

Examples:

```bash
# Get an object by ID from a session
jac get_object app.jac -i "node_abc123" -s my_session

# Get object from default session
jac get_object app.jac -i "some_object_id"
```

## `jac destroy`

The `destroy` command removes a Kubernetes deployment created by `jac start --scale`. This is part of the jac-scale plugin.

```bash
jac destroy <file_path>
```

Parameters:

- `file_path`: Path to the .jac file that was deployed.

Examples:

```bash
# Remove a scaled deployment
jac destroy app.jac
```

> **Note**: This command requires the jac-scale plugin and an active Kubernetes cluster connection.
