# Jac Development Skill

Instructions for AI coding agents. Following this file installs the Jac programming language, wires Jac expertise into your tooling, and teaches you enough to work productively in a Jac codebase. Execute the steps in order and verify each one before moving on.

Jac is a Python-like language that compiles to Python bytecode, JavaScript, and native machine code. AI calls (`by llm()`), persistent graphs, REST APIs, React-style UIs, and cloud deployment are language features. Everything ships in one self-contained `jac` binary.

## Step 1: Install the jac binary

On macOS or Linux (on Windows, run inside WSL):

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

The script installs a self-contained binary to `~/.local/bin/jac`. No Python, pip, Node, or C toolchain is required.

Verify the install:

```bash
jac --version
```

If `jac` is not found, ensure `~/.local/bin` is on `PATH` for the current shell.

## Step 2: Register the Jac MCP server (if your host supports MCP)

The binary includes an MCP server exposing Jac validation, formatting, documentation, and examples.

Claude Code:

```bash
claude mcp add jac -- jac mcp
```

Cursor, Windsurf, or any other MCP client (add to its MCP config):

```json
{ "mcpServers": { "jac": { "command": "jac", "args": ["mcp"] } } }
```

Pass `--mode lite` for a smaller tool surface if you are a smaller model. If you cannot use MCP, skip this step; `jac guide` prints curated reference material in the terminal instead.

## Step 3: Know the toolchain

All development tasks go through the one binary:

| Command | Purpose |
|---|---|
| `jac run app.jac` | Run a program |
| `jac create <name>` | Scaffold a new project |
| `jac dev` | Dev loop with hot reload |
| `jac start app.jac` | Serve as a REST API (+ frontend if present) |
| `jac build` | Type-check and emit an app bundle |
| `jac build --as native` | Compile to a standalone executable |
| `jac install <pkg>` | Add PyPI or npm dependencies (declared in `jac.toml`) |
| `jac check` / `jac fmt` / `jac test` | Type-check, format, run tests |
| `jac guide` | Curated docs in the terminal |

## Step 4: Learn the language essentials

Read before writing Jac; it is not Python:

- Statements end with `;` and blocks use `{ }`.
- Object fields are declared with `has name: type;` and type annotations are mandatory.
- `node`, `edge`, and `walker` are archetypes for graph-based programming. `root ++> MyNode(...)` attaches a node to the persistent root graph; `[-->]` collects outgoing neighbors; `spawn` sends a walker traversing.
- The graph under `root` persists between runs and across server requests automatically.
- `def f(x: str) -> T by llm();` delegates a function body to an LLM with the return type enforced as the output schema (requires `jac install byllm` and a model in `jac.toml`).
- Code inside `cl { }` blocks (or `cl def`) compiles to JavaScript/JSX for the browser; the rest runs on the server. Cross-boundary calls are generated RPCs.
- Interfaces can be separated from implementations with `impl`.

Primary references:

- Syntax cheatsheet: https://docs.jaseci.org/quick-guide/syntax-cheatsheet/
- Language fundamentals: https://docs.jaseci.org/tutorials/language/basics/
- Graphs and walkers: https://docs.jaseci.org/tutorials/language/osp/
- Documentation index for LLMs: https://docs.jaseci.org/llms.txt

## Step 5: Validate everything you write

Before declaring any Jac work done:

```bash
jac check <file-or-project>   # type errors
jac fmt <file-or-project>     # canonical formatting
jac test <path>               # run tests
```

For runnable programs, execute them (`jac run`) and confirm the observed behavior matches the request.
