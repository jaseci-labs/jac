# jac-mcp Release Notes

## jac-mcp 0.1.3 (Unreleased)

## jac-mcp 0.1.2 (Latest Release)

- **Compiler-validated MCP content**: Cross-validated all code snippets in pitfalls.md and patterns.md against the Jac compiler, fixing critical issues where the server was teaching syntax the compiler rejects
- **Fixed `can` vs `def` guidance**: `can` is only for event-driven abilities (`can X with Y entry`); `def` is correct for regular methods. Updated pitfalls, patterns, and SERVER_INSTRUCTIONS accordingly
- **Fixed `enumerate()` pitfall**: Corrected documentation that wrongly said `enumerate()` is unsupported in Jac
- **Removed invalid `<>` ByRef pitfall**: This syntax does not exist in current Jac
- **Fixed `class` vs `obj` pitfall**: `class` is valid Jac syntax alongside `obj`
- **Fixed match/case syntax in patterns**: Uses colon syntax, not braces
- **Enhanced SERVER_INSTRUCTIONS**: Corrected `can`/`def` guidance sent to AI clients during MCP initialization
- **Enhanced tool descriptions**: Added workflow guidance (MUST validate, use before writing, etc.)
- **System/user role separation**: All 9 prompt templates now use proper role separation
- **QA test suite**: Added 149-test `qa_server.jac` covering resources, tools, prompts, server instructions, and compiler validation

## jac-mcp 0.1.1

- **Expanded documentation resources**: DOC_MAPPINGS now covers all 42 mkdocs pages (up from 12), including tutorials, developer workflow, and quick-start guides
- **Auto-generated doc bundling**: New `scripts/bundle_docs.jac` script replaces hardcoded CI copy commands, using DOC_MAPPINGS as the single source of truth for PyPI release bundling

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
