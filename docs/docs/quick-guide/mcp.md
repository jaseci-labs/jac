# MCP Server (jac-mcp)

The `jac-mcp` plugin provides a [Model Context Protocol](https://modelcontextprotocol.io/) server that gives AI assistants deep knowledge of the Jac language. It exposes grammar specifications, documentation, code examples, compiler tools, and prompt templates through a standardized protocol --so any MCP-compatible AI client can write, validate, format, and debug Jac code.

## Installation

If you installed Jaseci via PyPI or the install script, `jac-mcp` is likely already included. Run `jac --version` to check -- it prints all installed plugins. If `jac-mcp` appears in the list, you're good to go.

Otherwise, install it separately:

```bash
pip install jac-mcp
```

## Quick Start

### 1. Start the MCP server

```bash
jac mcp
```

This starts the server with the default **stdio** transport, ready for IDE integration.

### 2. Inspect what's available

```bash
jac mcp --inspect
```

This prints all available resources, tools, and prompts, then exits.

### 3. Connect your AI client

Add the server to your AI client's MCP configuration (see [IDE Integration](#ide-integration) below), then start using Jac tools directly from your AI assistant.

## IDE Integration

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "jac": {
      "command": "jac",
      "args": ["mcp"]
    }
  }
}
```

Restart Claude Desktop after saving. The Jac tools will appear in the tool picker (hammer icon).

### Claude Code (CLI)

Add to your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "jac": {
      "command": "jac",
      "args": ["mcp"],
      "type": "stdio"
    }
  }
}
```

Or add it interactively:

```bash
claude mcp add jac -- jac mcp
```

### Cursor

Add to `.cursor/mcp.json` in your project root:

```json
{
  "mcpServers": {
    "jac": {
      "command": "jac",
      "args": ["mcp"]
    }
  }
}
```

After saving, open Cursor Settings > MCP and verify the server shows a green status indicator.

### VS Code with Continue

Add to your Continue config (`.continue/config.json`):

```json
{
  "mcpServers": [
    {
      "name": "jac",
      "command": "jac",
      "args": ["mcp"]
    }
  ]
}
```

### VS Code with Copilot Chat

Add to your VS Code `settings.json`:

```json
{
  "mcp": {
    "servers": {
      "jac": {
        "command": "jac",
        "args": ["mcp"]
      }
    }
  }
}
```

### Windsurf

Add to `~/.windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "jac": {
      "command": "jac",
      "args": ["mcp"]
    }
  }
}
```

### Remote / SSE Clients

For clients that connect over HTTP rather than stdio:

```bash
jac mcp --transport sse --port 3001
```

Then configure your client to connect to:

- **SSE endpoint:** `http://127.0.0.1:3001/sse`
- **Message endpoint:** `http://127.0.0.1:3001/messages/` (POST)

!!! tip
If your `jac` binary is installed in a virtualenv, use the full path in the `command` field (e.g., `/path/to/venv/bin/jac`). You can find it with `which jac`.

## CLI Reference

```
jac mcp [OPTIONS]
```

| Option        | Default     | Description                                                |
| ------------- | ----------- | ---------------------------------------------------------- |
| `--transport` | `stdio`     | Transport protocol: `stdio`, `sse`, or `streamable-http`   |
| `--port`      | `3001`      | Port for SSE/HTTP transports                               |
| `--host`      | `127.0.0.1` | Bind address for SSE/HTTP transports                       |
| `--inspect`   | `false`     | Print inventory of resources, tools, and prompts then exit |

**Examples:**

```bash
# Default stdio (for IDE integration)
jac mcp

# SSE on custom port
jac mcp --transport sse --port 8080

# Streamable HTTP
jac mcp --transport streamable-http --port 3001

# See everything the server exposes
jac mcp --inspect
```

## Configuration

Add to your project's `jac.toml` to customize the server:

```toml
[plugins.mcp]
# Transport settings
transport = "stdio"          # "stdio", "sse", or "streamable-http"
port = 3001                  # Port for SSE/HTTP transports
host = "127.0.0.1"          # Bind address for SSE/HTTP transports

# Resource exposure
expose_grammar = true        # Expose jac.spec and token definitions
expose_docs = true           # Expose language documentation
expose_examples = true       # Expose example Jac projects
expose_pitfalls = true       # Expose common AI mistakes guide

# Tool enable/disable
enable_validate = true       # validate_jac and check_syntax tools
enable_format = true         # format_jac tool
enable_py2jac = true         # py_to_jac conversion tool
enable_ast = false           # get_ast tool (verbose, off by default)

# Project context
project_root = "."           # Root directory for project-aware tools
```

