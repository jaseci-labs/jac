# CLI Reference

The `jac` command is your primary interface for working with Jac projects. It handles the full development lifecycle: running programs (`jac run`), type-checking code (`jac check`), running tests (`jac test`), formatting and linting (`jac format`, `jac lint`), managing dependencies (`jac add`, `jac install`), serving APIs (`jac start`), and even compiling to native binaries (`jac nacompile`). Think of it as combining the roles of `python`, `pip`, `pytest`, `black`, and `flask` into a single unified tool.

The CLI is extensible through plugins. When you install a plugin like `jac-scale`, it adds new commands and flags automatically -- for example, `jac start --scale` for Kubernetes deployment. The built-in full-stack client framework (formerly the `jac-client` / `jac-desktop` plugins, now part of `jaclang` core) contributes others, such as `jac build --client desktop` for desktop app packaging.

> **💡 Enhanced Output**: All CLI commands render beautiful, colorful Rich-style output out of the box -- themes, panels, and spinners are built into jaclang by default, with no extra install needed.

## Quick Reference

| Command | Description |
|---------|-------------|
| `jac run` | Execute a Jac file, or (no filename) run the current project by its kind |
| `jac start` | Start REST API server (use `--scale` for K8s deployment) |
| `jac create` | Create new project |
| `jac check` | Type check code |
| `jac test` | Run tests |
| `jac format` | Format code |
| `jac lint` | Lint code (use `--fix` to auto-fix) |
| `jac clean` | Clean project build artifacts |
| `jac purge` | Purge global bytecode cache (works even if corrupted) |
| `jac enter` | Run specific entrypoint |
| `jac dot` | Generate graph visualization |
| `jac debug` | Interactive debugger |
| `jac browse` | Automate a headless browser over CDP (navigate, click, snapshot, screenshot) |
| `jac plugins` | Manage plugins |
| `jac model` | Manage byLLM local-model weights (Gemma 4, Qwen 3.5, …) |
| `jac config` | Manage project configuration |
| `jac destroy` | Remove Kubernetes deployment (jac-scale) |
| `jac status` | Show deployment status of Kubernetes resources (jac-scale) |
| `jac add` | Add packages to project |
| `jac install` | Install project dependencies from `jac.toml`, or `jac install <pkg>` to install packages directly into the activated environment |
| `jac remove` | Remove packages from project |
| `jac update` | Update dependencies to latest compatible versions |
| `jac bundle` | Build a distributable `.whl` from `jac.toml` |
| `jac jacpack` | Manage project templates (.jacpack files) |
| `jac eject` | Compile a project into a runnable FastAPI + JavaScript app (zero `.jac` files) |
| `jac grammar` | Extract and print the Jac grammar |
| `jac guide` | Show curated Jac reference guides |
| `jac script` | Run project scripts |
| `jac py2jac` | Convert Python to Jac |
| `jac jac2py` | Convert Jac to Python |
| `jac tool` | Language tools (IR, AST) |
| `jac lsp` | Language server |
| `jac jac2js` | Convert Jac to JavaScript |
| `jac build` | Build for target platform (jac-client) |
| `jac setup` | Setup build target (jac-client) |
| `jac db` | Inspect persistence DB, manage rescue aliases, recover quarantined data |

---

## Version Info

```bash
jac --version
```

Displays the Jac version, Python version, platform, and all detected plugins with their versions:

