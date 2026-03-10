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