## Transport Options

| Transport           | Flag                          | Use Case                                                        | Requirements |
| ------------------- | ----------------------------- | --------------------------------------------------------------- | ------------ |
| **stdio**           | `--transport stdio`           | IDE integration (Claude Desktop, Cursor, Claude Code). Default. | None         |
| **SSE**             | `--transport sse`             | Browser-based clients, remote access                            | None         |
| **Streamable HTTP** | `--transport streamable-http` | Advanced HTTP clients, load-balanced deployments                | None         |

**Endpoint details for HTTP transports:**

| Transport       | Endpoints                                                      |
| --------------- | -------------------------------------------------------------- |
| SSE             | `GET /sse` (event stream), `POST /messages/` (client messages) |
| Streamable HTTP | `POST /mcp` (bidirectional streaming)                          |

## Resources (40+)

Resources are read-only reference materials that AI models can load for context. They are served through the `jac://` URI scheme.

### Grammar

| URI                    | Description                     |
| ---------------------- | ------------------------------- |
| `jac://grammar/spec`   | Full EBNF grammar specification |
| `jac://grammar/tokens` | Token and keyword definitions   |

### Getting Started

| URI                             | Description                                     |
| ------------------------------- | ----------------------------------------------- |
| `jac://docs/welcome`            | Getting started with Jac                        |
| `jac://docs/install`            | Installation guide                              |
| `jac://docs/core-concepts`      | What makes Jac different                        |
| `jac://docs/first-app`          | Build an AI Day Planner tutorial                |
| `jac://docs/cheatsheet`         | Quick syntax reference                          |
| `jac://docs/jac-vs-traditional` | Architecture comparison with traditional stacks |
| `jac://docs/faq`                | Frequently asked questions                      |

### Language Specification

| URI                             | Description                                        |
| ------------------------------- | -------------------------------------------------- |
| `jac://docs/reference-overview` | Full reference index                               |
| `jac://docs/foundation`         | Core language concepts                             |
| `jac://docs/primitives`         | Primitives and codespace semantics                 |
| `jac://docs/functions-objects`  | Archetypes, abilities, has declarations            |
| `jac://docs/osp`                | Object-Spatial Programming (nodes, edges, walkers) |
| `jac://docs/concurrency`        | Concurrency (flow, wait, async)                    |
| `jac://docs/advanced`           | Comprehensions and filters                         |

### Language Tutorials

| URI                                 | Description                 |
| ----------------------------------- | --------------------------- |
| `jac://docs/tutorial-coding-primer` | Coding primer for beginners |
| `jac://docs/tutorial-basics`        | Jac language fundamentals   |
| `jac://docs/tutorial-osp`           | Graphs and walkers tutorial |

### AI Integration

| URI                                 | Description                 |
| ----------------------------------- | --------------------------- |
| `jac://docs/byllm`                  | byLLM plugin reference      |
| `jac://docs/tutorial-ai-quickstart` | Your first AI function      |
| `jac://docs/tutorial-ai-structured` | Structured outputs tutorial |
| `jac://docs/tutorial-ai-agentic`    | Building AI agents tutorial |
| `jac://docs/tutorial-ai-multimodal` | Multimodal AI tutorial      |

### Full-Stack Development

| URI                                        | Description                 |
| ------------------------------------------ | --------------------------- |
| `jac://docs/jac-client`                    | jac-client plugin reference |
| `jac://docs/tutorial-fullstack-setup`      | Project setup               |
| `jac://docs/tutorial-fullstack-components` | Components tutorial         |
| `jac://docs/tutorial-fullstack-state`      | State management            |
| `jac://docs/tutorial-fullstack-backend`    | Backend integration         |
| `jac://docs/tutorial-fullstack-auth`       | Authentication              |
| `jac://docs/tutorial-fullstack-routing`    | Routing                     |

### Deployment & Scaling

| URI                                    | Description                 |
| -------------------------------------- | --------------------------- |
| `jac://docs/jac-scale`                 | jac-scale plugin reference  |
| `jac://docs/tutorial-production-local` | Local API server deployment |
| `jac://docs/tutorial-production-k8s`   | Kubernetes deployment       |

