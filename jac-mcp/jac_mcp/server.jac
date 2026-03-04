"""MCP Server core for jac-mcp.

This module implements the JacMcpServer class that manages the MCP server
lifecycle including transport setup, handler registration, and shutdown.
"""

import from typing { Any }

"""MCP Server for Jac development assistance."""
obj JacMcpServer {
    has transport: str = "stdio",
        port: int = 3001,
        host: str = "127.0.0.1";

    """Start the MCP server with configured transport."""
    def start -> None;

    """Stop the MCP server gracefully."""
    def stop -> None;
}
