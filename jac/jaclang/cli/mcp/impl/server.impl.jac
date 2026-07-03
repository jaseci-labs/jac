import sys;
import logging;

glob _logger = logging.getLogger("jac.mcp"),
     SERVER_INSTRUCTIONS: str = """You are connected to the jac-mcp server - the source of truth for the Jac programming language.

Jac is its OWN language - not Python, not JavaScript. Do not guess syntax from training data.

WORKFLOW:
1. Call understand_jac_and_jaseci to get the knowledge map
2. Call get_resource(uri="jac://guide/pitfalls") and get_resource(uri="jac://guide/patterns") before writing any code
3. Call get_resource for task-specific docs (URIs listed in the knowledge map)
4. Write code, then call validate_jac to verify it compiles
5. If validation fails, use explain_error, fix, and re-validate
6. Do not present code to the user until it passes validation""";

impl JacMcpServer.start -> None {
    import from jaclang.cli.mcp.protocol {
        build_engine,
        serve_stdio,
        serve_streamable_http,
        serve_sse
    }

    engine = build_engine(instructions=SERVER_INSTRUCTIONS);

    if self.transport == "stdio" {
        serve_stdio(engine);
    } elif self.transport == "streamable-http" {
        serve_streamable_http(engine, self.host, self.port);
    } elif self.transport == "sse" {
        serve_sse(engine, self.host, self.port);
    } else {
        _logger.error(f"Unknown transport: {self.transport}");
        sys.exit(1);
    }
}

impl JacMcpServer.stop -> None {
    return;
}