### Developer Workflow

| URI                            | Description                      |
| ------------------------------ | -------------------------------- |
| `jac://docs/cli`               | CLI command reference            |
| `jac://docs/config`            | Project configuration            |
| `jac://docs/code-organization` | Project structure guide          |
| `jac://docs/mcp`               | MCP server reference (this page) |
| `jac://docs/testing`           | Test framework reference         |
| `jac://docs/debugging`         | Debugging techniques             |

### Python Integration

| URI                             | Description                   |
| ------------------------------- | ----------------------------- |
| `jac://docs/python-integration` | Python interoperability       |
| `jac://docs/library-mode`       | Using Jac as a Python library |

### Quick Reference

| URI                           | Description                   |
| ----------------------------- | ----------------------------- |
| `jac://docs/walker-responses` | Walker response patterns      |
| `jac://docs/appendices`       | Additional language reference |

### Guides & Examples

| URI                    | Description                            |
| ---------------------- | -------------------------------------- |
| `jac://guide/pitfalls` | Common AI mistakes when writing Jac    |
| `jac://guide/patterns` | Idiomatic Jac code patterns            |
| `jac://examples/*`     | Example Jac projects (auto-discovered) |

## Tools (19)

Tools are executable operations that AI models can invoke to validate, format, and analyze Jac code.

### validate_jac

Full type-check validation of Jac code. Runs the complete compilation pipeline including type checking.

| Parameter  | Type   | Required | Description                                          |
| ---------- | ------ | -------- | ---------------------------------------------------- |
| `code`     | string | Yes      | Jac source code to validate                          |
| `filename` | string | No       | Filename for error messages (default: `snippet.jac`) |

**Example input:**

```json
{
  "code": "obj Foo {\n    has x: int = 5;\n}"
}
```

**Example output (valid):**

```json
{
  "valid": true,
  "errors": [],
  "warnings": []
}
```

**Example output (error):**

```json
{
  "valid": false,
  "errors": [
    { "line": 0, "col": 0, "message": "SyntaxError: unexpected token 'class'" }
  ],
  "warnings": []
}
```

### check_syntax

Quick parse-only syntax check. Faster than `validate_jac` since it skips type checking.

| Parameter | Type   | Required | Description              |
| --------- | ------ | -------- | ------------------------ |
| `code`    | string | Yes      | Jac source code to check |

### lint_jac

Lint Jac code for style violations and unused symbols. With `auto_fix: true`, also returns corrected code.

| Parameter  | Type    | Required | Description                                                   |
| ---------- | ------- | -------- | ------------------------------------------------------------- |
| `code`     | string  | Yes      | Jac source code to lint                                       |
| `auto_fix` | boolean | No       | Return corrected code alongside violations (default: `false`) |

**Example output (no violations):**

```json
{
  "violations": [],
  "fixed_code": null,
  "changed": false
}
```

**Example output (violations found):**

```json
{
  "violations": [
    {
      "line": 1,
      "col": 1,
      "message": "Consecutive 'has' declarations can be combined [combine-has]"
    },
    {
      "line": 6,
      "col": 10,
      "message": "Unused variable 'x'",
      "severity": "error"
    }
  ],
  "fixed_code": null,
  "changed": false
}
```

**Example output (with `auto_fix: true`):**

```json
{
  "violations": [
    {
      "line": 1,
      "col": 1,
      "message": "Consecutive 'has' declarations can be combined [combine-has]"
    }
  ],
  "fixed_code": "obj Foo {\n    has x: int,\n        y: int;\n}\n",
  "changed": true
}
```

!!! note "Severity field"
Style violations (warnings) have no `severity` field. Only compiler-level errors include `"severity": "error"`.

### format_jac

Format Jac code according to standard style.

| Parameter | Type   | Required | Description               |
| --------- | ------ | -------- | ------------------------- |
| `code`    | string | Yes      | Jac source code to format |

**Example output:**

```json
{
  "formatted": "obj Foo {\n    has x: int = 5;\n}\n",
  "changed": true
}
```

### py_to_jac

Convert Python code to Jac.

| Parameter     | Type   | Required | Description                   |
| ------------- | ------ | -------- | ----------------------------- |
| `python_code` | string | Yes      | Python source code to convert |

**Example output:**

