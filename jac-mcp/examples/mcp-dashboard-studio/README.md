# Jac MCP Studio

An interactive developer dashboard for working with [Jac](https://www.jac-lang.org/) code via the [Model Context Protocol (MCP)](https://modelcontextprotocol.io). Connect to a Jac MCP server and run tools to validate, format, inspect, and explore Jac code, all from a clean browser UI.

> **What is Jac?** Jac is a programming language built on top of Python that adds native support for graph-based computation, AI integration, and object-spatial programming. Learn more at [jac-lang.org](https://www.jac-lang.org/).

---

## What it does

| Tool              | What it does                                      |
| ----------------- | ------------------------------------------------- |
| **Validate**      | Checks your Jac code for semantic errors          |
| **Syntax**        | Fast syntax-only check                            |
| **Format**        | Auto-formats your code and shows the diff         |
| **AST Tree**      | Renders the abstract syntax tree as readable text |
| **AST JSON**      | Renders the AST as structured JSON                |
| **Python → Jac**  | Converts Python code to Jac                       |
| **Explain Error** | Explains a Jac error message in plain language    |
| **Examples**      | Lists and loads example Jac programs by category  |
| **Search Docs**   | Full-text search across Jac documentation         |

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

## Using the tools

### Search bar (top, full width)

Type a keyword and press **Enter** or click **Search** to query the Jac documentation. Results show the title, description, snippet, relevance score, and source URI.

### Code editor (left panel)

Paste or type Jac code in the editor. The toolbar above it has buttons for each code tool. Click any of them to run it against the current code. Formatted and AST outputs include a **Copy** button so you can paste the result directly into your editor.

### Tools panel (center)

- **Python → Jac**: paste Python code and click Convert. The result appears below with a Copy button.
- **Explain Error**: paste an error message and click Explain.
- **Examples**: click **List Examples** to see available categories. Click a category badge to load its files directly into the output panel.

### Output panel (right)

All tool results appear here. The active tool name is shown at the top. Results update every time you run a tool.

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
├── main.jac                  # App entry point and walker definitions
├── jac.toml                  # Project config (dependencies, server, plugins)
├── pyproject.toml            # Python dependencies (used by uv sync)
├── scripts/
│   └── dev.sh                # Starts MCP server + dashboard together
├── frontend/
│   └── Dashboard.cl.jac      # Main UI component
├── backend/
│   ├── service.jac           # MCP HTTP communication layer
│   └── utils.jac             # Input validation helpers
├── components/               # Reusable UI components
│   ├── CodeBlock.cl.jac
│   ├── Button.cl.jac
│   ├── Badge.cl.jac
│   ├── Card.cl.jac
│   └── Spinner.cl.jac
├── tests/
│   ├── utils_test.jac        # Unit tests for backend/utils.jac
│   ├── service_test.jac      # Tests for backend/service.jac
│   └── walkers_test.jac      # Tests for walker input guards and contracts
├── assets/
│   ├── logo.png              # App logo
│   ├── home.png              # Screenshot: home view
│   ├── format.png            # Screenshot: format output
│   └── ast.png               # Screenshot: AST output
└── styles/
    └── main.css              # Tailwind CSS entry
```

---

## Tests

Tests live in `tests/` and require no running MCP server.

```bash
jac test -d tests/
```

| File               | What it covers                                                                                                   |
| ------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `utils_test.jac`   | All guard response functions and `extract_first_error` edge cases                                                |
| `service_test.jac` | `ping_endpoint` returning a graceful error for unreachable URLs                                                  |
| `walkers_test.jac` | Empty and whitespace input guards, single-report contract, graceful service failure, `set_mcp_server` edge cases |

---

## Development notes

**Always use `scripts/dev.sh`**: it starts both the MCP server and the dashboard together and cleans up both on exit. Running `jac start main.jac` alone will start the UI but no MCP tools will work.

**Transport**: the MCP server uses the `streamable-http` transport on port `3001`. This is set in `scripts/dev.sh` and matches the default URL shown in the dashboard.

**Hot reload** is enabled by default. Changes to `.jac` files reload the browser automatically.

**Adding npm packages:**

```bash
jac add --cl <package-name>
```

**MCP server URL** can be changed at any time from the UI without restarting. Clicking Connect re-initializes the MCP session with the new URL.

**The backend never stores code**: all tool calls are forwarded directly to the MCP server and results are held only in the browser's UI state.
