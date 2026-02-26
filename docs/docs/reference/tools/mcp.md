# MCP Server (jac-mcp)

The `jac-mcp` plugin provides a [Model Context Protocol](https://modelcontextprotocol.io/) server that gives AI assistants deep knowledge of the Jac language. It exposes grammar specifications, documentation, code examples, compiler tools, and prompt templates through a standardized protocol.

## Installation

```bash
pip install jac-mcp
```

Or for development:

```bash
pip install -e ./jac-mcp
```

## Quick Start

### Start the MCP server (stdio transport)

```bash
jac mcp
```

### Start with SSE transport

```bash
jac mcp --transport sse --port 3001
```

### Inspect available resources, tools, and prompts

```bash
jac mcp --inspect
```

## Configuration

Add to your project's `jac.toml`:

```toml
[plugins.mcp]
transport = "stdio"
port = 3001
host = "127.0.0.1"
expose_grammar = true
enable_validate = true
```

## Resources (24+)

Resources are read-only reference materials that AI models can load for context.

| URI Pattern | Description |
|---|---|
| `jac://grammar/spec` | Full EBNF grammar specification |
| `jac://grammar/tokens` | Token and keyword definitions |
| `jac://docs/foundation` | Core language concepts |
| `jac://docs/functions-objects` | Archetypes, abilities, has declarations |
| `jac://docs/osp` | Object-Spatial Programming (nodes, edges, walkers) |
| `jac://docs/primitives` | Primitives and codespace semantics |
| `jac://docs/concurrency` | Concurrency (flow, wait, async) |
| `jac://docs/advanced` | Comprehensions and filters |
| `jac://docs/cheatsheet` | Quick syntax reference |
| `jac://docs/python-integration` | Python interoperability |
| `jac://docs/byllm` | byLLM plugin reference |
| `jac://docs/jac-client` | jac-client plugin reference |
| `jac://docs/jac-scale` | jac-scale plugin reference |
| `jac://guide/pitfalls` | Common AI mistakes when writing Jac |
| `jac://guide/patterns` | Idiomatic Jac code patterns |
| `jac://examples/*` | Example Jac projects |

## Tools (9)

Tools are executable operations that AI models can invoke.

| Tool | Description |
|---|---|
| `validate_jac` | Full type-check validation of Jac code |
| `check_syntax` | Quick parse-only syntax check |
| `format_jac` | Format Jac code to standard style |
| `py_to_jac` | Convert Python code to Jac |
| `explain_error` | Explain compiler errors with suggestions |
| `list_examples` | List available example categories |
| `get_example` | Get example code files |
| `search_docs` | Keyword search across documentation |
| `get_ast` | Parse code and return AST info |

## Prompts (9)

Prompt templates for common Jac development tasks.

| Prompt | Description |
|---|---|
| `write_module` | Generate a new Jac module |
| `write_impl` | Generate .impl.jac implementation file |
| `write_walker` | Generate a walker with visit logic |
| `write_node` | Generate a node archetype |
| `write_test` | Generate test blocks |
| `write_ability` | Generate an ability implementation |
| `debug_error` | Debug a compilation error |
| `fix_type_error` | Fix a type checking error |
| `migrate_python` | Convert Python to idiomatic Jac |

## IDE Integration

### Claude Desktop

Add to your Claude Desktop config (`~/.claude/claude_desktop_config.json`):

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

### VS Code with Continue

Add to your Continue config:

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

## Transport Options

| Transport | Flag | Description |
|---|---|---|
| stdio | `--transport stdio` | Default. Standard input/output. Best for IDE integration. |
| SSE | `--transport sse` | Server-Sent Events over HTTP. Requires `uvicorn` and `starlette`. |
| Streamable HTTP | `--transport streamable-http` | HTTP streaming. Requires `uvicorn` and `starlette`. |
