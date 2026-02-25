"""MCP Prompt templates for jac-mcp.

This module provides pre-built prompt templates for common Jac generation tasks.
Each prompt loads relevant resources into the system message and structures
the user message with provided arguments.
"""

import from typing { Any }

"""Load a resource's content, returning empty string if unavailable."""
def load_resource_content(uri: str) -> str;

"""Build system prompt with pitfalls and optional extra resources."""
def build_system_prompt(extra_uris: list[str] = []) -> str;

"""Prompt template provider for Jac code generation and debugging."""
obj PromptProvider {
    """Return list of available prompts."""
    def list_prompts -> list[dict[str, Any]];

    """Get a prompt by name with arguments."""
    def get_prompt(name: str, arguments: dict[str, str]) -> dict[str, Any];
}
