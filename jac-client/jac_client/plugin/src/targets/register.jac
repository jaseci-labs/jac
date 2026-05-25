"""Register all build targets.

Built-in targets (web, pwa, mobile) register here. Plugin-provided targets
(e.g. desktop from jac-desktop) register via the ``get_client_targets`` hook.
"""
import from jac_client.plugin.src.targets.registry {
    get_target_registry,
    TargetRegistry
}
import from jac_client.plugin.src.targets.web_target { WebTarget }
import from jac_client.plugin.src.targets.pwa_target { PWATarget }
import from jac_client.plugin.src.targets.mobile_target { MobileTarget }

# Note: Jac's annex pass should auto-discover .impl.jac files automatically
# The impl files in impl/ directory should be loaded when the base classes are imported
"""Register targets returned by the ``get_client_targets`` plugin hook."""
def _register_plugin_client_targets(registry: TargetRegistry) -> None {
    import from jac_client.plugin.client_plugin { JacClientRuntime }
    results = JacClientRuntime.get_client_targets();
    if results is None {
        return;
    }
    if isinstance(results, list) {
        for target in results {
            registry.register(target);
        }
    } else {
        registry.register(results);
    }
}

"""Register built-in and plugin-provided client build targets.

Called from ``JacCmd.create_cmd`` after jac-client runtime plugins are loaded.
"""
def register_targets {
    import from jac_client.plugin.client_plugin { load_client_plugins }
    load_client_plugins();
    registry = get_target_registry();
    registry.register(WebTarget());
    registry.register(PWATarget());
    registry.register(MobileTarget());
    _register_plugin_client_targets(registry);
}

"""Sync ``--client`` argparse choices on build/start with registered targets."""
def sync_client_target_choices -> None {
    import from jaclang.cli.registry { get_registry }
    import from jac_client.plugin.src.targets.registry { get_target_factory }
    registry = get_registry();
    factory = get_target_factory();
    names = factory.get_available_target_names();
    if not names {
        return;
    }
    for cmd_name in ["build", "start"] {
        spec = registry.get(cmd_name);
        if spec is None {
            continue;
        }
        for arg in spec.get_all_args() {
            if arg.name == "client" {
                arg.choices = list(names);
            }
        }
    }
}
