import from jaclang.jac0core.runtime { hookimpl }

class JacMcpPluginConfig {
    @hookimpl
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "mcp",
            "version": "0.1.0",
            "description": "MCP server for AI-assisted Jac development"
        };
    }

    @hookimpl
    static def get_config_schema -> dict[str, any] {
        return {
            "section": "mcp",
            "options": {
                "transport": {
                    "type": "string",
                    "default": "stdio",
                    "description": "Transport protocol: stdio, sse, or streamable-http"
                },
                "port": {
                    "type": "int",
                    "default": 3001,
                    "description": "Port for SSE/HTTP transports (1-65535)"
                },
                "host": {
                    "type": "string",
                    "default": "127.0.0.1",
                    "description": "Bind address for SSE/HTTP transports"
                },
                "expose_grammar": {
                    "type": "bool",
                    "default": True,
                    "description": "Expose jac.spec language grammar as resource"
                },
                "expose_guides": {
                    "type": "bool",
                    "default": True,
                    "description": "Expose the jac://guide/* reference guides as resources"
                },
                "expose_examples": {
                    "type": "bool",
                    "default": True,
                    "description": "Expose example code from jaclang/examples"
                },
                "expose_pitfalls": {
                    "type": "bool",
                    "default": True,
                    "description": "Expose curated pitfalls/gotchas guide"
                },
                "enable_validate": {
                    "type": "bool",
                    "default": True,
                    "description": "Enable parse + type-check tools"
                },
                "enable_format": {
                    "type": "bool",
                    "default": True,
                    "description": "Enable Jac code formatting tool"
                },
                "enable_py2jac": {
                    "type": "bool",
                    "default": True,
                    "description": "Enable Python to Jac conversion tool"
                },
                "enable_ast": {
                    "type": "bool",
                    "default": False,
                    "description": "Enable AST introspection tool (verbose)"
                },
                "project_root": {
                    "type": "string",
                    "default": ".",
                    "description": "Root directory for project-aware tools"
                },
                "mode": {
                    "type": "string",
                    "default": "full",
                    "description": "Tool/prompt exposure mode: lite, standard, or full"
                }
            }
        };
    }
}
