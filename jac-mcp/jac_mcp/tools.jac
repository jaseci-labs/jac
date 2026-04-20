"""MCP Tool providers for jac-mcp.

This module registers executable tools that AI models can invoke:
validation, formatting, conversion, error explanation, and more.
"""

import from typing { Any }

"""Tool provider that registers and dispatches MCP tools."""
obj ToolProvider {
    """Return list of available tools with schemas."""
    def list_tools -> list[dict[str, Any]];

    """Call a tool by name with arguments."""
    def call_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any];
}

"""Explain a compiler error with suggestions and examples."""
def explain_error(error_message: str) -> dict[str, Any];

"""List available example categories."""
def list_examples(category: str | None = None) -> dict[str, Any];

"""Get all files from an example category."""
def get_example(name: str) -> dict[str, Any];

"""Search documentation by keywords."""
def search_docs(query: str, limit: int = 5) -> dict[str, Any];

"""Parse code and return AST info."""
def get_ast(code: str, fmt: str = "tree") -> dict[str, Any];

"""Lint Jac code with optional auto-fix."""
def lint_jac(code: str, auto_fix: bool = False) -> dict[str, Any];

"""Convert Jac code to Python."""
def jac_to_py(code: str) -> dict[str, Any];

"""Convert Jac code to JavaScript."""
def jac_to_js(code: str) -> dict[str, Any];

"""Execute Jac code and return output."""
def run_jac(code: str, entrypoint: str = "", timeout: int = 10) -> dict[str, Any];

"""Generate graph visualization from Jac code."""
def graph_visualize(
    code: str,
    format: str = "dot",
    depth: int = -1,
    bfs: bool = True,
    edge_limit: int = 512,
    node_limit: int = 512
) -> dict[str, Any];

"""List all available jac CLI commands including those from installed plugins."""
def list_commands -> dict[str, Any];

"""Get full argument details for a specific jac CLI command."""
def get_command(name: str) -> dict[str, Any];

"""Execute a jac CLI command by name with optional arguments."""
def execute_command(
    command: str, args: list[str] | None = None, timeout: int = 30
) -> dict[str, Any];

"""Get the Jac & Jaseci knowledge map with resource URIs for any task."""
def understand_jac_and_jaseci -> dict[str, Any];

"""Fetch a Jac/Jaseci doc resource by URI (from understand_jac_and_jaseci)."""
def get_resource(uri: str) -> dict[str, Any];
