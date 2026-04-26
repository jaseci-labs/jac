# jac-mcp

`jac-mcp` provides a Model Context Protocol (MCP) server for AI-assisted Jac development. It exposes Jac-aware resources, prompts, and tools so MCP-compatible clients can inspect documentation, validate snippets, format code, convert Jac to other targets, and run Jac commands through the same project tooling used by the Jaseci stack.

## Installation

Install from PyPI:

```bash
pip install jac-mcp
```

For local development from this repository:

```bash
git clone --recurse-submodules https://github.com/jaseci-labs/jaseci.git
cd jaseci
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e jac
python -m pip install -e jac-mcp
```

## Usage

Start the MCP server with the default `stdio` transport:

```bash
jac mcp
```

Use an HTTP transport when connecting clients that expect a network endpoint:

```bash
jac mcp --transport streamable-http --host 127.0.0.1 --port 3001
```

Inspect the resources, tools, and prompts exposed by the server:

```bash
jac mcp --inspect
```

## Modes

`jac-mcp` supports three exposure modes for different client and model sizes:

- `lite` - minimal tool/prompt surface for smaller models or constrained contexts
- `standard` - balanced default surface for day-to-day Jac assistance
- `full` - complete tool/prompt surface

Select a mode from the CLI:

```bash
jac mcp --mode lite
```

Or configure it in `jac.toml`:

```toml
[plugins.mcp]
transport = "stdio"
mode = "standard"
```

## Available capabilities

The MCP server exposes capabilities such as:

- Jac documentation and knowledge-map resources
- grammar/spec resources
- example discovery
- compiler error explanations
- AST inspection
- Jac linting and formatting
- Jac-to-Python and Jac-to-JavaScript conversion
- Jac code execution
- graph visualization
- Jac CLI command discovery and execution

Use `jac mcp --inspect` for the authoritative list supported by the installed version.

## Development

Run the package tests from the repository root:

```bash
pytest -q jac-mcp -x
```

The package depends on `jaclang` and the upstream `mcp` Python package. When working from a fresh clone, initialize submodules before running compiler/type-checker paths:

```bash
git submodule update --init --recursive
```