```json
{
  "jac_code": "can greet(name: str) -> str {\n    return f\"Hello, {name}!\";\n}\n",
  "warnings": []
}
```

### jac_to_py

Transpile Jac code to Python. Returns the generated Python source that the Jac compiler produces internally.

| Parameter | Type   | Required | Description                |
| --------- | ------ | -------- | -------------------------- |
| `code`    | string | Yes      | Jac source code to convert |

**Example input:**

```json
{
  "code": "obj Foo {\n    has x: int = 5;\n}\n\ndef greet(name: str) -> str {\n    return f\"Hello, {name}!\";\n}"
}
```

**Example output (success):**

```json
{
  "python_code": "from __future__ import annotations\nfrom jaclang.jac0core.jaclib import Obj\n\nclass Foo(Obj):\n    x: int = 5\n\ndef greet(name: str) -> str:\n    return f'Hello, {name}!'",
  "warnings": []
}
```

**Example output (error):**

```json
{
  "python_code": "",
  "warnings": ["snippet.jac, line 1, col 13: Missing '}'"]
}
```

!!! note
Errors are reported through `warnings`. The field name is the same regardless of severity.

### jac_to_js

Transpile Jac code to JavaScript. Returns generated JS source.

- `obj` → ES6 classes
- `def` → JavaScript functions
- `node` / `walker` → simple class stubs

The generated output is minimal and does not include runtime helpers or execution scaffolding.

| Parameter | Type   | Required | Description                |
| --------- | ------ | -------- | -------------------------- |
| `code`    | string | Yes      | Jac source code to convert |

**Example input:**

```json
{
  "code": "obj Foo {\n    has x: int = 5;\n}\n\ndef greet(name: str) -> str {\n    return f\"Hello, {name}!\";\n}"
}
```

**Example output (success):**

```json
{
  "js_code": "class Foo {\n  constructor(props = {}) {\n    this.x = (props.hasOwnProperty(\"x\") ? props.x : 5);\n  }\n}\nfunction greet(name) {\n  return `Hello, ${name}!`;\n}",
  "warnings": []
}
```

**Example output (error):**

```json
{
  "js_code": "",
  "warnings": ["snippet.jac, line 1, col 13: Missing '}'"]
}
```

!!! note
The `warnings` field includes both warnings and compilation errors.

On failure, `js_code` will be empty and `warnings` will contain one or more error messages with file, line, and column information. These messages may include temporary file paths.

### explain_error

Explain a Jac compiler error with suggestions and code examples.

| Parameter       | Type   | Required | Description                  |
| --------------- | ------ | -------- | ---------------------------- |
| `error_message` | string | Yes      | The error message to explain |

**Example output:**

```json
{
  "title": "Syntax Error",
  "explanation": "The code contains a syntax error. Common causes: missing semicolons, missing braces, or using Python syntax instead of Jac syntax.",
  "suggestion": "Review the error and apply the pattern shown in the example.",
  "example": "obj Foo {\n    has x: int = 5;\n}",
  "docs_uri": "jac://guide/pitfalls"
}
```

### list_examples

List available Jac example categories.

| Parameter  | Type   | Required | Description              |
| ---------- | ------ | -------- | ------------------------ |
| `category` | string | No       | Optional category filter |

### get_example

Get all `.jac` files from an example category.

| Parameter | Type   | Required | Description           |
| --------- | ------ | -------- | --------------------- |
| `name`    | string | Yes      | Example category name |

### search_docs

Keyword search across all documentation resources. Returns ranked snippets.

| Parameter | Type    | Required | Description                    |
| --------- | ------- | -------- | ------------------------------ |
| `query`   | string  | Yes      | Search query keywords          |
| `limit`   | integer | No       | Maximum results (default: `5`) |

**Example output:**

```json
{
  "results": [
    {
      "uri": "jac://docs/osp",
      "title": "Object-Spatial Programming",
      "description": "Object-Spatial Programming - Nodes, edges, walkers",
      "snippet": "...walkers traverse the graph by visiting connected nodes...",
      "score": 12.0
    }
  ]
}
```

### get_ast

Parse Jac code and return AST information.

| Parameter | Type   | Required | Description                                       |
| --------- | ------ | -------- | ------------------------------------------------- |
| `code`    | string | Yes      | Jac source code to parse                          |
| `format`  | string | No       | Output format: `tree` or `json` (default: `tree`) |

