"""Jac Super Console Plugin - jacpretty-enhanced console.

This plugin provides jacpretty-enhanced console output for Jac CLI.
It overrides the base console implementation to provide elegant,
colorful terminal output with themes, panels, tables, and spinners.
"""
import from jaclang.jac0core.runtime { hookimpl, plugin_manager }
import from jaclang.cli.console { JacConsole as BaseJacConsole }

"""Jac Super Plugin for console enhancement."""
class JacSuperPlugin {
    """Get the jacpretty-enhanced console instance."""
    @hookimpl
    static def get_console -> BaseJacConsole {
        return JacSuperConsole();
    }
}

# Register the plugin
with entry {
    plugin_manager.register(JacSuperPlugin());
}
