# jac-mcp Release Notes

## jac-mcp 0.1.1 (Unreleased)

## jac-mcp 0.1.0

Initial release of jac-mcp, the MCP (Model Context Protocol) server plugin for Jac.

### Features

- **MCP Server**: Full MCP server with stdio, SSE, and streamable-http transport support
- **Resources (24+)**: Grammar spec, token definitions, 11 documentation sections, example index, bundled pitfalls/patterns guides
- **Tools (9)**: validate_jac, check_syntax, format_jac, py_to_jac, explain_error, list_examples, get_example, search_docs, get_ast
- **Prompts (9)**: write_module, write_impl, write_walker, write_node, write_test, write_ability, debug_error, fix_type_error, migrate_python
- **Compiler Bridge**: Parse, typecheck, format, and py2jac operations with timeout protection and input size limits
- **CLI Integration**: `jac mcp` command with --transport, --port, --host, --inspect flags
- **Plugin System**: Full Jac plugin with JacCmd and JacPluginConfig hooks