!!! note "Safety limits"
All compiler tools enforce a **100 KB** maximum input size and a **10-second** timeout per operation.

### run_jac

Execute Jac code in-process and return its output. Unlike `execute_command`, no file on disk is required. The code is compiled and run from the string directly.

| Parameter    | Type    | Required | Description                                           |
| ------------ | ------- | -------- | ----------------------------------------------------- |
| `code`       | string  | Yes      | Jac source code to execute                            |
| `entrypoint` | string  | No       | Walker or function name to invoke as the entry point. |
| `timeout`    | integer | No       | Max execution time in seconds (default: `10`)         |

!!! note "`report` and stdout"
Walker `report` statements print the reported value to stdout **and** append it to the walker's `.reports` list inside the program. The tool output captures both through `stdout`.

**Example input:**

```json
{
  "code": "with entry {\n    print(\"Hello!\");\n}"
}
```

**Example output (success):**

```json
{
  "stdout": "Hello!\n",
  "stderr": "",
  "exit_code": 0
}
```

**Example output (runtime error):**

```json
{
  "stdout": "",
  "stderr": "",
  "exit_code": 1,
  "error": "name 'x' is not defined"
}
```

**Example output (no entrypoint):**

```json
{
  "stdout": "",
  "stderr": "",
  "exit_code": 0
}
```

- If no `with entry {}` block or valid entrypoint is provided, execution succeeds but produces no output.
- Runtime errors are reported in the `error` field. The `stderr` field is typically empty.
- Error messages are generated by the underlying runtime and may vary.
- The `entrypoint` parameter may not work when executing code directly from a string and may require compiled bytecode.

### graph_visualize

Execute Jac code and return a DOT-format graph of the resulting node/edge structure.

- Always produces a graph rooted at `Root()`, even if no edges are created.
- Includes styling and metadata (e.g., colors, labels).
- Captures both program output and CLI messages in `program_output`.

| Parameter    | Type    | Required | Description                                             |
| ------------ | ------- | -------- | ------------------------------------------------------- |
| `code`       | string  | Yes      | Jac source code that builds a graph                     |
| `format`     | string  | No       | Output format: `dot` or `json` (default: `dot`)         |
| `depth`      | integer | No       | Max traversal depth, `-1` for unlimited (default: `-1`) |
| `bfs`        | boolean | No       | Use breadth-first search (default: `true`)              |
| `edge_limit` | integer | No       | Max edges to include (default: `512`)                   |
| `node_limit` | integer | No       | Max nodes to include (default: `512`)                   |

!!! warning "Optional parameters behavior"
Some parameters (e.g., `node_limit`) may affect the output, while others may be partially applied or ignored depending on the underlying `jac dot` implementation. Behavior may vary.

**Example input:**

```json
{
  "code": "node Person { has name: str; }\n\nwith entry {\n    alice = Person(name=\"Alice\");\n    bob = Person(name=\"Bob\");\n    root ++> alice;\n    alice ++> bob;\n}"
}
```

**Example output (success):**

```json
{
  "graph": "digraph {\nnode [style=\"filled\", shape=\"ellipse\", fillcolor=\"invis\", fontcolor=\"black\"];\n0 -> 1 [label=\"\"];\n1 -> 2 [label=\"\"];\n0 [label=\"Root()\"fillcolor=\"#FFE9E9\"];\n1 [label=\"Person(name='Alice')\"fillcolor=\"#F0FFF0\"];\n2 [label=\"Person(name='Bob')\"fillcolor=\"#F5E5FF\"];\n}",
  "program_output": ">>> Graph content saved to /tmp/.../snippet.dot\n"
}
```

**Example output (no graph edges):**

```json
{
  "graph": "digraph {\nnode [style=\"filled\", shape=\"ellipse\", fillcolor=\"invis\", fontcolor=\"black\"];\n0 [label=\"Root()\"fillcolor=\"#FFE9E9\"];\n}",
  "program_output": "Hello\n>>> Graph content saved to /tmp/.../snippet.dot\n"
}
```

**Example output (error):**

```json
{
  "graph": "",
  "program_output": "",
  "error": "Error executing 'dot': No bytecode found ..."
}
```

- `program_output` includes both program stdout and CLI/tool messages.
- A graph is always returned with at least a `Root()` node, even if no edges are created.
- DOT output includes styling attributes and may contain HTML-encoded characters.
- Error messages may include stack traces and additional diagnostic output from the runtime.

