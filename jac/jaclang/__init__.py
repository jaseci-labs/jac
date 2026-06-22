"""The Jac Programming Language."""

import sys

from jaclang.meta_importer import JacMetaImporter  # noqa: E402

# Register JacMetaImporter BEFORE loading plugins, so .jac modules can be imported
if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

# Import compiler first to ensure generated parsers exist before jac0core.parser is loaded
# Backwards-compatible import path for older plugins/tests.
# Prefer `jaclang.jac0core.runtime` going forward.
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


def _add_project_venv_to_path() -> None:
    """Put the current project's ``.jac/venv`` site-packages on ``sys.path``.

    Plugins are enumerated below (during ``import jaclang``), which is *before*
    the CLI runs ``add_venv_to_path``. So a plugin installed into a project venv
    (``jac install [-e] <pkg>``) would not be discovered in time. This walks up
    from the cwd to the nearest ``jac.toml`` and prepends its venv site-packages
    so per-project plugins load. Plain Python (no jac imports) -- it runs during
    the foundational bootstrap phase. Mirrors ``get_venv_site_packages`` /
    ``add_venv_to_path`` in ``jaclang/project``; the CLI's later call is then a
    no-op (the path is already present).
    """
    import os

    try:
        directory = os.getcwd()
        toml = None
        while True:
            candidate = os.path.join(directory, "jac.toml")
            if os.path.isfile(candidate):
                toml = candidate
                break
            parent = os.path.dirname(directory)
            if parent == directory:
                break
            directory = parent
        if toml is None:
            return
        venv = os.path.join(os.path.dirname(toml), ".jac", "venv")
        if os.name == "nt":
            site_packages = os.path.join(venv, "Lib", "site-packages")
        else:
            site_packages = ""
            lib = os.path.join(venv, "lib")
            if os.path.isdir(lib):
                for entry in sorted(os.listdir(lib)):
                    cand = os.path.join(lib, entry, "site-packages")
                    if entry.startswith("python") and os.path.isdir(cand):
                        site_packages = cand
                        break
        if (
            site_packages
            and os.path.isdir(site_packages)
            and site_packages not in sys.path
        ):
            sys.path.insert(0, site_packages)
    except Exception:
        # Plugin discovery falls back to the binary's own site; never fatal.
        pass


# Discover per-project venv plugins (jac install [-e] <pkg>) before enumerating.
_add_project_venv_to_path()

# Load external plugins with disabling support
# Disabling can be configured via JAC_DISABLED_PLUGINS env var or jac.toml [plugins].disabled
# Use "*" to disable all external plugins, "package:*" for all from a package,
# or "package:plugin" for specific plugins
_disabled_list = get_disabled_plugins()
# Always go through load_plugins_with_disabling so plugin-load failures
# are surfaced as warnings (instead of silently swallowed by pluggy's
# load_setuptools_entrypoints). The disable list may be empty.
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
    except Exception as exc:  # keep core usable if the framework fails to import
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
    except Exception as exc:  # keep core usable if shadcn fails to import
        import warnings

        warnings.warn(f"Built-in shadcn provider unavailable: {exc}", stacklevel=2)
        return
    if not plugin_manager.is_registered(JacShadcnPlugin):
        plugin_manager.register(JacShadcnPlugin)


_register_builtin_shadcn_provider()

# Schedule deferred native acceleration if autonative is enabled in jac.toml
try:
    from jaclang.project.config import get_config as _get_jac_config

    _jac_cfg = _get_jac_config()
    if _jac_cfg and _jac_cfg.run.autonative:
        from jaclang.jac0core.native_accel import schedule_native_acceleration

        schedule_native_acceleration()
except Exception:
    pass  # Config not available or acceleration failed — continue normally

__all__ = ["JacRuntimeInterface", "JacRuntime"]
