"""Compiler bridge for jac-mcp.

This module wraps jaclang's compiler pipeline for use by MCP tools,
providing parse, typecheck, format, and py2jac operations.
"""

glob MAX_INPUT_SIZE: int = 102400,
     DEFAULT_TIMEOUT: int = 10;

"""Run a function with timeout protection."""
def run_with_timeout(func: object, timeout: int = 10) -> tuple;

"""Bridge to jaclang compiler pipeline."""
obj CompilerBridge {
    """Parse Jac code and return structured errors."""
    static def parse_snippet(
        code: str, filename: str = "snippet.jac"
    ) -> dict[str, any];

    """Full type-check pipeline on Jac code."""
    static def typecheck_snippet(
        code: str, filename: str = "snippet.jac"
    ) -> dict[str, any];

    """Format Jac code."""
    static def format_snippet(code: str) -> dict[str, any];

    """Convert Python code to Jac."""
    static def py_to_jac(python_code: str) -> dict[str, any];

    """Parse Jac code and return AST representation."""
    static def get_ast_snippet(code: str, fmt: str = "tree") -> dict[str, any];

    """Lint Jac code and return violations with optional auto-fix."""
    static def lint_snippet(code: str, auto_fix: bool = False) -> dict[str, any];

    """Convert Jac code to Python."""
    static def jac_to_py(code: str) -> dict[str, any];

    """Convert Jac code to JavaScript."""
    static def jac_to_js(code: str) -> dict[str, any];

    """Execute Jac code and return output."""
    static def run_snippet(
        code: str, entrypoint: str = "", timeout: int = 10
    ) -> dict[str, any];

    """Generate graph visualization from Jac code."""
    static def graph_viz_snippet(
        code: str,
        format: str = "dot",
        depth: int = -1,
        bfs: bool = True,
        edge_limit: int = 512,
        node_limit: int = 512
    ) -> dict[str, any];

    """List available Jac project templates."""
    static def list_templates -> dict[str, any];

    """Create a new Jac project from a template."""
    static def create_project(
        name: str, template: str = "cli", directory: str = ""
    ) -> dict[str, any];

    """Start a Jac REST API server as a background process."""
    static def start_server(
        filename: str, port: int = 8000, faux: bool = False
    ) -> dict[str, any];
}
