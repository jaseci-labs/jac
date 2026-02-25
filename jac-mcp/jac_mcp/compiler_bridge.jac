"""Compiler bridge for jac-mcp.

This module wraps jaclang's compiler pipeline for use by MCP tools,
providing parse, typecheck, format, and py2jac operations.
"""

import from typing { Any }

glob MAX_INPUT_SIZE: int = 102400,
     DEFAULT_TIMEOUT: int = 10;

"""Run a function with timeout protection."""
def run_with_timeout(func: object, timeout: int = 10) -> tuple;

"""Bridge to jaclang compiler pipeline."""
obj CompilerBridge {
    """Parse Jac code and return structured errors."""
    static def parse_snippet(
        code: str, filename: str = "snippet.jac"
    ) -> dict[str, Any];

    """Full type-check pipeline on Jac code."""
    static def typecheck_snippet(
        code: str, filename: str = "snippet.jac"
    ) -> dict[str, Any];

    """Format Jac code."""
    static def format_snippet(code: str) -> dict[str, Any];

    """Convert Python code to Jac."""
    static def py_to_jac(python_code: str) -> dict[str, Any];
}