```
 _
(_) __ _  ___     Jac Language
| |/ _` |/ __|
| | (_| | (__     Version:  0.11.1
_/ |\__,_|\___|    Python 3.12.3
|__/                Platform: Linux x86_64

🔌 Plugins Detected:
   byllm==0.4.15
   jac-client==0.2.11
   jac-scale==0.2.1
```

---

## Core Commands

### jac run

Execute a Jac file, or (with no filename) run the current project.

**Note:** `jac <file>` is shorthand for `jac run <file>` - both work identically.

```bash
jac run [-h] [-s] [--show] [-m] [--no-main] [-c] [--no-cache] [-e DIAGNOSTICS] [--profile PROFILE] [filename] [args ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to run. Omit to dispatch on the project's `jac.toml` | (project) |
| `-s, --show` | Print the resolved project run-plan (kind, action, equivalent command) without executing | `False` |
| `-m, --main` | Treat module as `__main__` | `True` |
| `-c, --cache` | Enable compilation cache | `True` |
| `-e, --diagnostics` | Diagnostic verbosity: `error`, `all`, or `none` | `error` |
| `--profile` | Configuration profile to load (e.g. prod, staging) | `""` |
| `args` | Arguments passed to the script (available via `sys.argv[1:]`) | |

Like Python, everything after the filename is passed to the script. Jac flags must come **before** the filename.

**Project-aware run (no filename).** Inside a project, a bare `jac run` resolves the project *kind* from `[project] kind` in `jac.toml` (or infers it from the entry-point's codespace) and does the natural action for that kind: **execute** runnable kinds (`cli`, `native-app`), **serve** server kinds (`api-service`, `fullstack`, ...), or **build** artifact kinds (`native-binary`, `shared-library`, `pypi-package`, `npm-package`). Use `jac run --show` to preview the plan and the equivalent primitive command (`run` / `start` / `nacompile` / `bundle`) without running it. See [project kinds](../../quick-guide/project-kinds.md) and [config `[project]`](../config/index.md).

**Diagnostics modes:**

| Mode | Errors | Warnings | Exit code on errors |
|------|--------|----------|---------------------|
| `error` (default) | Shown with full details | Silent | `1` |
| `all` | Shown with full details | Shown | `1` |
| `none` | Silent | Silent | `0` |

The diagnostics level can also be set in `jac.toml` under `[run].diagnostics`. The CLI flag takes precedence over the config file.

**Examples:**

```bash
# Run a file (fails on compile errors by default)
jac run main.jac

# Run the current project per its jac.toml kind (no filename)
jac run

# Preview what the project would run/build, without doing it
jac run --show

# Run without cache (flags before filename)
jac run --no-cache main.jac

# Pass arguments to the script
jac run script.jac arg1 arg2

# Show all diagnostics (errors + warnings)
jac run -e all main.jac

# Suppress all diagnostics
jac run -e none main.jac

# Pass flag-like arguments to the script
jac run script.jac --verbose --output result.txt
```

**Passing arguments to scripts:**

Arguments after the filename are available in the script via `sys.argv`:

```jac
# greet.jac
import sys;

with entry {
    name = sys.argv[1] if len(sys.argv) > 1 else "World";
    print(f"Hello, {name}!");
}
```

```bash
jac run greet.jac Alice        # Hello, Alice!
jac run greet.jac              # Hello, World!
```

`sys.argv[0]` is the script filename (like Python). For scripts that accept
flags, use Python's `argparse` module:

```jac
import argparse;

with entry {
    parser = argparse.ArgumentParser();
    parser.add_argument("--name", default="World");
    args = parser.parse_args();
    print(f"Hello, {args.name}!");
}
```

```bash
jac run greet.jac --name Alice
```

---

### jac start

Start a Jac application as an HTTP API server. With the jac-scale plugin installed, use `--scale` to deploy to Kubernetes. Use `--dev` for Hot Module Replacement (HMR) during development; live-reload is powered by the `watchdog` library bundled in the `jac` binary, so no extra install is needed.

```bash
jac start [-h] [-p PORT] [-m] [--no-main] [-f] [--no-faux] [-d] [--no-dev] [-a API_PORT] [-n] [--no-no_client] [--profile PROFILE] [--client {web,desktop,pwa,mobile}] [--host HOST] [--platform {auto,android,ios}] [--scale] [--no-scale] [-b] [--no-build] [filename]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to serve | `main.jac` |
| `-p, --port` | Port number | `8000` |
| `-m, --main` | Treat as `__main__` | `True` |
| `-f, --faux` | Print docs only (no server) | `False` |
| `-d, --dev` | Enable HMR (Hot Module Replacement) mode | `False` |
| `--api_port` | Separate API port for HMR mode (0=same as port) | `0` |
| `--no_client` | Skip client bundling/serving (API only) | `False` |
| `--profile` | Configuration profile to load (e.g. prod, staging) | `""` |
| `--client` | Client build target (`web`, `desktop`, `pwa`, `mobile`) | None |
| `--host` | Mobile dev (`--client mobile --dev`) optional live-reload host/IP override | `""` |
| `--platform` | Mobile start/dev platform selector for `--client mobile` (`auto`, `android`, `ios`) | `auto` |
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
jac start --dev --no_client

# Mobile dev (Android default)
jac start main.jac --client mobile --dev

# Mobile dev on iOS simulator
jac start main.jac --client mobile --dev --platform ios

# Mobile dev with explicit host override
jac start main.jac --client mobile --dev --host 192.168.1.25

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

Initialize a new Jac project with configuration. Creates a project folder with the given name containing the project files, including an `AGENTS.md` that points AI coding agents at `jac guide`.

`jac create` is kind-aware: `--kind <kind>` scaffolds a project for a specific project kind, stamping `[project] kind` into `jac.toml` so the new project's bare `jac run` dispatches correctly (see `jac run`). All built-in kinds ship with `jaclang` -- including `fullstack`, `wasm`, `mobile`, and `desktop`, which previously required the separate `jac-client` / `jac-desktop` plugins and now need no extra install.

```bash
jac create [-h] [-f] [-k KIND] [-u USE] [-l] [name]
```

| Option | Description | Default |
|--------|-------------|---------|
| `name` | Project name (creates folder with this name) | Current directory name |
| `-f, --force` | Overwrite existing project | `False` |
| `-k, --kind` | Project kind: cli, native-app, native-binary, shared-library, api-service, microservices, pypi-package, npm-package, fullstack, wasm, desktop, mobile | `cli` |
| `-u, --use` | Custom template: file path or URL to a `.jacpack`, or a named variant (e.g. `jac-shadcn`) | `default` |
| `-l, --list_jacpacks` | List available project kinds and named variants | `False` |

`--kind` and `--use` are mutually exclusive.

**Examples:**

```bash
# Create a basic cli project (creates myapp/ folder)
jac create myapp
cd myapp

# Scaffold a headless API service
jac create myapp --kind api-service

# Scaffold a natively-compiled binary
jac create myapp --kind native-binary

# Scaffold a full-stack app (built into jaclang core)
jac create myapp --kind fullstack

# Scaffold a shadcn-themed fullstack app
jac create myapp --use jac-shadcn

# Create from a local .jacpack file / directory / URL
jac create myapp --use ./my-template.jacpack
jac create myapp --use ./my-template/
jac create myapp --use https://example.com/template.jacpack

# List available project kinds and named variants
jac create --list_jacpacks

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
jac check [-h] [-e] [-i [IGNORE ...]] [-p] [--nowarn] paths [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to check | Required |
| `-e, --print_errs` | Print detailed error messages | `True` |
| `-i, --ignore` | Space-separated list of files/folders to ignore | None |
| `-p, --parse_only` | Only check syntax (skip type checking) | `False` |
| `--nowarn` | Suppress warning output | `False` |

**Examples:**

```bash
# Check a file
jac check main.jac

# Check a directory
jac check src/

# Check directory excluding specific folders/files
jac check myproject/ --ignore fixtures tests

# Check excluding multiple patterns
jac check . --ignore node_modules dist __pycache__
```

Errors and warnings are displayed with structured diagnostic codes (e.g., `E1030`, `W2001`). You can suppress individual diagnostics inline with `# jac:ignore[CODE]`:

<!-- jac-skip -->
```jac
x = some_func();  # jac:ignore[E1030]
```

See the full [Errors & Warnings](../diagnostics.md) reference for all diagnostic codes.

---

### jac test

Run tests in Jac files.

> **Note:** `jac test` runs through pytest bundled in the `jac` binary -- there is no separate `pytest` install needed.

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

# Run a specific test - spaces in name (quoted)
jac test main.jac -t "my test name"

# Run a specific test - underscores in name
jac test main.jac -t my_test_name

# Run tests in directory
jac test -d tests/

# Run all tests in current directory
jac test

# Stop on first failure
jac test main.jac -x

# Verbose output
jac test main.jac -v
```

**Error handling:**

| Mistake | Error shown |
|---------|-------------|
| `jac test --test_name foo` (no file or directory) | `--test_name requires a filepath` |
| `jac test missing.jac` (file doesn't exist) | `File not found: 'missing.jac'` |
| `jac test main.jac -t foo bar` (unquoted multi-word) | hint to use quotes |

---

### jac format

Format Jac code according to style guidelines. For auto-linting (code corrections like combining consecutive `has` statements, converting `@staticmethod` to `static`), use `jac lint --fix` instead.

```bash
jac format [-h] [-s] [-l] [-c] paths [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to format | Required |
| `-s, --to_screen` | Print to stdout instead of writing | `False` |
| `-l, --lintfix` | Also apply auto-lint fixes in the same pass | `False` |
| `-c, --check` | Check if files are formatted without modifying them (exit 1 if unformatted) | `False` |

**Examples:**

```bash
# Preview formatting
jac format main.jac -s

# Apply formatting
jac format main.jac

# Format entire directory
jac format .

# Check formatting without modifying (useful in CI)
jac format . --check
```

> **Note**: For auto-linting (code corrections), use `jac lint --fix` instead. See [`jac lint`](#jac-lint) below.
>
> **Safety**: If the formatter detects that comments were displaced (e.g., moved to the end of the file), it emits error `E5051` and refuses to save the file. Run `jac format <file> -s` to inspect the output without writing.

---

### jac lint

Lint Jac files and report violations. Use `--fix` to auto-fix violations.

```bash
jac lint [-h] [-f] [--ignore IGNORE] paths [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to lint | Required |
| `-f, --fix` | Auto-fix lint violations | `False` |
| `--ignore` | Comma-separated files/folders to ignore | `""` |

**Examples:**

```bash
# Report lint violations
jac lint main.jac

# Auto-fix violations
jac lint main.jac --fix

# Lint entire directory
jac lint .

# Lint excluding folders
jac lint . --ignore fixtures
```

> **Lint Rules**: Configure rules via [`[check.lint]`](../config/index.md#checklint) in `jac.toml`. See [Lint Rules](../diagnostics.md#lint-rules-w3xxx--e3xxx) for the full list with diagnostic codes.

---

### jac enter

Run a specific entrypoint in a Jac file.

```bash
jac enter [-h] [-m] [-r ROOT] [-n NODE] filename entrypoint [args ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file | Required |
| `entrypoint` | Function/walker to invoke (positional) | Required |
| `args` | Arguments to pass | None |
| `-m, --main` | Treat as `__main__` | `True` |
| `-r, --root` | Root executor ID | None |
| `-n, --node` | Starting node ID | None |

**Examples:**

```bash
# Run specific entrypoint
jac enter main.jac my_walker

# With arguments
jac enter main.jac process_data arg1 arg2

# With root and node
jac enter main.jac my_walker -r root_id -n node_id
```

---

## Visualization & Debug

### jac dot

Generate DOT graph visualization.

```bash
jac dot [-h] [-s SESSION] [-i INITIAL] [-d DEPTH] [-t] [-b] [-e EDGE_LIMIT] [-n NODE_LIMIT] [-o SAVETO] [-p] [-f FORMAT] filename [connection ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file | Required |
| `-s, --session` | Session identifier | None |
| `-i, --initial` | Initial node ID | None |
| `-d, --depth` | Max traversal depth | `-1` (unlimited) |
| `-t, --traverse` | Enable traversal mode | `False` |
| `-c, --connection` | Connection filters | None |
| `-b, --bfs` | Use BFS traversal | `False` |
| `-e, --edge_limit` | Max edges | `512` |
| `-n, --node_limit` | Max nodes | `512` |
| `-o, --saveto` | Output file path | None |
| `-p, --to_screen` | Print to stdout | `False` |
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

#### VS Code Debugger Setup

To use the VS Code debugger with Jac:

1. Install the **Jac** extension from the VS Code Extensions marketplace
2. Enable **Debug: Allow Breakpoints Everywhere** in VS Code Settings (search "breakpoints")
3. Create a `launch.json` via Run and Debug panel (Ctrl+Shift+D) → "Create a launch.json file" → select "Jac Debug"

The generated `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "jac",
            "request": "launch",
            "name": "Jac Debug",
            "program": "${file}"
        }
    ]
}
```

Debugger controls: F5 (continue), F10 (step over), F11 (step into), Shift+F11 (step out).

#### Graph Visualization (`jacvis`)

The Jac extension includes live graph visualization:

1. Open VS Code Command Palette (Ctrl+Shift+P / Cmd+Shift+P)
2. Type `jacvis` and select **jacvis: Visualize Jaclang Graph**
3. A side panel opens showing your graph structure

Set breakpoints and step through code -- nodes and edges appear in real time as your program builds the graph. Open `jacvis` **before** starting the debugger for best results.

For a complete walkthrough, see the [Debugging in VS Code Tutorial](../../tutorials/language/debugging.md).

---

## Browser Automation

### jac browse

Drive a headless Chrome/Chromium over the Chrome DevTools Protocol (CDP): navigate, interact with elements, inspect the page, and capture screenshots. The driver is zero-dependency -- it speaks CDP over a hand-rolled WebSocket, so no Playwright or Selenium install is required. Interactions use real CDP input events (trusted clicks and keystrokes), not JavaScript injection.

```bash
jac browse <action> [args ...] [-s SESSION] [--viewport WxH]
```

| Option | Description | Default |
|--------|-------------|---------|
| `action` | The action to perform (see table below) | Required |
| `args` | Action-specific arguments (selector, url, text, path, ...) | `[]` |
| `-s, --session` | Session name; each session is an isolated browser instance | `default` |
| `--viewport` | Browser window size as `WIDTHxHEIGHT` (applied at `open`) | `1280x720` |

**Actions:**

| Action | Arguments | Description |
|--------|-----------|-------------|
| `open` | `[url]` | Launch a headless browser, optionally navigating to a URL |
| `navigate` / `goto` | `<url>` | Navigate to a URL (adds `https://` if no scheme; waits for load) |
| `click` | `<selector\|@ref>` | Real mouse click at the element center |
| `type` | `<selector> <text>` | Focus an element and type text as per-character key events |
| `fill` | `<selector> <text>` | Clear a field and insert text in one step |
| `press` | `<key>` | Press a named key or character (`Enter`, `Tab`, `Ctrl+A`, ...) |
| `get` | `url\|title\|text [selector]` | Read a page property (`get text` needs a selector) |
| `eval` | `<expression>` | Run JavaScript and return the result as JSON |
| `wait` | `<ms\|selector>` | Sleep for a duration, or wait until a selector is actionable |
| `scroll` | `<up\|down\|left\|right\|top\|bottom\|selector> [px]` | Scroll the page, or scroll an element into view |
| `console` | `[--clear]` | Print buffered console/log/exception output since page load |
| `snapshot` | | Print the accessibility tree with `@e1`/`@e2` refs on interactive nodes |
| `screenshot` | `[path]` | Capture the page as PNG (defaults to the cache directory) |
| `state` | `save\|load <path>` | Save or restore cookies + localStorage as JSON |
| `sessions` | | List known sessions with their PID, port, and liveness |
| `close` | | Terminate the browser and clear session state |

Outputs are printed raw so they pipe cleanly; JSON-valued results (`eval`, `get`) are serialized. Errors go to stderr and return exit code `1`.

**Sessions and persistence:**

A launched browser stays alive between CLI calls -- each invocation reconnects to the running Chrome recorded under `~/.cache/jacbrowser/`. Use `-s` to run multiple isolated browsers side by side. Element refs from `snapshot` (the `@e1` handles) persist across calls, so you can snapshot once and act on refs in later commands.

**Refs vs. selectors:**

`click`, `type`, and `fill` accept either a CSS selector (`#email`, `button.primary`) or an `@ref` produced by `snapshot`. Both auto-wait until the element is actionable: it is scrolled into view and must be visible, position-stable, inside the viewport, and the top element at the click point. If any of those cannot be satisfied (e.g. the point lands offscreen or another element covers the target), the command fails with an error instead of silently doing nothing.

**Environment variables:**

| Variable | Description |
|----------|-------------|
| `JACBROWSER_SESSION` | Default session name (overridden by `-s`) |
| `JACBROWSER_CHROME` | Path to the Chrome/Chromium binary |
| `JACBROWSER_CACHE` | Cache directory for session, ref, and screenshot files |

**Examples:**

```bash
# Launch a browser and open a page
jac browse open example.com

# Read page properties
jac browse get title
jac browse get text 'h1'

# Inspect the accessibility tree -> assigns @e1, @e2, ... to interactive nodes
jac browse snapshot
#   @e1 link "Home"
#   @e5 button "Send Message"

# Interact by ref (from snapshot) or by CSS selector
jac browse click @e5
jac browse fill '#email' you@example.com
jac browse press Enter

# Run JavaScript
jac browse eval "document.querySelectorAll('a').length"

# Wait for an app to mount, then read its console output
jac browse wait '#app'
jac browse console
#   [log] booted in 312ms
#   [warning] Each child in a list should have a unique "key" prop.

# Scroll for screenshot framing
jac browse scroll down
jac browse scroll '#pricing'

# Capture a screenshot
jac browse screenshot ./page.png

# Save and restore an authenticated session
jac browse state save auth.json
jac browse state load auth.json

# Work in an isolated session
jac browse -s work open example.com
jac browse sessions
#   * work     pid=12345 port=9222 [alive]

# Close the browser
jac browse close
```

A typical end-to-end flow chains these together:

```bash
jac browse open example.com
jac browse snapshot                 # find the @ref of the field and button
jac browse fill @e3 "hello"
jac browse click @e5
jac browse screenshot result.png
jac browse close
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
| `info` | Show plugin information |
| `enable` | Enable plugins |
| `disable` | Disable plugins |
| `disabled` | List disabled plugins |

| Option | Description | Default |
|--------|-------------|---------|
| `-v, --verbose` | Verbose output | `False` |

**Examples:**

```bash
# List plugins (action defaults to 'list')
jac plugins

# Explicitly list plugins
jac plugins list

# Show info about a plugin
jac plugins info byllm

# Disable a plugin
jac plugins disable byllm

# Enable a plugin
jac plugins enable byllm

# List disabled plugins
jac plugins disabled
```

> **Note:** To install or remove plugins, use `jac install <plugin>` / `jac remove <plugin>`. The `jac plugins` command manages enabled/disabled state for already-installed plugins.
>
> **💡 Popular Plugins**:
>
> - **jac-scale**: Kubernetes deployment and scaling (`jac install jac-scale`)
>
> (Full-stack web and native-desktop app building ships with `jaclang` core -- no plugin install needed.)

---

## Local Model Cache

The `jac model` command manages the on-disk cache of bundled local LLM weights used by byLLM's `local:<alias>` route. Weights live under `~/.cache/jac/models/<alias>/` (override with `JAC_MODELS_DIR`). See [Built-in Local Models](../plugins/byllm.md#built-in-local-models) in the byLLM reference for the full backend.

### jac model

Manage byLLM local-model weights (Gemma 4, Qwen 3.5, …).

```bash
jac model [-h] [action] [alias]
```

| Action | Description |
|--------|-------------|
| `list` | Show bundled aliases and download status (default). |
| `pull <alias>` | Download GGUF weights for an alias from HuggingFace. |
| `rm <alias>` | Delete cached weights for an alias. Aliases: `remove`, `delete`. |

| Argument | Description | Default |
|----------|-------------|---------|
| `action` | One of `list`, `pull`, `rm`. | `list` |
| `alias` | Local-model alias (e.g. `gemma-4-e4b`). Required for `pull` / `rm`; omit for `list`. | `""` |

**Examples:**

```bash
# Show bundled aliases and which are cached locally
jac model

# Download Gemma 4 E4B weights (~5 GB) ahead of first use
jac model pull gemma-4-e4b

# Free disk by removing cached weights
jac model rm gemma-4-e4b
```

**Sample output of `jac model`:**

```text
Local model cache: /home/you/.cache/jac/models

  ALIAS                       SIZE STATUS       DESCRIPTION
  ---------------------- --------- ------------ ----------------------------------------
  gemma-4-e2b             ~2500 MB not cached   Google Gemma 4 E2B (smaller, faster)
  gemma-4-e4b               4.6 GB downloaded   Google Gemma 4 E4B (instruction-tuned, Q4_K_M)
  qwen3.5-4b              ~2800 MB not cached   Alibaba Qwen 3.5 4B (instruction-tuned, Q4_K_M)
```

> **Note:** In CI and other non-TTY contexts, the runtime will not prompt to download. Either `jac model pull <alias>` ahead of time, or set `BYLLM_AUTO_DOWNLOAD=1` (or `[plugins.byllm.local].auto_download = true` in `jac.toml`) to allow silent first-run downloads.

---

## Database Operations

The `jac db` command group inspects the live persistence backend, manages DB-resident rescue aliases, and recovers quarantined anchors. It works against any `PersistentMemory` backend -- `SqliteMemory` (default), `MongoBackend` (with `jac-scale`), or any plugin-provided backend that implements the interface -- through the same set of subcommands.

For the architectural background (fingerprints, drift detection, quarantine philosophy, alias decorator), see [Persistence & Schema Migration](../persistence.md).

### Backend dispatch

`jac db` always operates on the backend the user's app is configured to use:

- Pass `--app PATH` to point at the entry `.jac` file.
- Or run the command from the app's directory; if there's exactly one `.jac` in the current directory, it's picked automatically.

The command imports the user's app to set up the runtime context, then talks to whatever `PersistentMemory` backend the configuration installs -- SQLite locally, Mongo in production, etc. There is no separate mode for each backend.

```bash
# Explicit
jac db inspect --app path/to/app.jac

# Implicit when there's one .jac in cwd
cd my_app/
jac db inspect
```

### jac db inspect

Print a one-line summary of the live persistence backend plus per-archetype count tables for both anchors and quarantine.

```bash
jac db inspect
```

**Output:**

```
Jac DB: /tmp/myapp/.jac/data/anchor_store.db
[INFO] format_version=1   anchors=5   quarantined=0   aliases=0
        Anchors
┏━━━━━━━━━━━━━┳━━━━━━━┓
┃ arch_type   ┃ count ┃
┡━━━━━━━━━━━━━╇━━━━━━━┩
│ Person      │ 2     │
│ GenericEdge │ 2     │
│ Root        │ 1     │
└─────────────┴───────┘
```

The summary line covers: storage format version, total live anchor count, total quarantined count, and total alias count. Quarantine + Anchors tables only print when non-empty.

### jac db quarantine list

List the most recent quarantined anchors with their class, fingerprint, error, and timestamp.

```bash
jac db quarantine list           # default limit: 50
jac db quarantine list -n 200    # raise limit
```

Sorted newest first. UUID columns are truncated to a recognizable prefix; pass any unique prefix to `quarantine show` or `recover`.

### jac db quarantine show \<id-prefix\>

Dump one quarantined row in full (parsed JSON), including the original `data` payload -- useful for understanding why a row failed to load.

```bash
jac db quarantine show 86092d34
```

A unique prefix is sufficient. If the prefix is ambiguous, the command tells you and asks for a longer prefix.

### jac db alias add / list / remove

DB-resident rescue aliases. Persisted in an `aliases` table (SQLite) or `<collection>_aliases` companion collection (Mongo, e.g. `_anchors_aliases`) and merged into the in-process `Serializer._aliases` map at backend connect time. Survives across process restarts; affects every consumer of that database.

```bash
# List current aliases.
jac db alias list

# Register a rescue alias for a class rename / module move.
jac db alias add "old.module.LegacyName" "new.module.NewName"

# Remove one.
jac db alias remove "old.module.LegacyName"
```

Both arguments to `alias add` are fully-qualified `module.ClassName` strings -- the `module` part is what would have appeared in the stored row's `arch_module` field. For files imported via `jac enter app.jac`, the module is `__main__`.

> **When to use this vs. the decorator.** The [`@archetype_alias`](../persistence.md#class-renames-the-alias-decorator) decorator is the normal path: it's code-resident, travels through git, applies wherever the code runs. `jac db alias add` is the rescue path: emergency recovery in production without a code deploy. Decorator first, CLI as the safety net.

### jac db recover \<id-prefix\>

Re-attempt deserialization on one quarantined row. On success, the row is moved back to the live anchors collection and **re-stamped with the live class's identity + fingerprint** so subsequent reads bypass alias resolution and drift detection.

```bash
jac db recover 86092d34 --app app.jac
```

Recovery only succeeds when the user's archetype classes (and any `@archetype_alias` decorators) are registered, so the user app must be discoverable -- via `--app PATH` or the cwd auto-discovery described above. Without it, every quarantined row will be reported as `class X.Y still unresolvable`.

### jac db recover-all

Batch variant. Re-attempts every quarantined row and reports counts, plus a per-row reason for whatever still can't be recovered.

```bash
jac db recover-all --app app.jac
```

Typical output:

```
✔ Recovered 2 of 2 quarantined rows.
```

Or, when some rows are still stuck (often because the class involved isn't covered by any alias yet):

```
✔ Recovered 3 of 5 quarantined rows.
[WARN] 2 rows still quarantined.
                Still quarantined
┏━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ id        ┃ reason                                          ┃
┡━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ d44e2c7a… │ class oldmod.GoneAway still unresolvable       │
│ 902b14ee… │ deserialize raised: ValueError: bad enum value │
└───────────┴─────────────────────────────────────────────────┘
```

### jac db fsck

Scan the backend for referential-integrity violations: **dangling references** (a node citing an edge document that no longer exists, or an edge citing a missing endpoint node) and **orphans** (an unreferenced edge, or an edgeless non-root node). Read-only by default, so it is safe to run as a monitoring probe.

```bash
jac db fsck --app app.jac
```

**Output:**

```
Jac DB fsck: /tmp/myapp/.jac/data/app.db
[INFO] dangling refs : 19   (8 document(s) cite a missing referent)
[INFO] orphan edges  : 3
[INFO] orphan nodes  : 11
[INFO] Run `jac db fsck repair` to heal danglers and collect orphans.
```

Pass `repair` to act on the findings. Dangling citations are pruned and each missing referent is filed into the quarantine store under the `DANGLING_REF` reason code (visible via `jac db quarantine list`); orphans are collected. On SQLite the whole repair runs inside one `BEGIN IMMEDIATE` transaction, so a `fsck repair` is itself crash-atomic.

```bash
jac db fsck repair --app app.jac
```

**Output:**

```
✔ repaired: pruned 19 citation(s), quarantined 19 dangler(s) under DANGLING_REF, collected 14 orphan(s).
```

A clean database reports nothing to do:

```
✔ Clean: no referential-integrity violations.
```

> Most danglers are healed automatically the first time a traversal touches them (see [Persistence → Dangling references](../persistence.md#dangling-references-and-read-path-healing)). `jac db fsck` is the offline backstop: it heals references no live request has hit yet, and surfaces orphan garbage for collection.

### jac db schema rules

List every registered [`__jac_schema__` drift rule](../persistence.md#declared-drift-rules-__jac_schema__) along with the active `JAC_SCHEMA_REPAIR` mode. The app is imported first (same `--app` / cwd discovery as the other subcommands), which is what runs the `__jac_schema__` hooks and registers the rules.

```bash
jac db schema rules --app app.jac
```

**Output:**

```
Registered schema drift rules
[INFO] JAC_SCHEMA_REPAIR mode: repair
                    Rules
┏━━━━━━━━━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━┓
┃ archetype       ┃ rule    ┃ detail                ┃
┡━━━━━━━━━━━━━━━━━╇━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━┩
│ __main__.User   │ was     │ myapp.models.OldUser  │
│ __main__.User   │ alias   │ username -> name      │
│ __main__.User   │ drop    │ legacy_bio            │
│ __main__.User   │ upgrade │ split_tags            │
└─────────────────┴─────────┴───────────────────────┘
```

Useful as a pre-deploy sanity check: it confirms which renames, drops, and upgrade callbacks will apply when old documents load, and which repair mode the process will run under.

### Typical rescue workflow

```bash
# 1. Discover what's quarantined.
jac db inspect --app app.jac
jac db quarantine list --app app.jac

# 2. Drill into one row to understand why.
jac db quarantine show <prefix> --app app.jac

# 3. If it's a class rename: register an alias.
jac db alias add "__main__.OldName" "__main__.NewName"

# 4. Re-attempt every stuck row.
jac db recover-all --app app.jac

# 5. Confirm.
jac db inspect --app app.jac
```

After step 5 the quarantine count should be zero (or list only rows that genuinely need a different fix -- type changes too aggressive for the coercion table, etc.).

---

## Configuration Management

### jac config

View and modify project configuration settings in `jac.toml`.

```bash
jac config [action] [key] [value] [-g GROUP] [-o FORMAT]
```

| Action | Description |
|--------|-------------|
| `show` | Display explicitly set configuration values (default) |
| `list` | Display all settings including defaults |
| `get` | Get a specific setting value |
| `set` | Set a configuration value |
| `unset` | Remove a configuration value (revert to default) |
| `path` | Show path to config file |
| `groups` | List available configuration groups |

| Option | Description | Default |
|--------|-------------|---------|
| `key` | Configuration key (positional, e.g., `project.name`) | None |
| `value` | Value to set (positional) | None |
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
jac config get project.name

# Set a value
jac config set project.version "2.0.0"

# Remove a value (revert to default)
jac config unset run.cache

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

### jac status

Show the deployment status of your Jac application on Kubernetes. Displays a color-coded table with the health of each component (application, Redis, MongoDB, Prometheus, Grafana), pod readiness counts, and service URLs.

```bash
jac status [-h] file_path [--target TARGET]
```

| Option | Description | Default |
|--------|-------------|---------|
| `file_path` | Path to the `.jac` file | Required |
| `--target` | Deployment target platform | `kubernetes` |

**Example output:**

```
  Jac Scale - Deployment Status
  App: my-app   Namespace: default

┌───────────────────┬────────────────────────┬───────┐
│ Component         │ Status                 │ Pods  │
├───────────────────┼────────────────────────┼───────┤
│ Jaseci App        │ ● Running              │  1/1  │
│ Redis             │ ● Running              │  1/1  │
│ MongoDB           │ ● Running              │  1/1  │
│ Prometheus        │ ● Running              │  1/1  │
│ Grafana           │ ● Running              │  1/1  │
└───────────────────┴────────────────────────┴───────┘

  Service URLs
  ────────────────────────────────────────────
  Application:  http://localhost:30001
  Grafana:      http://localhost:30003
```

**Status indicators:**

| Symbol | Meaning |
|--------|---------|
| `● Running` | All pods healthy and ready |
| `◑ Degraded` | Some pods ready, but not all |
| `⟳ Pending` | Pods are starting up |
| `↺ Restarting` | Pods are crash-looping |
| `✗ Failed` | Component has failed |
| `○ Not Deployed` | Component is not present in the cluster |

**Examples:**

```bash
# Check deployment status
jac status app.jac

# Check status with explicit target
jac status app.jac --target kubernetes
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

Add packages to your project's dependencies. Requires at least one package argument (use `jac install` to install all existing dependencies). When no version is specified, the package is installed unconstrained and then the installed version is queried to record a `~=X.Y` compatible-release spec in `jac.toml`.

```bash
jac add [-h] [-d] [-g GIT] [-v] [packages ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Package specifications (required) | None |
| `-d, --dev` | Add as dev dependency | `False` |
| `-g, --git` | Git repository URL | None |
| `-v, --verbose` | Show detailed output | `False` |

**With the built-in client framework:**

| Option | Description | Default |
|--------|-------------|---------|
| `--npm` | Add as client-side (npm) package | `False` |

**Examples:**

```bash
# Add a package (records ~=2.32 based on installed version)
jac add requests

# Add with explicit version constraint
jac add "numpy>=1.24"

# Add multiple packages
jac add numpy pandas scipy

# Add as dev dependency
jac add pytest --dev

# Add from git repository
jac add --git https://github.com/user/package.git

# Add npm package (client framework built into jaclang core)
jac add react --npm
```

For private packages from custom registries (e.g., GitHub Packages), configure scoped registries and auth tokens in `jac.toml` under `[plugins.client.npm]`. See [NPM Registry Configuration](../plugins/jac-client.md#npm-registry-configuration).

---

### jac install

`jac install` has two modes depending on whether package names are passed:

**No-argument mode** - sync the project environment to `jac.toml`. Installs all Python (pip), git, and plugin-provided (npm, etc.) dependencies in one command. Creates or validates the project virtual environment at `.jac/venv/`. Requires a `jac.toml` in the current (or a parent) directory.

**Package mode** - `jac install <pkg> [pkg ...]` installs one or more packages directly into the **active project environment** (managed by the `jac` binary, which provides the jaclang runtime), without reading or modifying `jac.toml`. It is the Jac-native equivalent of `pip install <pkg>`: under the hood it wraps pip (or `uv pip`), but the target is the project's `jac`-managed environment rather than a user-managed system Python. Useful for quick one-off installs or scripts where you do not need a full jac project.

> **`jac install <pkg>` vs `jac add <pkg>`**
>
> | | `jac install <pkg>` | `jac add <pkg>` |
> |---|---|---|
> | Target | Active `jac`-managed environment | Project `.jac/venv/` |
> | Updates `jac.toml` | No | Yes |
> | Works outside a project | Yes | No |
>
> Use `jac add` when you want the dependency tracked for reproducible installs. Use `jac install <pkg>` for ad-hoc or environment-level installs.

```bash
jac install [-h] [packages ...] [-e PATH] [-d] [-x group [group ...]] [-v]
            [--force-reinstall] [--no-cache-dir] [--pre] [--dry-run]
            [--no-deps] [--quiet] [--prefer-binary] [--no-uv]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Package(s) to install into the activated environment. When provided, skips `jac.toml` entirely. | `[]` |
| `-e, --editable PATH` | Install the Jac package at `PATH` in editable mode (analogous to `pip install -e`). `jac.toml` is read from `PATH`, not the current directory. Cannot be combined with `packages`. Repeatable. | `None` |
| `-d, --dev` | Include dev dependencies (no-arg mode only) | `False` |
| `-x, --extras` | Install one or more `[optional-dependencies]` groups (no-arg mode only) | `[]` |
| `-v, --verbose` | Show detailed output | `False` |
| `--force-reinstall` | Reinstall all packages even if they are already up-to-date | `False` |
| `--no-cache-dir` | Disable the pip download cache | `False` |
| `--pre` | Include pre-release and development versions | `False` |
| `--dry-run` | Show what would be installed without actually installing anything | `False` |
| `--no-deps` | Don't install package dependencies | `False` |
| `--quiet` | Suppress pip output | `False` |
| `--prefer-binary` | Prefer pre-built wheels over source distributions | `False` |
| `--no-uv` | Use pip directly, even if `uv` is available on `PATH` | `False` |

**Examples:**

```bash
# Install a single package into the activated environment
jac install numpy

# Install multiple packages at once
jac install numpy pandas scipy

# Install with version constraints
jac install "requests>=2.28" "pydantic>=2.0"

# Install all dependencies from jac.toml (no-arg mode)
jac install

# Install including dev dependencies (no-arg mode)
jac install --dev

# Install optional dependency groups defined in jac.toml (no-arg mode)
jac install --extras data monitoring

# Editable install of the current package (no-arg mode)
jac install -e .

# Editable install from anywhere (no need to cd into the package)
jac install -e /path/to/lib

# Editable install with all optional dependency groups
jac install -e . --extras all

# Install with verbose output
jac install -v

# Reinstall all packages from scratch (ignores cached state)
jac install --force-reinstall

# Preview what would be installed without doing it
jac install --dry-run

# Install without using pip's download cache
jac install --no-cache-dir

# Force pip (skip uv) for this install
jac install --no-uv
```

Optional groups are declared under `[optional-dependencies]` in `jac.toml`. See the [Configuration Reference](../config/index.md#optional-dependencies).

> **uv backend:** When [`uv`](https://github.com/astral-sh/uv) is installed and on `PATH`, `jac install` (and `jac add`, `jac remove`, `jac update`) automatically route pip operations through `uv pip` for significantly faster dependency resolution and downloads. No configuration needed - it activates on detection.
>
> To opt out for a single `jac install` run: `jac install --no-uv`
>
> To opt out system-wide (all commands, all sessions): `export JAC_NO_UV=1`
>
> The `--prefer-binary` flag has no `uv` equivalent and is silently dropped when uv is active. Pass `--no-uv` to preserve it.
>
> **Note:** The pip passthrough flags (`--force-reinstall`, `--no-cache-dir`, `--pre`, `--no-deps`, `--quiet`, `--prefer-binary`) are forwarded directly to pip in both modes. Use `jac update` to upgrade packages to their latest versions.

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

**With the built-in client framework:**

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

# Remove npm package (client framework built into jaclang core)
jac remove react --npm
```

---

### jac update

Update dependencies to their latest compatible versions. For each updated package, the installed version is queried and a `~=X.Y` compatible-release spec is written back to `jac.toml`.

```bash
jac update [-h] [-d] [-v] [packages ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Specific packages to update (all if empty) | None |
| `-d, --dev` | Include dev dependencies | `False` |
| `-v, --verbose` | Show detailed output | `False` |

**Examples:**

```bash
# Update all dependencies to latest compatible versions
jac update

# Update a specific package
jac update requests

# Update all including dev dependencies
jac update --dev
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
| `-p, --packages` | Clean virtual environment (`.jac/venv`) | `False` |
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

> **💡 Troubleshooting Tip:** If you encounter unexpected syntax errors, "NodeAnchor is not a valid reference" errors, or other strange behavior after modifying your code, try clearing the cache with `jac clean --cache` (`rm -rf .jac`) or `jac purge`. Stale bytecode can cause issues when source files change.

---

### jac purge

Purge the global bytecode cache. Works even when the cache is corrupted.

```bash
jac purge
```

**When to use:**

- After upgrading Jaseci packages
- When encountering cache-related errors (`jaclang.pycore`, `NodeAnchor`, etc.)
- When setup stalls during first-time compilation

| Command | Scope |
|---------|-------|
| `jac clean --cache` | Local project (`.jac/cache/`) |
| `jac purge` | Global system cache |

---

### jac bundle

Build a standards-compliant Python wheel (`.whl`) from your project's `jac.toml`. The wheel is `pip install`-ready and requires no `pyproject.toml` or `setuptools`. It is consumed under the `jac` binary (which provides the jaclang runtime), so the wheel neither bundles nor declares `jaclang` as a dependency. After building, upload to PyPI (or a private registry) with `twine upload dist/*`. For the full end-to-end workflow, see the [Publishing Packages](../publishing.md) guide.

```bash
jac bundle [-h] [-o OUTPUT] [-p]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-o, --output` | Directory to write the `.whl` file | `dist` |
| `-p, --precompile` | Compile `.jac` → `.jir` bytecode for every `python3.X` found on `PATH` before packaging | off |

**What it does:**

1. Reads `[project]` from `jac.toml` and validates required fields (`name`, `version`).
2. Discovers source files under the package directory (defaults to the directory named after the project, or the explicit `[project.include]` `packages` list). Includes `*.jac`, `*.py`, `*.pyi`, `*.lark`, `py.typed`, and `*.jir` by default.
3. Generates a PEP 427-compliant `.whl` archive with `METADATA`, `WHEEL`, `RECORD`, `top_level.txt`, and optional `entry_points.txt`. The build is reproducible (fixed ZIP timestamps).
4. Writes `<name>-<version>-py3-none-any.whl` to the output directory.

> **Note on bytecode:** `jac bundle` ships `.jir` files only if they already exist in your source tree. Use `--precompile` to auto-generate `.jir` files for every `python3.X` interpreter on `PATH` before packaging, each version gets its own isolated venv so compilation is clean.

**Examples:**

```bash
# Build wheel into dist/ (default)
jac bundle

# Build to a custom directory
jac bundle -o /tmp/wheels

# Pre-compile for all Python versions on PATH, then build
jac bundle --precompile

# Upload to PyPI after building
jac bundle --precompile && twine upload dist/*

# Install locally to test before publishing
pip install dist/mylib-1.0.0-py3-none-any.whl
```

**Requirements:**

A `[project]` section must exist in `jac.toml`. At minimum:

```toml
[project]
name = "mylib"
version = "1.0.0"
```

See the [Configuration Reference](../config/index.md#project) for the full set of publishing fields (`license`, `readme`, `authors`, `[project.include]`, and more).

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
jaclang = "0.9.0"        # minimum compatible jac binary (host) runtime, not a PyPI dependency

[[jacpack.plugins]]
name = "jac-client"
version = "0.1.0"

[jacpack.options]
directories = [".jac"]
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

### jac eject

Compile a Jac project into a runnable FastAPI + JavaScript app. The output contains **zero `.jac` files**: each walker is compiled to Python and served by a FastAPI backend, and the `.cl.jac` UI is compiled to JavaScript on Vite. The backend runs the walkers on the `jac` binary's bundled jaclang runtime (so persistence, graph traversal, access control, and `by llm()` behave exactly as under `jac start`), and exposes jaclang-native auth. Use it when you want an editable FastAPI/JS codebase you can extend and deploy without writing Jac.

```bash
jac eject [-h] [-o OUTPUT] [-f] [source]
```

| Option | Description | Default |
|--------|-------------|---------|
| `source` | Project directory to eject (must contain `jac.toml`) | `.` |
| `-o, --output` | Output directory | `<project>/ejected` (overridable via `[eject].output`) |
| `-f, --force` | Overwrite a non-eject directory at the output path | `False` |

**What gets emitted**

- Server-side `.sv.jac` (and the server scope of plain `.jac`) modules become Python via the compiler's `gen.py`, keeping their real `jaclang.jac0core.jaclib` imports.
- Client-side `.cl.jac` modules become JavaScript via `gen.js` (JSX lowers to `__jacJsx(...)`, `has` to `useState`, `sv import` to HTTP RPC stubs). Client modules never go to the backend.
- A generated `backend/main.py` is the FastAPI app: one `POST /walker/<Name>` per walker, `POST /function/<name>` per function, plus `/user/register` and `/user/login`. `:pub` walkers/functions are open endpoints; the rest require a bearer token.
- `.impl.jac` / `.test.jac` files are skipped (they merge into their declaration sibling at compile time).
- A project with no client `app` component (no `cl {}` block / `.cl.jac`) ejects **backend-only**: the `frontend/` scaffold is skipped so there is no broken Vite build.

**Output layout**

```
<project>/ejected/
├── .jac-ejected         marker (lets re-runs regenerate without --force)
├── backend/
│   ├── main.py          FastAPI app (walkers/functions + auth routes)
│   ├── requirements.txt  jaclang + fastapi + uvicorn (see runtime note below)
│   └── <module>.py      compiled server modules (real jaclang imports)
└── frontend/
    ├── package.json     npm dependencies (includes Vite)
    ├── vite.config.js   dev server proxying /walker, /function, /user to the backend
    ├── index.html       SPA shell
    └── src/             compiled .cl.jac modules + vendored @jac/runtime
```

The generated `backend/main.py` wires up jaclang's `UserManager` and `ExecutionManager`: `/user/register` and `/user/login` create and authenticate users (each gets their own persistent SQLite-backed root graph), and each walker route resolves the bearer token to a user (falling back to a `__guest__` user for `:pub` walkers) before running the walker in that user's context. When a built frontend is present at `frontend/dist`, `main.py` mounts it so a single `uvicorn main:app` serves both the API and the UI.

**Persistence**

By default the object graph persists to a local SQLite file via the jaclang runtime. To persist through SQLAlchemy instead (so the same backend can target Postgres/MySQL), opt in via `jac.toml`:

```toml
[eject.db]
driver = "sqlalchemy"   # or "sqlite"
```

This vendors a `backend/_jac_sqldb.py` SQLAlchemy `PersistentMemory` backend and registers it through the runtime's `get_persistent_memory` hook, and adds `SQLAlchemy` to `requirements.txt`. The connection URL defaults to a SQLite file under `backend/` and is overridable at runtime with `JAC_DB_URL` (e.g. `postgresql://...`). This is a single-writer backend (correct for one uvicorn worker); for multi-process writers use jac-scale.

**Examples**

```bash
# Eject the current project to ./ejected/
jac eject

# Eject a specific project to a chosen output directory
jac eject ./myapp -o /tmp/myapp-out

# Overwrite an existing (non-eject) directory at the output path
jac eject ./myapp --force
```

**Running the ejected project**

```bash
cd ejected
(cd frontend && npm install && npm run build)
cd backend && pip install -r requirements.txt && uvicorn main:app
```

The backend listens on `PORT` (default 8000). For frontend dev with hot reload, run `npm run dev` in `frontend/` instead; its Vite config proxies `/walker`, `/function`, and `/user` to the backend.

**Caveats**

- The ejected backend imports the jaclang runtime (`jaclang.runtimelib.server`, and the compiled modules import `jaclang.jac0core.jaclib`), so that runtime must be available in the environment that runs `uvicorn`. The goal of `jac eject` is *zero `.jac` files and an editable FastAPI surface*, not zero jaclang runtime.

    !!! warning "Runtime provisioning is being migrated"
        `jaclang` is no longer published to PyPI -- it ships as the `jac` binary. The generated `requirements.txt` still lists a `jaclang` entry and the run step above uses a plain `pip install`, which no longer resolves. Until eject is updated to package the binary's runtime, run the ejected backend in an environment that already provides the jaclang runtime (for example, a checkout where the `jac` binary is on PATH) rather than relying on a standalone `pip`-based deploy.
- The generated FastAPI app enables permissive CORS (`allow_origins=["*"]`) for local dev; restrict it before deploying to production.
- `.impl.jac` and `.test.jac` files are skipped; so are well-known build directories (`.jac`, `.git`, `.venv`, `node_modules`, `__pycache__`, `dist`, `build`, etc.).
- Persistent state (users, root nodes, graph data) lives under `backend/.jac/data/` after first run, just as it would for `jac start`.

**Extending eject from a plugin**

Like every other command, `jac eject` is extensible through the standard plugin hook mechanism -- a plugin can add flags via `registry.extend_command("eject", ...)` and either replace the default behavior in a pre-hook or augment the output in a post-hook. See the [Plugin Authoring Guide](../plugin-authoring.md) for the full extension model. `jaclang.cli.commands.impl.eject` exports `load_eject_project_metadata(src: Path) -> dict`, which parses `jac.toml` and returns `project_name`, `entry_point`, `entry_module`, and the raw `toml_data`, so plugin hooks can read sections like `[plugins.scale]` or `[dependencies.npm]` without re-parsing.

---

### jac jac2js

Generate JavaScript output from Jac code (used for jac-client frontend compilation).

```bash
jac jac2js [-h] filename
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file to compile to JS | Required |

**Examples:**

```bash
# Generate JS from Jac file
jac jac2js app.jac
```

> **Deprecated:** `jac js` is a deprecated alias for `jac jac2js` and will be
> removed in a future release. It still works but emits a deprecation warning
> on stderr; update scripts to use `jac jac2js`.

---

## Utility Commands

### jac guide

Show the curated Jac reference guides bundled with the compiler -- the authoritative spec for writing correct, idiomatic Jac. AI coding agents and humans can read them straight from the CLI; nothing to install.

```bash
jac guide [-h] [-s SEARCH] [-e EXPORT] [-j] [topic]
```

| Option | Description | Default |
|--------|-------------|---------|
| `topic` | Guide name to display (omit to list every guide) | None |
| `-s, --search` | List only guides matching a keyword | None |
| `-e, --export` | Export all guides as a Claude Code skills directory at this path | None |
| `-j, --json` | Emit machine-readable JSON (for tools and agents) | `False` |

**Examples:**

```bash
# List every available guide
jac guide

# Print a specific guide
jac guide jac-types

# Find guides by keyword
jac guide --search walker

# Machine-readable list for tooling and agents
jac guide --json

# Export the guides as auto-loading Agent Skills
jac guide --export ~/.claude/skills
```

See [Agent Skills and MCP](../../quick-guide/agent-skills-and-mcp.md) for using the guides with AI assistants.

---

### jac grammar

Extract and print the Jac grammar.

```bash
jac grammar [-h] [--lark] [-o OUTPUT]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--lark` | Output in Lark format instead of EBNF | `False` |
| `-o, --output` | Write output to file instead of stdout | None |

**Examples:**

```bash
# Print grammar in EBNF format
jac grammar

# Print in Lark format
jac grammar --lark

# Save to file
jac grammar -o grammar.ebnf
```

---

### jac script

Run custom scripts defined in the `[scripts]` section of `jac.toml`.

```bash
jac script [-h] [-l] [name]
```

| Option | Description | Default |
|--------|-------------|---------|
| `name` | Script name to run | None |
| `-l, --list_scripts` | List available scripts | `False` |

**Examples:**

```bash
# Run a script
jac script dev

# List available scripts
jac script --list
```

See [Configuration: Scripts](../config/index.md#scripts) for defining scripts in `jac.toml`.

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

### jac nacompile

Compile a `.na.jac` file to a standalone native ELF executable. No external compiler, assembler, or linker is required. The entire pipeline runs in pure Python using llvmlite and a built-in ELF linker.

```bash
jac nacompile filename [-o OUTPUT]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Path to the `.na.jac` file (must have `with entry {}` block) | *required* |
| `-o, --output` | Output binary path | filename without `.na.jac` |

The file must contain a `with entry { }` block (which defines the `jac_entry()` function). Files with Python/server dependencies (`native_imports`) cannot be compiled to standalone binaries.

**What happens under the hood:**

1. Compiles the `.na.jac` through the Jac pipeline to get LLVM IR
2. Injects `main()` and `_start` as pure LLVM IR (zero inline assembly)
3. Emits native object code via llvmlite's `emit_object()`
4. Links into an ELF executable via the built-in pure-Python ELF linker

The resulting binary dynamically links against `libc.so.6`. Memory management uses a self-contained reference counting scheme -- no external garbage collector (libgc) is required.

**Examples:**

```bash
# Compile to ./chess
jac nacompile chess.na.jac

# Compile with custom output name
jac nacompile chess.na.jac -o mychess

# Run the binary
./mychess
```

---

### jac completions

Generate and install shell completion scripts for the `jac` CLI.

```bash
jac completions [-h] [-s SHELL] [-i] [--no-install]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-s, --shell` | Shell type (`bash`, `zsh`, `fish`) | `bash` |
| `-i, --install` | Auto-install completion to shell config | `False` |

When `--install` is used, the completion script is written to `~/.jac/completions.<shell>` (e.g. `~/.jac/completions.bash`) and a source line is added to your shell config file (`~/.bashrc`, `~/.zshrc`, or `~/.config/fish/config.fish`).

**Installed files:**

| Shell | Completion script | Config modified |
|-------|------------------|-----------------|
| bash | `~/.jac/completions.bash` | `~/.bashrc` |
| zsh | `~/.jac/completions.zsh` | `~/.zshrc` |
| fish | `~/.jac/completions.fish` | `~/.config/fish/config.fish` |

**Examples:**

```bash
# Print bash completion script to stdout
jac completions

# Auto-install for bash (writes to ~/.jac/completions.bash)
jac completions --install

# Generate zsh completions
jac completions --shell zsh

# Auto-install for fish
jac completions --shell fish --install
```

> **Note:** After installing, run `source ~/.bashrc` (or restart your shell) to activate completions. Completions cover subcommands, options, and file paths.

---

### jac lsp

Start the Language Server Protocol server (for IDE integration).

```bash
jac lsp
```

---

## Plugin Commands

Plugins can add new commands and extend existing ones. These commands are available when the corresponding plugin is installed.

### jac-client Commands

These commands ship with `jaclang` core -- no separate install needed.

#### jac build

Build a Jac application for a specific target.

```bash
jac build [filename] [--client TARGET] [-p PLATFORM]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Path to .jac file | `main.jac` |
| `--client` | Build target (`web`, `desktop`, `pwa`, `mobile`) | `web` |
| `-p, --platform` | **Mobile:** `android`, `ios`, `all`. **Desktop:** `windows` names the sidecar `jac-sidecar.exe` | Current platform |

**Examples:**

```bash
# Build web target (default)
jac build

# Build desktop app
jac build --client desktop

# Build on Windows for the windows binary
jac build --client desktop --platform windows

# Build mobile app for Android
jac build --client mobile --platform android

# Build mobile app for iOS
jac build --client mobile --platform ios
```

#### jac setup

One-time initialization for a build target.

```bash
jac setup <target> [-p PLATFORM]
```

For `target=mobile`, `--platform` supports `android`, `ios`, or `all`.

**Examples:**

```bash
# Setup Capacitor for mobile builds
jac setup mobile

# Setup iOS scaffold only (macOS only)
jac setup mobile --platform ios

# Setup both Android and iOS scaffolds (macOS)
jac setup mobile --platform all
```

#### Extended Flags

| Base Command | Added Flag | Description |
|-------------|-----------|-------------|
| `jac create` | `--use client` | Create full-stack project template |
| `jac create` | `--skip` | Skip npm package installation |
| `jac start` | `--client <target>` | Client build target for dev server |
| `jac add` | `--npm` | Add npm (client-side) dependency |
| `jac remove` | `--npm` | Remove npm (client-side) dependency |

#### Desktop builds

The `desktop` client target ships with `jaclang` core -- no separate install. There is no
separate `jac desktop` command and no setup step - build and run with
`jac build --client desktop` / `jac start --client desktop`. See the
[jac-desktop Reference](../plugins/jac-desktop.md) for configuration.

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

# Lint and fix
jac lint . --fix
```

### Publishing a Package

Expected project layout:

```
mylib/
├── jac.toml          ← must contain [project] section
├── README.md
└── mylib/            ← source dir (matches [project] name)
    ├── __init__.jac
    └── utils.jac
```

```bash
# Build wheel from jac.toml
jac bundle

# Test locally in a clean environment before uploading
python -m venv test_env && source test_env/bin/activate
pip install dist/mylib-1.0.0-py3-none-any.whl

# Upload to TestPyPI first to verify metadata
twine upload --repository testpypi dist/*

# Then publish to PyPI
twine upload dist/*
```

### Production

!!! note
    `main.jac` is the default entry point for `jac start`. If your entry point differs (e.g., `app.jac`), pass it explicitly: `jac start app.jac --scale`.

```bash
# Start locally
jac start -p 8000

# Deploy to Kubernetes
jac start --scale

# Check deployment status
jac status main.jac

# Remove deployment
jac destroy main.jac
```

## See Also

- [Project Configuration](../config/index.md)
- [jac-scale Documentation](../plugins/jac-scale.md)
- [Testing Guide](../testing.md)
