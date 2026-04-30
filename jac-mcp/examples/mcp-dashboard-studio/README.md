# Jac MCP Studio

An interactive developer dashboard for working with [Jac](https://www.jac-lang.org/) code via the [Model Context Protocol (MCP)](https://modelcontextprotocol.io). Connect to a Jac MCP server and use 19 tools to validate, format, run, inspect, and explore Jac code, all from a Monaco-powered browser UI.

> **What is Jac?** Jac is a programming language built on top of Python that adds native support for graph-based computation, AI integration, and object-spatial programming. Learn more at [jac-lang.org](https://www.jac-lang.org/).

---

## How it works

The app has two halves:

- **Left (Monaco Editor)**: a VS Code-quality editor pre-loaded with a sample Jac program. Most tools run against the code in this editor. The toolbar above it has quick-action buttons (**Run**, **Validate**) and a **Tools ▾** button that opens the command palette.
- **Right (Output panel)**: all tool results appear here, replacing each other as you run new tools. Each renderer is tailored to its tool's data shape.

**Command palette** (`Tools ▾`): type to filter across all 19 tools. Tools that only need the editor code run immediately. Tools that need extra input (a query, an error message, options) drop into a **micro-form** inline before executing. Press `Escape` to close.

**Connection**: enter the MCP server URL (default `http://127.0.0.1:3001/mcp/`) and click **Connect**. The status dot turns green. All tools are disabled until connected. You can change the URL and reconnect at any time without restarting.

---

## Tools

The 19 tools are organised into five categories in the command palette.

### Analysis

| Tool | Input | What it does |
|---|---|---|
| **Validate Jac** | editor code | Full semantic validation; reports all type errors and constraint violations |
| **Check Syntax** | editor code | Fast syntax-only parse, no type checking |
| **Lint Jac** | editor code + auto-fix toggle | Reports style violations; optionally applies auto-fixes |
| **Get AST Tree** | editor code | Renders the abstract syntax tree as indented plain text in a read-only Monaco pane |
| **Get AST JSON** | editor code | Renders the AST as structured JSON with syntax highlighting, bracket guides, and collapsible folding |
| **Explain Error** | error message (text input) | Sends an error message to the MCP server and returns a plain-language explanation |

### Transform

| Tool | Input | What it does |
|---|---|---|
| **Format Jac** | editor code | Auto-formats and returns the reformatted source with a copy button |
| **Python to Jac** | Python code (text input) | Converts Python source to equivalent Jac code |
| **Jac to Python** | editor code | Transpiles Jac to Python source |
| **Jac to JavaScript** | editor code | Transpiles Jac to JavaScript (client-side Jac) |

### Execution

| Tool | Input | What it does |
|---|---|---|
| **Run Jac** | editor code + optional entrypoint + timeout | Executes the Jac program and shows stdout, stderr, and exit code |
| **Visualize Graph** | editor code | Runs the program, captures the graph state, and renders it as an interactive SVG |

### Documentation

| Tool | Input | What it does |
|---|---|---|
| **Jac and Jaseci Guide** | none | Fetches the full Jac + Jaseci knowledge map from the MCP server |
| **Get Resource** | URI (text input, e.g. `jac://docs/osp`) | Fetches a named MCP resource by URI |
| **List Examples** | none | Lists all example programs available on the server, grouped by category |
| **Get Example** | category name (text input) | Loads a named example program |
| **Search Docs** | query string | Full-text search across Jac documentation; returns ranked results with title, snippet, and source URI |

### Commands

| Tool | Input | What it does |
|---|---|---|
| **List Commands** | none | Lists all shell-level Jac commands available on the server |
| **Get Command** | command name | Returns the full spec for a named command |
| **Execute Command** | command name + target + optional args | Runs a Jac CLI command server-side and returns its output |

---

## AST output

Both AST tools render inside a **read-only Monaco Editor** instance rather than a plain text block:

- **AST JSON** uses `language="json"`: keys, strings, numbers, and booleans are syntax-highlighted; any nested object or array can be collapsed with the gutter fold arrows; bracket pair colorization and indentation guides are active; a minimap appears on the right for navigating large trees.
- **AST Tree** uses `language="plaintext"`: clean navigation and line highlighting without false syntax colouring.

Both views show a line count, char count, and a **Copy** button in the header bar.

---

## Requirements

1. Python 3.12+
2. [uv](https://docs.astral.sh/uv/) for package management
3. Node.js 18+ (for the client build)
4. A modern browser: Chrome, Firefox, Edge, or Safari 16.4+ (the app uses the Clipboard API)

---

## Setup

**1. Clone the repo and enter the project directory**

```bash
git clone https://github.com/Developer-Linus/mcp-dashboard-studio.git
cd mcp-dashboard-studio
```

**2. Create a virtual environment and install all dependencies**

```bash
uv venv
uv sync
```

This installs everything listed in `pyproject.toml`, including `jaclang`, `jac-client`, and `jac-mcp`.

**3. Start everything**

```bash
bash scripts/dev.sh
```

This single command:

- Activates the virtual environment
- Starts the Jac MCP server on `http://127.0.0.1:3001/mcp/` using the **streamable-http** transport
- Starts the dashboard app

The dashboard opens at `http://localhost:8000`. Press `Ctrl+C` to stop both processes.

> **If port 3001 is already in use**, the script will kill the existing process automatically before starting fresh.

---

## Connecting to the MCP server

1. The server URL is pre-filled as `http://127.0.0.1:3001/mcp/`
2. Click **Connect**
3. The status dot in the top-right turns green when connected

All tools are disabled until a connection is established.

---

## Troubleshooting

**`ERROR: jac-mcp plugin not installed`**
Run `uv sync` again from inside the project directory. If it still fails, check that `pyproject.toml` exists and contains `jac-mcp` in the dependencies.

**Connect button fails / stays orange**

- Make sure `scripts/dev.sh` is running. The dashboard alone cannot connect without the MCP server.
- Check that the URL in the input matches what the script prints (`http://127.0.0.1:3001/mcp/`).
- Look at the terminal output for any MCP server startup errors.

**Blank page in the browser**

- Confirm Node.js 18+ is installed: `node --version`
- Check the terminal for build errors after `jac start` launches.
- Hard-refresh the browser (`Ctrl+Shift+R`) to clear any cached build.

**`ERROR: .venv not found`**
Run `uv venv && uv sync` before running the script.

**Copy buttons don't work**
The app uses the browser Clipboard API which requires a secure context. Make sure you are accessing the app over `http://localhost` (not a raw IP like `http://0.0.0.0`).

---

## Project structure

```
mcp-dashboard-studio/
├── main.jac                       # App entry point + all 20 walker definitions
├── jac.toml                       # Project config (dependencies, server, plugins)
├── pyproject.toml                 # Python dependencies (used by uv sync)
├── scripts/
│   └── dev.sh                     # Starts MCP server + dashboard together
├── frontend/
│   ├── AppRoot.cl.jac             # Root component (routes between home and dashboard)
│   ├── HomePage.cl.jac            # Landing page
│   ├── Dashboard.cl.jac           # Dashboard state declarations and method signatures
│   └── Dashboard.impl.jac         # All method implementations and output renderers
├── backend/
│   ├── service.jac                # MCP HTTP communication layer (one fn per tool)
│   └── utils.jac                  # Input validation helpers and error envelope builders
├── components/                    # Reusable UI primitives
│   ├── Badge.cl.jac
│   ├── Button.cl.jac
│   ├── Card.cl.jac
│   ├── CodeBlock.cl.jac
│   └── Spinner.cl.jac
├── tests/
│   ├── utils_test.jac             # Unit tests for extract_first_error and guard helpers
│   ├── service_test.jac           # ping_endpoint graceful error behaviour
│   ├── walkers_test.jac           # Guard, single-report, and graceful-failure tests per walker
│   └── input_contract_test.jac    # Parametrized fixture tests (blank inputs × all walkers)
└── styles/
    └── main.css                   # Tailwind CSS entry point
```

---

## Tests

Tests live in `tests/` and require no running MCP server; they exercise only input guards and response envelope shape.

```bash
jac test -d tests/
```

| File | What it covers |
|---|---|
| `utils_test.jac` | `extract_first_error` edge cases and all guard response builder functions |
| `service_test.jac` | `ping_endpoint` returning a graceful error dict for unreachable URLs |
| `walkers_test.jac` | Empty and whitespace input guards, single-report contract, graceful service failure, and `set_mcp_server` edge cases for all 19 tools |
| `input_contract_test.jac` | Parametrized fixtures: 6 blank-input variants × 10 code-taking walkers = 60 tests; 4 blank variants × 6 string-input walkers = 24 tests; response envelope shape (4 required keys) × 5 walkers = 20 tests; 8 `extract_first_error` fixture rows |

---

## Development notes

**Always use `scripts/dev.sh`**: it starts both the MCP server and the dashboard together and cleans up both on exit. Running `jac start main.jac` alone starts the UI but no MCP tools will work.

**Transport**: the MCP server uses the `streamable-http` transport on port `3001`. This is set in `scripts/dev.sh` and matches the default URL shown in the dashboard.

**Hot reload** is enabled by default. Changes to `.jac` files reload the browser automatically.

**Adding npm packages:**

```bash
jac add --cl <package-name>
```

**MCP server URL** can be changed at any time from the UI without restarting. Clicking Connect re-initializes the MCP session with the new URL.

**The backend never stores code**: all tool calls are forwarded directly to the MCP server and results are held only in the browser's UI state.

**Adding a new tool**: create the walker in `main.jac`, add a service function in `backend/service.jac`, wire it into the `runTool` dispatch and `renderActiveOutput` dispatch in `Dashboard.impl.jac`, add a renderer function, and add it to `renderPalette`'s category list. Add input-guard tests in `walkers_test.jac` and `input_contract_test.jac`.
