# CLI Reference

The `jac` command is your primary interface for working with Jac projects. It handles the full development lifecycle: running programs (`jac run`), type-checking code (`jac check`), running tests (`jac test`), formatting and linting (`jac fmt`, `jac check --lint`), managing dependencies (`jac add`, `jac install`), serving APIs (`jac start`), and even compiling to native binaries (`jac nacompile`, or `jac build --as native`). Think of it as combining the roles of `python`, `pip`, `pytest`, `black`, and `flask` into a single unified tool.

Every capability ships built into the core binary. The `scale` subsystem (formerly the `jac-scale` plugin) provides deployment commands and flags -- for example, `jac start --scale` for Kubernetes deployment. The full-stack client framework (formerly the `jac-client` / `jac-desktop` plugins) contributes others, such as `jac build --client desktop` for desktop app packaging. byLLM likewise ships built in, contributing `jac model` and the AI language features.

> **💡 Enhanced Output**: All CLI commands render beautiful, colorful Rich-style output out of the box -- themes, panels, and spinners are built into jaclang by default, with no extra install needed.

## I want to…

A task-first index into the commands below. The full alphabetical list follows in [Quick Reference](#quick-reference).

| I want to… | Command(s) |
|---|---|
| Run a program | `jac run` (no filename → runs the project by its `kind`; `--entry <walker>` runs a specific entrypoint) |
| Start a web/API server | `jac start` |
| Run the live hot-reload dev loop | `jac dev` · `jac start --dev` |
| Deploy to Kubernetes | `jac start --scale` · `jac scale status` · `jac scale destroy` |
| Create a new project | `jac create` |
| Set up / build a client shell (web, desktop, mobile) | `jac setup` · `jac build --client <target>` |
| Compile a native binary or C-ABI shared library | `jac nacompile` · `jac build --as native` |
| Build one distributable artifact (.jab, wheel, npm, source) | `jac build --as {jab,wheel,npm,source,…}` |
| Add, remove, or update dependencies | `jac add` · `jac remove` · `jac update` |
| Install project dependencies (preview with `--plan`) | `jac install` · `jac install --plan` |
| Run an installed CLI tool under Jac | `jac x` |
| Type-check, format, or lint | `jac check` · `jac fmt` · `jac check --lint` · `jac precommit` |
| Run tests | `jac test` |
| Debug or visualize a graph | `jac run --debug` · `jac dot` · `jac browse` |
| Have an AI agent write or edit code in my project | `jac ai` |
| Query code structure (definitions, uses, walkers) | `jac code` |
| Inspect or recover the persistence DB | `jac db` |
| Manage config or profiles | `jac config` |
| Manage byLLM local models | `jac model` |
| Use Jac from an AI assistant | `jac guide` · `jac mcp` |
| Convert between Python, Jac, and JS | `jac tool py2jac` · `jac tool jac2py` · `jac tool jac2js` |
| Clean caches / artifacts | `jac clean` · `jac purge` |

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `jac run` | Execute a Jac file or `.jab`, or (no filename) run the current project by its kind (`--entry <walker>`, `--debug`) |
| `jac start` | Start REST API server (use `--scale` for K8s deployment) |
| `jac dev` | Live hot-reload dev loop (project-entry resolution + HMR serve) |
| `jac build` | Type-check gate, then emit one artifact (`--as jab\|sealed\|binary\|wheel\|npm\|source\|native`; default `.jab`; `--client` builds a client shell) |
| `jac create` | Create new project (`--pack` to bundle a directory into a `.jacpack` template) |
| `jac check` | Type check code (`--lint` to lint, `--lint --fix` to auto-fix) |
| `jac test` | Run tests |
| `jac fmt` | Format code |
| `jac precommit` | Run format + check using `jac.toml` lint settings (installable as a git hook) |
| `jac clean` | Clean project build artifacts |
| `jac purge` | Purge global bytecode cache (works even if corrupted) |
| `jac dot` | Generate graph visualization |
| `jac browse` | Automate a headless browser over CDP (navigate, click, snapshot, screenshot) |
| `jac ai` | Launch an interactive Jac coding agent (works with local models, no API key) |
| `jac code` | Query code structure via the compiler (symbols, uses, walkers, slices) |
| `jac mcp` | Start the MCP server so AI assistants can use the live Jac compiler |
| `jac completions` | Generate (and optionally install) shell completions |
| `jac nacompile` | Compile the native (`na`) subset to a binary, shared library, or WebAssembly |
| `jac model` | Manage byLLM local-model weights (Gemma 4, Qwen 3.5, …) |
| `jac config` | Manage project configuration |
| `jac scale` | Manage local microservices (status/stop/restart/logs) and platform deployments (status/destroy) |
| `jac add` | Add packages to project |
| `jac install` | Install project dependencies from `jac.toml` (`--plan` to preview the resolved plan), or `jac install <pkg>` to install packages into the project's `.jac/venv` |
| `jac x` | Run an installed CLI tool (Python console-script or npm tool) under the `jac` runtime |
| `jac remove` | Remove packages from project |
| `jac update` | Update dependencies to latest compatible versions |
| `jac tool` | Language tools & source transforms (`jac2py`, `py2jac`, `jac2js`, `grammar`, IR, AST) |
| `jac guide` | Show curated Jac reference guides |
| `jac lsp` | Language server |
| `jac setup` | Setup client build target (jac-client) |
| `jac db` | Inspect persistence DB, manage rescue aliases, recover quarantined data |

---

## Version Info

```bash
jac --version
```

Displays the Jac version and platform, plus documentation and community links:

```
   _
  (_) __ _  ___     Jac Language
  | |/ _` |/ __|
  | | (_| | (__     Version:  0.31.0
 _/ |\__,_|\___|
|__/                Platform: Linux x86_64

📚 Documentation: https://docs.jaseci.org
💬 Community:     https://discord.gg/6j3QNdtcN6
🐛 Issues:        https://github.com/Jaseci-Labs/jaseci/issues
```

(byLLM, scale, the full-stack client framework, and the MCP server all ship inside the binary, so there is no separate version to report for them.)

---

## Core Commands

### jac run

Execute a Jac file, a prebuilt `.jab` artifact, or (with no filename) run the current project.

**Note:** `jac <file>` is shorthand for `jac run <file>` - both work identically.

```bash
jac run [-h] [-s] [--show] [-m] [--no-main] [-c] [--no-cache] [-e DIAGNOSTICS] [--profile PROFILE] [--entry ENTRY] [-n NODE] [-r ROOT] [--debug] [filename] [args ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Jac file (or `.jab` artifact) to run. Omit to dispatch on the project's `jac.toml` | (project) |
| `-s, --show` | Print the resolved project run-plan (kind, action, equivalent command) without executing | `False` |
| `-m, --main` | Treat module as `__main__` | `True` |
| `-c, --cache` | Enable compilation cache | `True` |
| `-e, --diagnostics` | Diagnostic verbosity: `error`, `all`, or `none` | `error` |
| `--profile` | Configuration profile to load (e.g. prod, staging) | `""` |
| `--entry` | Run a specific entrypoint (function/walker) instead of the module's `with entry` block | None |
| `-n, --node` | Starting node ID (with `--entry`) | None |
| `-r, --root` | Root executor ID (with `--entry`) | None |
| `--debug` | Launch the interactive debugger on the file | `False` |
| `args` | Arguments passed to the script (available via `sys.argv[1:]`) | |

Like Python, everything after the filename is passed to the script. Jac flags must come **before** the filename.

**Project-aware run (no filename).** Inside a project, a bare `jac run` resolves the project *kind* from `[project] kind` in `jac.toml` (or infers it from the entry-point's codespace) and does the natural action for that kind: **execute** runnable kinds (`cli`, `cli-native`), **serve** server kinds (`service`, `web-app`, ...), or **build** artifact kinds (`native-binary`, `native-lib`, `py-package`, `js-package`). Use `jac run --show` to preview the plan and the equivalent primitive command (`run` / `start` / `nacompile` / `build`) without running it. See [project kinds](../../quick-guide/project-kinds.md) and [config `[project]`](../config/index.md).

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

**Running a specific entrypoint (`--entry`).** By default `jac run` executes a module's `with entry` block. Pass `--entry <name>` to invoke a specific function or walker instead, optionally seeding a starting node (`-n/--node`) and root (`-r/--root`). Flags come **before** the filename; script arguments follow it.

```bash
# Invoke a specific walker
jac run --entry my_walker main.jac

# With arguments passed to the entrypoint
jac run --entry process_data main.jac arg1 arg2

# With root and starting node
jac run --entry my_walker -r root_id -n node_id main.jac
```

**Running a prebuilt `.jab` artifact.** `jac run app.jab` executes a sealed artifact with **zero live compilation** -- the sealed image (client dist, serve manifest, native binaries) is baked in and hash-verified at load. `cli`-kind artifacts execute; use [`jac start`](#jac-start) to production-serve servable kinds.

```bash
# Execute a sealed artifact
jac run app.jab
```

**Interactive debugger (`--debug`).** Pass `--debug` to launch the interactive debugger on a file. See [VS Code Debugger Setup](#vs-code-debugger-setup) below for editor integration.

```bash
# Start the debugger
jac run --debug main.jac
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

Start a Jac application as an HTTP API server. Use `--scale` to deploy to Kubernetes (handled by the built-in `scale` subsystem; the first `--scale` run resolves its deploy deps via `jac install`). Use `--dev` for Hot Module Replacement (HMR) during development; live-reload is powered by the `watchdog` library bundled in the `jac` binary, so no extra install is needed.

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
| `--scale` | Deploy to Kubernetes (built-in scale subsystem) | `False` |
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

# Deploy to Kubernetes (built-in scale subsystem)
jac start --scale

# Build and deploy to Kubernetes
jac start --scale --build
```

> **Note**:
>
> - If your project uses a different entry file (e.g., `app.jac`, `server.jac`), you can specify it explicitly: `jac start app.jac`
>
---

### jac dev

The dedicated live hot-reload development loop. `jac dev` resolves the project entry point and serves it with Hot Module Replacement (HMR), rebuilding on every save. Unlike [`jac run`](#jac-run) / [`jac start`](#jac-start), it always works from **live source** and never reads a sealed `.jab` artifact. (`jac start --dev` still exists for HMR serving; `jac dev` is the purpose-built loop.)

```bash
jac dev [-h] [-p PORT] [--api_port API_PORT]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-p, --port` | Port to serve on | `8000` |
| `--api_port` | Separate API port for HMR (0 = same as `port`) | `0` |

**Examples:**

```bash
# Start the hot-reload dev loop
jac dev

# On a custom port
jac dev -p 3000
```

---

### jac create

Initialize a new Jac project with configuration. Creates a project folder with the given name containing the project files, including an `AGENTS.md` that points AI coding agents at `jac guide`.

`jac create` is kind-aware: `--kind <kind>` scaffolds a project for a specific project kind, stamping `[project] kind` into `jac.toml` so the new project's bare `jac run` dispatches correctly (see `jac run`). All built-in kinds ship with `jaclang` -- including `web-app`, `web-static`, `mobile`, and `desktop`, which previously required the separate `jac-client` / `jac-desktop` plugins and now need no extra install.

```bash
jac create [-h] [-f] [-k KIND] [-u USE] [-l] [name]
```

| Option | Description | Default |
|--------|-------------|---------|
| `name` | Project name (creates folder with this name) | Current directory name |
| `-f, --force` | Overwrite existing project | `False` |
| `-k, --kind` | Project kind: cli, cli-native, native-binary, native-lib, service, service-mesh, py-package, js-package, web-app, web-static, desktop, mobile | `cli` |
| `-u, --use` | Custom template: file path or URL to a `.jacpack`, or a named variant (e.g. `jac-shadcn`) | `default` |
| `-l, --list_jacpacks` | List available project kinds and named variants | `False` |
| `--pack DIR` | Bundle a template directory into a distributable `.jacpack` file (absorbs `jac jacpack pack`) | None |
| `--pack_output F` | Output path for the bundled `.jacpack` (with `--pack`) | `<name>.jacpack` |

`--kind` and `--use` are mutually exclusive.

**Examples:**

```bash
# Create a basic cli project (creates myapp/ folder)
jac create myapp
cd myapp

# Scaffold a headless API service
jac create myapp --kind service

# Scaffold a natively-compiled binary
jac create myapp --kind native-binary

# Scaffold a full-stack app (built into jaclang core)
jac create myapp --kind web-app

# Scaffold a shadcn-themed full-stack app
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

# Bundle a template directory into a .jacpack (absorbs `jac jacpack pack`)
jac create --pack ./my-template
jac create --pack ./my-template --pack_output custom-name.jacpack
```

**See Also:** Use `jac create --pack` to bundle a directory into a distributable `.jacpack` template, then `jac create --use <file>.jacpack` to scaffold from it.

---

### jac check

Type check Jac code for errors. Pass `--lint` to also run the linter (this absorbs the former `jac lint`), and `--lint --fix` to auto-fix lint violations.

```bash
jac check [-h] [-e] [-i [IGNORE ...]] [-p] [--nowarn] [--lint] [--fix] paths [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to check | Required |
| `-e, --print_errs` | Print detailed error messages | `True` |
| `-i, --ignore` | Space-separated list of files/folders to ignore | None |
| `-p, --parse_only` | Only check syntax (skip type checking) | `False` |
| `--nowarn` | Suppress warning output | `False` |
| `--lint` | Also run the linter and report style/lint violations | `False` |
| `--fix` | With `--lint`, auto-fix lint violations (code corrections) | `False` |

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

# Type-check and lint the current directory
jac check . --lint

# Lint and auto-fix violations
jac check . --lint --fix

# Lint excluding folders
jac check . --lint --ignore fixtures
```

Errors and warnings are displayed with structured diagnostic codes (e.g., `E1030`, `W2001`). You can suppress individual diagnostics inline with `# jac:ignore[CODE]`:

> **Lint Rules**: `jac check --lint` (formerly `jac lint`) reports style violations; add `--fix` to apply auto-fixes. Configure rules via [`[check.lint]`](../config/index.md#checklint) in `jac.toml`. See [Lint Rules](../diagnostics.md#lint-rules-w3xxx-e3xxx) for the full list with diagnostic codes.

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

### jac fmt

Format Jac code according to style guidelines. For auto-linting (code corrections like combining consecutive `has` statements, converting `@staticmethod` to `static`), use `jac check --lint --fix` instead.

```bash
jac fmt [-h] [-s] [-l] [-c] paths [paths ...]
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
jac fmt main.jac -s

# Apply formatting
jac fmt main.jac

# Format entire directory
jac fmt .

# Check formatting without modifying (useful in CI)
jac fmt . --check
```

> **Note**: For auto-linting (code corrections), use `jac check --lint --fix` instead. See [`jac check`](#jac-check) above.
>
> **Safety**: If the formatter detects that comments were displaced (e.g., moved to the end of the file), it emits error `E5051` and refuses to save the file. Run `jac fmt <file> -s` to inspect the output without writing.

---

### jac lint

Linting has folded into `jac check`. Run **`jac check --lint`** to report violations and **`jac check --lint --fix`** to auto-fix them. See [`jac check`](#jac-check) above for options and examples.

---

### jac precommit

*Hidden from `jac --help` (still functional).*

Run a pre-commit pipeline (`jac fmt --lintfix` followed by `jac check`) using the lint settings from `jac.toml`. Exits non-zero if any file was reformatted or `jac check` reported errors, so it can gate a commit. Because formatting honors [`[check.lint]`](../config/index.md#checklint), enabling the opt-in `strip-comments` / `strip-docstrings` rules there makes `jac precommit` apply them too.

```bash
jac precommit [-h] [-s] [-v] [-i] [paths ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `paths` | Files/directories to process | Project root |
| `-s, --staged` | Only process git-staged `.jac` files | `False` |
| `-v, --verify` | Verify only: do not rewrite files (exit 1 if unformatted) | `False` |
| `-i, --install` | Install a git pre-commit hook that runs this command | `False` |

**Examples:**

```bash
# Format (lintfix) and check the whole project
jac precommit

# Run on staged .jac files only
jac precommit --staged

# Verify without writing (what the installed git hook runs)
jac precommit --staged --verify

# Install a .git/hooks/pre-commit hook
jac precommit --install
```

> **Git hook**: `jac precommit --install` writes an executable `.git/hooks/pre-commit` that runs `jac precommit --staged --verify`. The hook blocks a commit when staged `.jac` files are unformatted or fail `jac check`; run `jac precommit` (without `--verify`) to apply the fixes, then re-stage. If a hook already exists, the installer leaves it untouched and reports the conflict.

---

### jac enter

Running a specific entrypoint has folded into `jac run`. Use **`jac run --entry <walker> <file>`** (with optional `-n/--node` and `-r/--root`). See [`jac run`](#jac-run) above.

---

## Visualization & Debug

### jac dot

*Hidden from `jac --help` (still functional).*

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

Interactive debugging has folded into `jac run`. Use **`jac run --debug <file>`** to launch the debugger on a file. See [`jac run`](#jac-run) above.

```bash
# Start the debugger
jac run --debug main.jac
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

*Hidden from `jac --help` (still functional).*

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

## AI-Assisted Development

Three commands make Jac projects legible to (and drivable by) AI agents -- including Jac's own built-in coding agent. See also [Agent Skills & MCP](../../quick-guide/agent-skills-and-mcp.md) for the workflow overview.

### jac ai

Launch an interactive Jac coding agent in your project. Runs against your configured byLLM model -- including fully local models, so it works without an API key.

```bash
jac ai [prompt] [-m MODEL] [--n_ctx N] [--safe] [-q] [--ui]
```

| Option | Description | Default |
|--------|-------------|---------|
| `prompt` | Optional one-shot request; omit for an interactive session | interactive |
| `-m, --model` | Model to use, e.g. `local:gemma-4-e4b` or `openai/gpt-4o` | from `jac.toml` |
| `-n, --n_ctx` | Context-window size for local models (tokens) | model default |
| `-s, --safe` | Confirm every file write and code execution | off |
| `-q, --quiet` | Compact output: hide live reasoning, timings, and step detail | off |
| `-u, --ui` | Open the agent in a web UI with a live phase-graph visualizer | off |

**Examples:**

```bash
# Interactive session using the project's configured model
jac ai

# One-shot request
jac ai "add a walker that lists all Todo nodes"

# Fully local, no API key
jac ai -m local:gemma-4-e4b

# Web UI with live phase-graph visualization
jac ai --ui
```

### jac code

Query code structure via the compiler -- grep's structural successor. Returns JSON by default (for tools and agents); pass `--text` for human-readable output.

```bash
jac code <action> [target] [-t] [-d DEPTH]
```

| Action | Description |
|--------|-------------|
| `symbol <name>` | Definitions and use-sites of a symbol |
| `uses <name>` | All reads/writes of a symbol |
| `map [kind]` | Structural overview of nodes, walkers, edges, objs (optionally filtered by kind) |
| `walkers <node-type>` | Walkers whose traversals visit a given node type |
| `slice <name> [-d N]` | Typed neighbourhood of a symbol to depth N (built for prompt assembly) |
| `diag [file]` | Structured compiler errors and warnings |

**Examples:**

```bash
jac code map                    # what's in this project?
jac code symbol Todo --text     # where is Todo defined and used?
jac code walkers Todo           # which walkers touch Todo nodes?
jac code slice add_todo -d 2    # everything an agent needs to edit add_todo
```

### jac mcp

Start the Model Context Protocol server so any MCP client (Claude Code, Claude Desktop, Cursor, ...) can lint, transpile, run, and explain Jac code through the live compiler.

```bash
jac mcp [-t stdio|sse|streamable-http] [-p PORT] [--host HOST] [--mode lite|standard|full] [--inspect]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-t, --transport` | Transport protocol | `stdio` |
| `-p, --port` | Port for SSE/HTTP transports | `3001` |
| `--host` | Bind address for SSE/HTTP transports | `127.0.0.1` |
| `--mode` | Tool/prompt exposure level for the connecting model | `full` |
| `--inspect` | Print inventory of resources, tools, and prompts, then exit | off |

See the [MCP Server Reference](../mcp.md) for the full tool catalog and per-client setup snippets.

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

> **Note:** In CI and other non-TTY contexts, the runtime will not prompt to download. Either `jac model pull <alias>` ahead of time, or set `BYLLM_AUTO_DOWNLOAD=1` (or `[byllm.local].auto_download = true` in `jac.toml`) to allow silent first-run downloads.

---

## Database Operations

The `jac db` command group inspects the live persistence backend, manages DB-resident rescue aliases, and recovers quarantined anchors. It works against any `PersistentMemory` backend -- `SqliteMemory` (default), the built-in scale `MongoBackend`, or any custom backend that implements the interface -- through the same set of subcommands.

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

Both arguments to `alias add` are fully-qualified `module.ClassName` strings -- the `module` part is what would have appeared in the stored row's `arch_module` field. For files run via `jac run app.jac`, the module is `__main__`.

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

## Deployment (scale)

### jac start --scale

Deploy to Kubernetes using the built-in `scale` subsystem. See the [`jac start`](#jac-start) command above for full options.

```bash
jac start --scale           # Deploy without building
jac start --scale --build   # Build and deploy
```

---

### jac scale

`jac scale <action>` is the unified noun for scale operations. It has two modes depending on the argument:

- **Local microservices** -- `jac scale <action> [name]` manages locally-running services: `status`, `stop`, `restart`, `logs`.
- **Platform deployment** -- given a `.jac` app file, `jac scale <action> <file.jac> [--target T] [--component C]` operates on a platform deployment: `status` (health of each component) and `destroy` (tear the deployment down). This absorbs the former top-level `jac status` / `jac destroy` verbs.

To *deploy* in the first place, run `jac start --scale` (see [`jac start`](#jac-start) above).

```bash
jac scale <action> [name|file] [--target TARGET] [--component COMPONENT]
```

| Option | Description | Default |
|--------|-------------|---------|
| `action` | `status`, `stop`, `restart`, `logs` (local) or `status`, `destroy` (platform, with a `.jac` file) | Required |
| `name` / `file` | Local service name, or the path to the `.jac` app file for platform actions | None |
| `--target` | Deployment target platform (platform actions) | `kubernetes` |
| `--component` | Restrict the action to a single component (platform actions) | None |

**Platform status output (`jac scale status app.jac`):**

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
# Local microservices
jac scale status
jac scale logs my-service
jac scale restart my-service
jac scale stop my-service

# Platform deployment status of a .jac app
jac scale status app.jac
jac scale status app.jac --target kubernetes

# Tear down a platform deployment
jac scale destroy app.jac
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

For private packages from custom registries (e.g., GitHub Packages), configure scoped registries and auth tokens in `jac.toml` under `[client.npm]`. See [NPM Registry Configuration](../plugins/jac-client.md#npm-registry-configuration).

---

### jac install

`jac install` has two modes depending on whether package names are passed. Pass `--plan` (optionally with `--json`) to preview the resolved dependency plan without installing anything -- this absorbs the former `jac deps`.

**No-argument mode** - sync the project environment to `jac.toml`. Installs all Python (pip), git, and npm dependencies in one command. Creates or validates the project virtual environment at `.jac/venv/`. Requires a `jac.toml` in the current (or a parent) directory.

**Package mode** - `jac install <pkg> [pkg ...]` installs one or more packages into the project's virtual environment at `.jac/venv/`, without reading or modifying `jac.toml`. It is the Jac-native equivalent of `pip install <pkg>`, run through the `jac` binary's bundled pip. By default it requires a `jac.toml` in the current (or a parent) directory and installs into that project's `.jac/venv`. Pass `--global` to install into the binary's own jac-owned site instead -- a location that is on `sys.path` from **any** project, for a tool you install once and use everywhere. Either target is fully self-contained: the bundled pip and the binary's own site, never the host Python or its `site-packages`.

> **`jac install <pkg>` vs `jac add <pkg>`**
>
> | | `jac install <pkg>` | `jac install <pkg> --global` | `jac add <pkg>` |
> |---|---|---|---|
> | Target | Project `.jac/venv/` | Binary's global site | Project `.jac/venv/` |
> | Updates `jac.toml` | No | No | Yes |
> | Requires a project | Yes | No | Yes |
> | Importable from other projects | No | Yes | No |
>
> Use `jac add` when you want the dependency recorded in `jac.toml` for reproducible installs, plain `jac install <pkg>` for an ad-hoc package scoped to this project, and `jac install <pkg> --global` for a tool you want available everywhere.

```bash
jac install [-h] [packages ...] [-e PATH] [-d] [-x group [group ...]] [-v]
            [--force-reinstall] [--no-cache-dir] [--pre] [--dry-run]
            [--no-deps] [--quiet] [--prefer-binary] [--global] [--plan] [--json]
```

| Option | Description | Default |
|--------|-------------|---------|
| `packages` | Package(s) to install into the project's `.jac/venv` (or the global site with `--global`). When provided, skips `jac.toml`. | `[]` |
| `-e, --editable PATH` | Install the Jac package at `PATH` in editable mode (analogous to `pip install -e`). The target package's own `jac.toml` (read from `PATH`) supplies its dependencies; the package and those deps are linked/installed into the **current** project's `.jac/venv` (or the global site with `--global`). Cannot be combined with `packages`. Repeatable. | `None` |
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
| `--global` | Install into the binary's own jac-owned site (importable from any project), not the project's `.jac/venv`. Works outside a project. | `False` |
| `--plan` | Resolve and print the dependency plan without installing anything (absorbs the former `jac deps`) | `False` |
| `--json` | With `--plan`, emit the plan as machine-readable JSON | `False` |

**Examples:**

```bash
# Install a single package into the project's .jac/venv
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

# Editable install of a package living elsewhere into the current project's venv
jac install -e /path/to/lib

# Editable install with all optional dependency groups
jac install -e . --extras all

# Install a tool into the global site, importable from any project
jac install -e ./jac-byllm --global

# Install with verbose output
jac install -v

# Reinstall all packages from scratch (ignores cached state)
jac install --force-reinstall

# Preview what would be installed without doing it
jac install --dry-run

# Install without using pip's download cache
jac install --no-cache-dir

# Preview the resolved dependency plan without installing (formerly `jac deps`)
jac install --plan
jac install --plan --json
```

Optional groups are declared under `[optional-dependencies]` in `jac.toml`. See the [Configuration Reference](../config/index.md#optional-dependencies).

> **Self-contained installs:** `jac install` (and `jac add`, `jac remove`, `jac update`) run through the `jac` binary's own bundled pip against the project's `.jac/venv`. No system Python, `pip`, or external package manager (such as `uv`) is required or consulted -- behaviour is identical regardless of what is installed on the host.
>
> **Note:** The pip passthrough flags (`--force-reinstall`, `--no-cache-dir`, `--pre`, `--no-deps`, `--quiet`, `--prefer-binary`) are forwarded directly to pip. Use `jac update` to upgrade packages to their latest versions.
>
> **Running installed tools:** packages that ship a command-line tool (a Python console-script, or an npm tool in `node_modules/.bin`) are runnable with [`jac x <tool>`](#jac-x) -- no need to put anything on your shell `PATH`.

---

### jac x

`jac x <tool>` runs an installed command-line tool under the `jac` runtime -- the Jac-native, cross-ecosystem equivalent of `pipx run` / `npx`. It resolves a **Python console-script** (from an installed package's entry points) or an **npm tool** (from `node_modules/.bin`) and runs it. Python tools execute in-process under the bundled interpreter; npm tools run through the jac-managed **bun** runtime -- so **neither a system Python nor a system Node is required**.

The CLI tools you install with `jac install` / `jac add` are therefore runnable without putting anything on your shell `PATH`, and resolution is project-aware: inside a project, a tool installed in that project shadows a global one of the same name. `jac x <name>` also runs custom scripts defined in the `[scripts]` section of `jac.toml` -- this absorbs the former `jac script`. A bare `jac x` (or `jac x --list`) lists everything runnable.

> **Resolution order (first match wins).** By default `jac x` searches tiers **locality-first**:
>
> 1. the project's Python venv (`.jac/venv`),
> 2. the project's npm tools (`.jac/client/node_modules/.bin`),
> 3. the jac-owned global Python site (where `jac install --global` installs).
>
> `--global` restricts the search to the global Python site; `--node` restricts it to the project's npm tools. Each tool's tier is shown by `jac x --list`.

```bash
jac x [-h] [-g] [-n] [-l] [name] [args ...]
```

| Option | Description | Default |
|--------|-------------|---------|
| `name` | Tool/command name to run. Omit (or pass `--list`) to list the available tools. | `""` |
| `args` | Everything after `name` is forwarded verbatim to the tool. Flags for `jac x` itself must come **before** `name`. | `[]` |
| `-g, --global` | Resolve from the jac-owned global Python site only, ignoring the project venv and npm tools. | `False` |
| `-n, --node` | Resolve from the project's npm tools (`node_modules/.bin`) only. | `False` |
| `-l, --list_tools` | List the runnable tools across all tiers (each tagged with its tier), then exit. A bare `jac x` does the same. | `False` |

**Examples:**

```bash
# Run a Python tool installed in the project (e.g. huggingface_hub's `hf`)
jac x hf download gpt2

# Run an installed formatter on the current directory
jac x black .

# Run a project npm tool (node_modules/.bin) through bun -- no system Node needed
jac x eslint .
jac x vite build

# Force a specific tier when a name exists in more than one
jac x --global hf whoami      # the global-site Python copy
jac x --node vite build       # the project's npm copy

# List everything runnable here, tagged by tier ([project] / [node] / [global])
jac x --list
```

> **No system Python or Node required.** Python tools run in-process under the `jac` binary's bundled interpreter; npm tools run via the jac-managed `bun` (resolved from the system `PATH`, the project's `.jac/bin/bun`, or auto-downloaded), which executes the `node_modules/.bin` shims directly. Arguments after the tool name -- including flags like `--help` -- pass straight through, and the tool's exit code becomes `jac x`'s exit code.

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

### jac build

Run the whole-program **type-check gate** (fail-closed; reuses [`jac check`](#jac-check)), then emit **one** artifact. By default `jac build` produces a `.jab` -- a single self-describing sealed app bundle. Use `--as` to select a different projection. `jac build` is now the single front door that the former `jac bundle` (wheel/npm), `jac eject` (source), and project-level `jac nacompile` (native/binary) folded into.

```bash
jac build [-h] [--as {jab,sealed,binary,wheel,npm,source,native}] [-o OUTPUT] [-n] [-c]
          [--client {web,pwa,static,mobile,desktop,cef,react-native}] [-p PLATFORM] [filename]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Entry `.jac` file (omit to use the project entry) | (project) |
| `--as` | Artifact projection: `jab`, `sealed`, `binary`, `wheel`, `npm`, `source`, `native` | `jab` |
| `-o, --output` | Output directory | `dist` |
| `-n, --no_typecheck` | Skip the type-check gate | `False` |
| `-c, --check_only` | Run the gate only; emit nothing | `False` |
| `--client` | Build a client shell (`web`, `pwa`, `static`, `mobile`, `desktop`, `cef`, `react-native`) | None |
| `-p, --platform` | Platform selector for `--client` builds | Current platform |

**Projections (`--as`):**

| `--as` | Emits | Replaces |
|--------|-------|----------|
| `jab` (default) | A sealed `.jab` app bundle (deterministic `tar.gz` of the sealed image) | -- |
| `sealed` / `binary` | Sealed image / native binary form | -- |
| `wheel` | A `pip install`-ready Python wheel in `dist/` | `jac bundle` |
| `npm` | An npm tarball | `jac bundle --target npm` |
| `source` | An editable FastAPI + JavaScript source tree (zero `.jac` files) | `jac eject` |
| `native` | A standalone native binary | project-level `jac nacompile` |

**The type-check gate.** `jac build` refuses to emit an artifact if the program fails the whole-program type check. Pass `--no_typecheck` to skip the gate, or `--check_only` to run the gate and emit nothing (useful in CI).

**The `.jab` artifact.** A `.jab` is a single self-describing sealed app bundle: client dist, serve manifest, and native binaries are baked in and hash-verified at load, so [`jac run app.jab`](#jac-run) / [`jac start app.jab`](#jac-start) execute or serve it with **zero live compilation**. It is kind-aware: `cli` kinds execute, servable kinds production-serve, and attachable packages refuse to run standalone.

**Building a wheel (publish to PyPI):**

```bash
# Type-check, then build a wheel into dist/
jac build --as wheel

# Build to a custom directory
jac build --as wheel -o /tmp/wheels
```

After a wheel build the tool prints `Upload with: twine upload dist/*`. There is no `--publish` flag; upload with twine:

```bash
jac build --as wheel && twine upload dist/*
```

**Building an npm tarball:**

```bash
jac build --as npm      # prints "Publish with: npm publish"
```

To produce **both** a wheel and an npm tarball, run both commands (there is no single "all" projection):

```bash
jac build --as wheel
jac build --as npm
```

**Building a native binary or editable source tree:**

```bash
# Standalone native binary (project-level; see `jac nacompile` for file-level .na.jac)
jac build --as native

# Editable FastAPI + JavaScript source tree (formerly `jac eject`)
jac build --as source -o /tmp/myapp-out
```

**Building a client shell:**

```bash
# Build a desktop client shell
jac build --client desktop

# Build a mobile client shell for a platform
jac build --client mobile -p android
```

> **Note:** The `[project.include]` / `**/*.jir` collection settings in `jac.toml` govern what `jac build --as wheel` collects (this was formerly `jac bundle`). See the [Configuration Reference](../config/index.md#project) for the full set of publishing fields (`name`, `version`, `license`, `readme`, `authors`, `[project.include]`, and more). For the full end-to-end publishing workflow, see the [Publishing Packages](../publishing.md) guide.

---

## Template Management

### jac jacpack

Template packing has folded into [`jac create`](#jac-create). Bundle a template directory into a distributable `.jacpack` with **`jac create --pack <dir>`** (`--pack_output F` for a custom path), and list available templates/kinds with **`jac create --list_jacpacks`**. The `.jacpack` concept below is unchanged.

```bash
# Bundle a template directory into a .jacpack (formerly `jac jacpack pack`)
jac create --pack <dir> [--pack_output out.jacpack]

# List available project kinds and named variants (formerly `jac jacpack list`)
jac create --list_jacpacks
```

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
# List available templates / project kinds
jac create --list_jacpacks

# Bundle a template directory
jac create --pack ./my-template

# Bundle with custom output path
jac create --pack ./my-template --pack_output custom-name.jacpack
```

**Using Templates with `jac create`:**

Once a template is registered, use it with the `--use` flag:

```bash
jac create myproject --use mytemplate
```

---

### jac eject

Ejecting has folded into [`jac build`](#jac-build). Use **`jac build --as source`** to compile a Jac project into a runnable FastAPI + JavaScript source tree with **zero `.jac` files** -- each walker becomes a Python FastAPI route and the `.cl.jac` UI compiles to JavaScript on Vite. Use it when you want an editable FastAPI/JS codebase you can extend and deploy without writing Jac.

```bash
# Eject the current project (formerly `jac eject`)
jac build --as source

# Eject to a chosen output directory
jac build --as source -o /tmp/myapp-out
```

**What gets emitted**

- Server-side `.sv.jac` (and the server scope of plain `.jac`) modules become Python, keeping their real `jaclang.jac0core.jaclib` imports; client-side `.cl.jac` modules become JavaScript. A generated `backend/main.py` FastAPI app exposes one `POST /walker/<Name>` per walker, `POST /function/<name>` per function, plus `/user/register` and `/user/login` (`:pub` walkers/functions are open; the rest require a bearer token).
- A project with no client `app` component ejects **backend-only** (the `frontend/` scaffold is skipped). `.impl.jac` / `.test.jac` files are skipped.

**Persistence.** By default the object graph persists to a local SQLite file via the jaclang runtime. To persist through SQLAlchemy instead (so the same backend can target Postgres/MySQL), set `driver = "sqlalchemy"` under `[eject.db]` in `jac.toml`; the connection URL is overridable at runtime with `JAC_DB_URL`.

!!! warning "Runtime provisioning is being migrated"
    `jaclang` is no longer published to PyPI -- it ships as the `jac` binary. The generated `requirements.txt` still lists a `jaclang` entry, which no longer resolves via a plain `pip install`. Until source ejection is updated to package the binary's runtime, run the ejected backend in an environment that already provides the jaclang runtime (for example, a checkout where the `jac` binary is on PATH).

---

### jac jac2js

Generating JavaScript from Jac has moved under [`jac tool`](#jac-tool). Use **`jac tool jac2js <file>`** (used for client frontend compilation). See [`jac tool`](#jac-tool) below.

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

Extracting the grammar has moved under [`jac tool`](#jac-tool). Use **`jac tool grammar`** (add `--lark` for Lark format, `-o OUT` to write to a file). See [`jac tool`](#jac-tool) below.

---

### jac script

Running custom scripts has folded into [`jac x`](#jac-x). Use **`jac x <name>`** to run a script defined in the `[scripts]` section of `jac.toml` (a bare `jac x`, or `jac x --list`, lists the available tools and scripts). See [Configuration: Scripts](../config/index.md#scripts) for defining scripts.

---

### jac py2jac

Converting Python to Jac has moved under [`jac tool`](#jac-tool). Use **`jac tool py2jac <file>`**. See [`jac tool`](#jac-tool) below.

---

### jac jac2py

Converting Jac to Python has moved under [`jac tool`](#jac-tool). Use **`jac tool jac2py <file>`**. See [`jac tool`](#jac-tool) below.

---

### jac tool

`jac tool <name>` fronts the language tools (IR, AST) and the source transforms. The transforms `jac2py`, `py2jac`, `jac2js`, and `grammar` are now invoked through `jac tool` (they were formerly top-level `jac jac2py` / `jac py2jac` / `jac jac2js` / `jac grammar`).

```bash
jac tool <name> [args ...]
```

| Tool | Description |
|------|-------------|
| `jac2py <file>` | Convert Jac code to Python |
| `py2jac <file>` | Convert Python code to Jac |
| `jac2js <file>` | Convert Jac code to JavaScript (used for client frontend compilation) |
| `grammar [--lark] [-o OUT]` | Extract and print the Jac grammar (EBNF, or `--lark` for Lark format) |
| `ir [ast\|sym\|py] <file>` | Inspect compiler IR: AST, symbol table, or generated Python |

**Examples:**

```bash
# Source transforms
jac tool jac2py main.jac
jac tool py2jac script.py
jac tool jac2js app.jac

# Grammar
jac tool grammar                 # EBNF to stdout
jac tool grammar --lark          # Lark format
jac tool grammar -o grammar.ebnf # write to file

# View IR options
jac tool ir

# View AST
jac tool ir ast main.jac

# View symbol table
jac tool ir sym main.jac

# View generated Python
jac tool ir py main.jac
```

> **Deprecated:** `jac js` is a deprecated alias for `jac tool jac2js` and will be removed in a future release. It still works but emits a deprecation warning on stderr; update scripts to use `jac tool jac2js`.

---

### jac lsp

Start the Jac language server (LSP over stdio) for editor/IDE integration.

```bash
jac lsp
```

Editors normally launch this for you; configure your editor's LSP client to run `jac lsp` for `.jac` files.

---

### jac nacompile

*Hidden from `jac --help` (still functional).*

Compile a `.na.jac` file to a standalone native ELF executable. No external compiler, assembler, or linker is required. The entire pipeline runs in pure Python using llvmlite and a built-in ELF linker.

> **Project-level vs. file-level.** For a whole-project native build, use [`jac build --as native`](#jac-build) (or `--as binary`), which runs the type-check gate first. `jac nacompile` remains the file-level tool for compiling an individual `.na.jac` file, building `--shared` C-ABI libraries, and cross-compiling with `--target wasm32`.

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

*Hidden from `jac --help` (still functional).*

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

## Client Framework Commands

The built-in full-stack client framework contributes these commands and flags. They ship with `jaclang` core -- no separate install needed.

### jac build --client

Build a **client shell** for a specific target. This is the `--client` mode of [`jac build`](#jac-build); see that section for the artifact projections (`.jab`, wheel, npm, source, native). A bare `jac build` (no `--client`) runs the type-check gate and emits a `.jab`, not a client shell.

```bash
jac build [filename] --client TARGET [-p PLATFORM]
```

| Option | Description | Default |
|--------|-------------|---------|
| `filename` | Path to .jac file | `main.jac` |
| `--client` | Client shell target (`web`, `desktop`, `pwa`, `mobile`, `static`, `cef`, `react-native`) | None |
| `-p, --platform` | **Mobile:** `android`, `ios`, `all`. **Desktop:** `windows` names the sidecar `jac-sidecar.exe` | Current platform |

**Examples:**

```bash
# Build the web client shell
jac build --client web

# Build desktop app
jac build --client desktop

# Build on Windows for the windows binary
jac build --client desktop --platform windows

# Build mobile app for Android
jac build --client mobile --platform android

# Build mobile app for iOS
jac build --client mobile --platform ios
```

### jac setup

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

### Extended Flags

| Base Command | Added Flag | Description |
|-------------|-----------|-------------|
| `jac create` | `--kind web-app` | Create full-stack project template |
| `jac create` | `--skip` | Skip npm package installation |
| `jac start` | `--client <target>` | Client build target for dev server |
| `jac add` | `--npm` | Add npm (client-side) dependency |
| `jac remove` | `--npm` | Remove npm (client-side) dependency |

### Desktop builds

The `desktop` and `cef` client targets ship with `jaclang` core -- no
separate install. There is no separate `jac desktop` command and no setup step.
Build and run the OS-native webview target with `jac build --client desktop` /
`jac start --client desktop`, or the Chromium Embedded Framework target with
`jac build --client cef` / `jac start --client cef`. Set
`engine = "cef"` under `[desktop]` for CEF projects. See the
[jac-desktop Reference](../plugins/jac-desktop.md) for configuration and CEF
runtime flags.

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
jac check . --lint --fix
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
# Type-check gate, then build a wheel from jac.toml
jac build --as wheel

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
jac scale status main.jac

# Remove deployment
jac scale destroy main.jac
```

## See Also

- [Project Configuration](../config/index.md)
- [Scale Documentation](../plugins/jac-scale.md)
- [Testing Guide](../testing.md)
