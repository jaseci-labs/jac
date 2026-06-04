"""Jac-client runtime plugin system for client-target extensibility.

Plugins such as jac-desktop register via the ``jac_client`` setuptools entry-point
group and implement ``get_client_targets`` to contribute build targets beyond the
built-in web, pwa, and mobile targets.
"""

import from jaclang.jac0core { plugin }
import from jac_client.plugin.src.targets.registry { ClientTarget }

glob client_plugin_manager = plugin.PluginManager('jac_client'),
     client_hookspec = plugin.HookspecMarker('jac_client'),
     client_hookimpl = plugin.HookimplMarker('jac_client');

"""Hookspec for jac-client runtime plugins (mirrors JacScalePlugin on core)."""
class JacClientPluginSpec {
    """Return plugin-provided build targets beyond built-in web/pwa/mobile."""
    @client_hookspec(firstresult=True)
    static def get_client_targets -> (list[ClientTarget] | ClientTarget | None) {
        ;
    }
}

"""Invoke jac-client runtime plugin hooks."""
class JacClientRuntime {
    static def get_client_targets -> (list[ClientTarget] | ClientTarget | None) {
        return client_plugin_manager.hook.get_client_targets();
    }
}

"""Load setuptools plugins from the ``jac_client`` entry-point group."""
def load_client_plugins {
    client_plugin_manager.load_setuptools_entrypoints('jac_client');
}

with entry {
    client_plugin_manager.add_hookspecs(JacClientPluginSpec);
}
