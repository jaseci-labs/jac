import sys

from jaclang.meta_importer import JacMetaImporter  # noqa: E402

if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

import jaclang.jac0core.runtime as _runtime_mod  # noqa: E402
from jaclang import compiler as _compiler  # noqa: E402, F401
from jaclang.jac0core.helpers import (  # noqa: E402
    get_disabled_plugins,
    load_plugins_with_disabling,
)
from jaclang.jac0core.runtime import (  # noqa: E402
    JacRuntime,
    JacRuntimeImpl,
    JacRuntimeInterface,
    plugin_manager,
)

sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)

plugin_manager.register(JacRuntimeImpl)

with __import__("contextlib").suppress(Exception):
    import _jac_finder as _jf

    _jf.add_project_venv_to_path()

_disabled_list = get_disabled_plugins()
load_plugins_with_disabling(plugin_manager, _disabled_list)


def _register_builtin_client_providers() -> None:
    """Register the built-in client/desktop framework hook providers.

    These shipped as the separate ``jac-client`` / ``jac-desktop`` plugins; they are
    now part of core and register directly (no entry points, no separate package).
    Serving hooks (render_page / get_client_js / send_static_file / format_build_error)
    are inlined into core's defaults; these providers contribute the ``[plugins.client]``
    / ``[plugins.desktop]`` config schema, the npm dependency type, the project
    templates (fullstack/client/mobile/desktop), plugin metadata, and the client CLI
    commands (``build`` / ``setup`` / ``start`` + ``--npm`` / ``--cl``).
    """
    try:
        from jaclang.runtimelib.client.cli import JacClientCmd
        from jaclang.runtimelib.client.desktop_plugin_config import (
            JacDesktopPluginConfig,
        )
        from jaclang.runtimelib.client.plugin_config import JacClientPluginConfig
    except Exception as exc:
        import warnings

        warnings.warn(f"Built-in client framework unavailable: {exc}", stacklevel=2)
        return
    for _provider in (JacClientPluginConfig, JacDesktopPluginConfig, JacClientCmd):
        if not plugin_manager.is_registered(_provider):
            plugin_manager.register(_provider)


_register_builtin_client_providers()


def _register_builtin_shadcn_provider() -> None:
    """Register the built-in shadcn/ui CLI provider.

    This shipped as the ``shadcn`` entry point of the separate ``jac-super``
    plugin; it is now part of core and registers directly (no entry point, no
    separate package). Importing the module also registers the ``jac retheme``
    command (via its ``@registry.command`` decorator); registering the plugin
    class wires its ``create_cmd`` / ``register_project_template`` hooks, which
    add the ``--shadcn`` flags and the ``jac-shadcn`` project template.
    """
    try:
        from jaclang.cli.shadcn.plugin import JacShadcnPlugin
    except Exception as exc:
        import warnings

        warnings.warn(f"Built-in shadcn provider unavailable: {exc}", stacklevel=2)
        return
    if not plugin_manager.is_registered(JacShadcnPlugin):
        plugin_manager.register(JacShadcnPlugin)


_register_builtin_shadcn_provider()

try:
    from jaclang.project.config import get_config as _get_jac_config

    _jac_cfg = _get_jac_config()
    if _jac_cfg and _jac_cfg.run.autonative:
        from jaclang.jac0core.native_accel import schedule_native_acceleration

        schedule_native_acceleration()
except Exception:
    pass

__all__ = ["JacRuntimeInterface", "JacRuntime"]