### understand_jac_and_jaseci

Returns the Jac & Jaseci knowledge map: a Markdown document listing every available resource URI by topic, with a task-to-resource lookup table. Call this first to discover what documentation is available, then fetch specific pages with `get_resource`.

No parameters.

**Example output:**

```json
{
  "knowledge_map": "# Jac & Jaseci - Knowledge Map\n\n## What is Jac?\n..."
}
```

### get_resource

Fetch the full content of a Jac/Jaseci documentation resource by URI. Resources are Markdown documents. Valid URIs are listed in the [Resources](#resources-40) section above and in the output of `understand_jac_and_jaseci`.

| Parameter | Type   | Required | Description                                                           |
| --------- | ------ | -------- | --------------------------------------------------------------------- |
| `uri`     | string | Yes      | Resource URI to fetch (e.g. `jac://docs/osp`, `jac://guide/pitfalls`) |

**Example input:**

```json
{
  "uri": "jac://docs/osp"
}
```

**Example output (success):**

```json
{
  "uri": "jac://docs/osp",
  "content": "# Part III: Object-Spatial Programming (OSP)\n..."
}
```

**Example output (not found):**

```json
{
  "uri": "jac://docs/unknown",
  "error": "Error: Resource not found: jac://docs/unknown"
}
```

- `content` is returned as raw Markdown text, including headings, code blocks, and tables.
- Responses may be large depending on the resource size.
- On failure, the `error` field is returned along with the requested `uri`.
- Error messages are generated by the backend and may vary slightly in wording.

### list_commands

List all available `jac` CLI commands, including those added by installed plugins. Commands are grouped by category. Use this to discover valid command names before calling `get_command` or `execute_command`.

No parameters.

**Example output:**

```json
{
  "commands": [...],
  "groups": [...],
  "total": 34
}
```

The optional `extended_by` field lists plugins that add arguments to a base command.

### get_command

Get the full argument details for a specific `jac` CLI command, including arguments contributed by plugins. Use this before calling `execute_command` to know exactly which arguments a command accepts.

| Parameter | Type   | Required | Description                                  |
| --------- | ------ | -------- | -------------------------------------------- |
| `name`    | string | Yes      | Command name (e.g. `run`, `check`, `format`) |

**Example output:**

```json
{
  "name": "run",
  "help": "Run a Jac program",
  "group": "execution",
  "source": "jaclang",
  "args": [
    {
      "name": "filename",
      "kind": "POSITIONAL",
      "type": "str",
      "required": false,
      "default": null,
      "help": "Path to .jac or .py file",
      "source": "jaclang"
    },
    {
      "name": "cache",
      "kind": "OPTION",
      "type": "bool",
      "required": false,
      "default": true,
      "help": "Enable compilation cache",
      "source": "jaclang",
      "short": "c"
    }
  ]
}
```

**Example output (not found):**

```json
{
  "error": "Command not found: nonexistent_command"
}
```

Each argument has a `kind` of `POSITIONAL`, `OPTION`, `MULTI`, or `REMAINDER`.

- `POSITIONAL`: A positional argument.
- `OPTION`: A named option (e.g. `--flag`).
- `MULTI`: Accepts multiple values (e.g. repeated or space-separated inputs).
- `REMAINDER`: Captures all remaining arguments.

Additional notes:

- `default` may be `null`, a primitive value, or a collection depending on the argument.
- `short` is always present but may be an empty string if no short flag is defined.
- Some fields (e.g. `choices`) are optional and only appear when applicable.
- Consumers should not assume that the presence of a field implies a usable value.

### execute_command

Execute any `jac` CLI command by name with optional arguments. Use `list_commands` to discover available commands and `get_command` to inspect their arguments before calling this.

| Parameter | Type     | Required | Description                                                         |
| --------- | -------- | -------- | ------------------------------------------------------------------- |
| `command` | string   | Yes      | The `jac` subcommand to run (e.g. `run`, `check`, `format`, `test`) |
| `args`    | string[] | No       | Arguments to pass, as a list of strings (default: `[]`)             |
| `timeout` | integer  | No       | Max execution time in seconds (default: `30`)                       |

**Example input:**

```json
{
  "command": "check",
  "args": ["app.jac"]
}
```

**Example output (success):**

```json
{
  "success": true,
  "exit_code": 0,
  "stdout": "Checking app.jac...\napp.jac PASSED [100%]\n",
  "stderr": "",
  "command": "jac check app.jac"
}
```

**Example output (failure):**

```json
{
  "success": false,
  "exit_code": 1,
  "stdout": "...",
  "stderr": "✖ Error: File 'app.jac' does not exist.\n",
  "command": "jac check app.jac"
}
```

**Example output (invalid arguments):**

```json
{
  "success": false,
  "exit_code": 2,
  "stdout": "",
  "stderr": "usage: jac check ...\nerror: the following arguments are required: paths\n",
  "command": "jac check "
}
```

!!! note

- Exit codes follow standard CLI conventions:
  - `0`: success
  - `1`: runtime or execution failure
  - `2`: command usage or argument error

- Errors are typically reported via `stderr`, not the `error` field.

- The `error` field is primarily used for system-level failures such as timeouts.

- Both `stdout` and `stderr` may contain useful information and should be inspected together.

- The `command` field is the full CLI command string that was executed and may include trailing spaces.

## Prompts (9)

Prompt templates provide structured system prompts for common Jac development tasks. Each prompt automatically loads the pitfalls guide and relevant reference material as context.

### write_module

Generate a new Jac module with optional `.impl.jac` file.

| Argument   | Required | Description                                                |
| ---------- | -------- | ---------------------------------------------------------- |
| `name`     | Yes      | Module name                                                |
| `purpose`  | Yes      | What the module does                                       |
| `has_impl` | No       | Include `.impl.jac` file (`true`/`false`, default: `true`) |

### write_impl

Generate a `.impl.jac` implementation file for existing declarations.

| Argument       | Required | Description                            |
| -------------- | -------- | -------------------------------------- |
| `declarations` | Yes      | Content of the `.jac` declaration file |

### write_walker

Generate a walker with visit logic.

| Argument     | Required | Description            |
| ------------ | -------- | ---------------------- |
| `name`       | Yes      | Walker name            |
| `purpose`    | Yes      | What the walker does   |
| `node_types` | Yes      | Node types to traverse |

### write_node

Generate a node archetype with has declarations.

| Argument | Required | Description       |
| -------- | -------- | ----------------- |
| `name`   | Yes      | Node name         |
| `fields` | Yes      | Field definitions |

### write_test

Generate test blocks for a module.

| Argument            | Required | Description                 |
| ------------------- | -------- | --------------------------- |
| `module_name`       | Yes      | Module to test              |
| `functions_to_test` | Yes      | Functions/abilities to test |

### write_ability

Generate an ability (method) implementation.

| Argument    | Required | Description    |
| ----------- | -------- | -------------- |
| `name`      | Yes      | Ability name   |
| `signature` | Yes      | Type signature |
| `purpose`   | Yes      | What it does   |

### debug_error

Debug a Jac compilation error.

| Argument       | Required | Description                    |
| -------------- | -------- | ------------------------------ |
| `error_output` | Yes      | The error message(s)           |
| `code`         | Yes      | The code that caused the error |

### fix_type_error

Fix a type checking error in Jac code.

| Argument       | Required | Description                  |
| -------------- | -------- | ---------------------------- |
| `error_output` | Yes      | The type error message       |
| `code`         | Yes      | The code with the type error |

### migrate_python

Convert Python code to idiomatic Jac.

| Argument      | Required | Description                   |
| ------------- | -------- | ----------------------------- |
| `python_code` | Yes      | Python source code to convert |

## Troubleshooting

### "command not found: jac"

The `jac` binary is not on your PATH. If installed in a virtualenv, use the full path:

```json
{
  "command": "/path/to/venv/bin/jac",
  "args": ["mcp"]
}
```

Find the path with `which jac` or `python -m site --user-base`.

### Server connects but shows no tools

Run `jac mcp --inspect` to verify the server is working. If it shows tools but your AI client doesn't, restart the AI client --most clients only load MCP servers at startup.

### Tools return timeout errors

The compiler bridge enforces a 10-second timeout per operation. If your code is very large, split it into smaller files. The maximum input size is 100 KB.

### Resources show "Error: File not found"

Resource paths are resolved relative to the jaclang package installation. In a **development install** (`pip install -e`), resources are read directly from the repository's `docs/` directory. In a **PyPI install**, bundled copies are used. If you see missing resources after a PyPI install, update to the latest version:

```bash
pip install --upgrade jac-mcp
```
