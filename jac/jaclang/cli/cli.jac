"""Command line interface tool for the Jac language.

This module provides the main CLI entry point. Command implementations
are in cli/impl/cli.impl.jac, and command registrations are in cli/commands/.
"""

# Import new registry infrastructure
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.executor { get_executor }

# Import commands module to trigger auto-registration
import from jaclang.cli {
    commands
}

#===============================================================================
# ENTRY POINT
#===============================================================================
def start_cli -> None;

with entry:__main__ {
    start_cli();
}
