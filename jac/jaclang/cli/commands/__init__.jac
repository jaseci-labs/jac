"""CLI command definitions organized by functional group.

This module provides auto-discovery of all command modules. Importing this
module will register all built-in commands with the command registry.

Command Groups:
- execution: run, enter, serve, debug - Program execution commands
- analysis: check, build, format, test, gen_parser - Code analysis commands
- transform: py2jac, jac2py, js - Code transformation commands
- project: create, install, add, remove, script - Project management commands
- tools: tool, dot, lsp - Development tool commands
- config: config, plugins - Configuration commands
"""

# Import all command modules to trigger registration
import from jaclang.cli.commands {
    execution
}
import from jaclang.cli.commands { analysis }
import from jaclang.cli.commands { transform }
import from jaclang.cli.commands { project }
import from jaclang.cli.commands { tools }
import from jaclang.cli.commands { config }

"""Register all built-in commands.

Call this function during CLI startup to ensure all commands are registered.
"""
def register_all_commands -> None {
# Imports above handle registration via decorators
}
